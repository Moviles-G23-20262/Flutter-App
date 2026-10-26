import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_front_end/model/services/external_vision_service.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/repositories/item_photo_classifier.dart';
import 'package:flutter_front_end/model/use_cases/classify_item_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _photo = Uint8List.fromList([1, 2, 3, 4]);
final _pngPhoto = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);

/// What Gemini's generateContent answers with [text] as the generated text.
String _gemini(String text, {bool withThoughtSignature = false}) => jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': text, if (withThoughtSignature) 'thoughtSignature': 'abc=='},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
      'usageMetadata': {'promptTokenCount': 1120},
    });

void main() {
  group('ExternalVisionService (Gemini)', () {
    late http.Request seen;

    ExternalVisionService service(
      Future<http.Response> Function(http.Request) handler, {
      String? apiKey = 'test-key',
      Duration timeout = const Duration(seconds: 5),
    }) =>
        ExternalVisionService(
          client: MockClient((request) {
            seen = request;
            return handler(request);
          }),
          apiKey: apiKey,
          timeout: timeout,
        );

    Future<http.Response> answer(String text) async => http.Response(_gemini(text), 200);

    test('POSTs the prompt and the base64 photo to generateContent with the key', () async {
      final vision = service((_) => answer('BOOKS'));

      await vision.classify(_photo);

      expect(seen.method, 'POST');
      expect(seen.url.origin, 'https://generativelanguage.googleapis.com');
      expect(seen.url.path, '/v1beta/models/gemini-flash-latest:generateContent');
      expect(seen.url.queryParameters['key'], 'test-key');
      expect(seen.headers['Content-Type'], startsWith('application/json'));

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      final parts = ((body['contents'] as List).single as Map)['parts'] as List;
      expect((parts[0] as Map)['text'], ExternalVisionService.prompt);
      expect(ExternalVisionService.prompt, contains('BOOKS, CALCULATORS, LAB_EQUIPMENT, FURNITURE, OTHER'));
      final image = (parts[1] as Map)['inline_data'] as Map;
      expect(image['mime_type'], 'image/jpeg');
      expect(image['data'], base64Encode(_photo));
    });

    test('labels a PNG photo as image/png', () async {
      final vision = service((_) => answer('BOOKS'));

      await vision.classify(_pngPhoto);

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      final image = ((((body['contents'] as List).single as Map)['parts'] as List)[1] as Map)['inline_data'] as Map;
      expect(image['mime_type'], 'image/png');
    });

    test('the model can be changed', () async {
      final vision = ExternalVisionService(
        client: MockClient((request) async {
          seen = request;
          return http.Response(_gemini('OTHER'), 200);
        }),
        apiKey: 'k',
        model: 'gemini-3.8-flash',
      );

      await vision.classify(_photo);

      expect(seen.url.path, '/v1beta/models/gemini-3.8-flash:generateContent');
    });

    test('maps every category name', () async {
      for (final category in MaterialCategoryEnum.values) {
        final vision = service((_) => answer(category.name));
        expect(await vision.classify(_photo), category, reason: category.name);
      }
    });

    test('cleans whitespace, new lines, quotes, case and punctuation', () async {
      const answers = {
        'CALCULATORS\n': MaterialCategoryEnum.CALCULATORS,
        '  furniture  ': MaterialCategoryEnum.FURNITURE,
        '"BOOKS"': MaterialCategoryEnum.BOOKS,
        '`LAB_EQUIPMENT`': MaterialCategoryEnum.LAB_EQUIPMENT,
        'Lab Equipment.': MaterialCategoryEnum.LAB_EQUIPMENT,
        'lab-equipment': MaterialCategoryEnum.LAB_EQUIPMENT,
        '\n\nOTHER\n\n': MaterialCategoryEnum.OTHER,
      };
      for (final entry in answers.entries) {
        final vision = service((_) => answer(entry.key));
        expect(await vision.classify(_photo), entry.value, reason: entry.key.trim());
      }
    });

    test('ignores the thought signature part Gemini adds', () async {
      final vision = service((_) async => http.Response(_gemini('FURNITURE', withThoughtSignature: true), 200));

      expect(await vision.classify(_photo), MaterialCategoryEnum.FURNITURE);
    });

    test('joins an answer split across several text parts', () async {
      final vision = service((_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'LAB_'},
                      {'text': 'EQUIPMENT'},
                    ],
                  },
                },
              ],
            }),
            200,
          ));

      expect(await vision.classify(_photo), MaterialCategoryEnum.LAB_EQUIPMENT);
    });

    test('returns null when the answer is not one of the categories', () async {
      for (final text in ['I think this is a textbook', 'MICROSCOPE', 'BOOKS or OTHER', '']) {
        final vision = service((_) => answer(text));
        expect(await vision.classify(_photo), isNull, reason: text);
      }
    });

    test('returns null without calling the API when there is no key', () async {
      var calls = 0;
      final vision = service((_) async {
        calls++;
        return http.Response(_gemini('BOOKS'), 200);
      }, apiKey: '');

      expect(await vision.classify(_photo), isNull);
      expect(calls, 0);
    });

    test('returns null on an HTTP error', () async {
      for (final status in [400, 403, 404, 429, 500, 503]) {
        final vision = service((_) async => http.Response('{"error":{"code":$status,"message":"nope"}}', status));
        expect(await vision.classify(_photo), isNull, reason: '$status');
      }
    });

    test('returns null when there is no connection', () async {
      final vision = service((_) async => throw http.ClientException('no route to host'));

      expect(await vision.classify(_photo), isNull);
    });

    test('returns null when the body is not what we expect', () async {
      const bodies = [
        'not json',
        'null',
        '[]',
        '{}',
        '{"candidates":[]}',
        '{"candidates":[{"finishReason":"SAFETY"}]}',
        '{"candidates":[{"content":{"parts":[]}}]}',
        '{"promptFeedback":{"blockReason":"SAFETY"}}',
      ];
      for (final body in bodies) {
        final vision = service((_) async => http.Response(body, 200));
        expect(await vision.classify(_photo), isNull, reason: body);
      }
    });

    test('returns null when the service takes too long', () async {
      final never = Completer<http.Response>();
      final vision = service((_) => never.future, timeout: const Duration(milliseconds: 20));

      expect(await vision.classify(_photo), isNull);
    });
  });

  group('ClassifyItemPhotoUseCase', () {
    test('returns the category found by the classifier', () async {
      final useCase = ClassifyItemPhotoUseCase(_FakeClassifier(MaterialCategoryEnum.FURNITURE));

      expect(await useCase.execute(_photo), MaterialCategoryEnum.FURNITURE);
    });

    test('an empty photo is not sent anywhere', () async {
      final classifier = _FakeClassifier(MaterialCategoryEnum.BOOKS);

      expect(await ClassifyItemPhotoUseCase(classifier).execute(Uint8List(0)), isNull);
      expect(classifier.calls, 0);
    });

    test('a classifier that throws still gives null', () async {
      final useCase = ClassifyItemPhotoUseCase(_FakeClassifier(null, throws: true));

      expect(await useCase.execute(_photo), isNull);
    });
  });
}

class _FakeClassifier implements ItemPhotoClassifier {
  final MaterialCategoryEnum? answer;
  final bool throws;
  int calls = 0;

  _FakeClassifier(this.answer, {this.throws = false});

  @override
  Future<MaterialCategoryEnum?> classify(Uint8List imageBytes) async {
    calls++;
    if (throws) throw StateError('boom');
    return answer;
  }
}
