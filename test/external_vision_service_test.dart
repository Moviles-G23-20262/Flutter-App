import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_front_end/Data/services/external_vision_service.dart';
import 'package:flutter_front_end/Domain/Entities/material_entity.dart';
import 'package:flutter_front_end/Domain/repositories/item_photo_classifier.dart';
import 'package:flutter_front_end/Domain/use_cases/classify_item_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _photo = Uint8List.fromList([1, 2, 3, 4]);

String _scores(Map<String, double> scores) =>
    jsonEncode([for (final e in scores.entries) {'label': e.key, 'score': e.value}]);

void main() {
  group('ExternalVisionService', () {
    late http.Request seen;

    ExternalVisionService service(
      Future<http.Response> Function(http.Request) handler, {
      String? token,
      Duration timeout = const Duration(seconds: 5),
    }) =>
        ExternalVisionService(
          client: MockClient((request) {
            seen = request;
            return handler(request);
          }),
          apiToken: token,
          timeout: timeout,
        );

    test('sends the photo and the candidate labels to the CLIP endpoint', () async {
      final vision = service((_) async => http.Response(_scores({'books': 0.9}), 200), token: 'hf_x');

      await vision.classify(_photo);

      expect(seen.method, 'POST');
      expect(
        seen.url.toString(),
        'https://api-inference.huggingface.co/models/openai/clip-vit-base-patch32',
      );
      expect(seen.headers['Authorization'], 'Bearer hf_x');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['inputs'], base64Encode(_photo));
      expect(
        (body['parameters'] as Map)['candidate_labels'],
        ['books', 'calculators', 'lab equipment', 'furniture', 'other'],
      );
    });

    test('works without a token', () async {
      final vision = service((_) async => http.Response(_scores({'books': 0.9}), 200));

      await vision.classify(_photo);

      expect(seen.headers.containsKey('Authorization'), isFalse);
    });

    test('maps every label to its category', () async {
      const expected = {
        'books': MaterialCategoryEnum.BOOKS,
        'calculators': MaterialCategoryEnum.CALCULATORS,
        'lab equipment': MaterialCategoryEnum.LAB_EQUIPMENT,
        'furniture': MaterialCategoryEnum.FURNITURE,
        'other': MaterialCategoryEnum.OTHER,
      };
      for (final entry in expected.entries) {
        final vision = service((_) async => http.Response(_scores({entry.key: 0.8}), 200));
        expect(await vision.classify(_photo), entry.value, reason: entry.key);
      }
    });

    test('picks the label with the highest score, whatever the order', () async {
      final vision = service((_) async => http.Response(
            _scores({'books': 0.1, 'furniture': 0.15, 'calculators': 0.7, 'other': 0.05}),
            200,
          ));

      expect(await vision.classify(_photo), MaterialCategoryEnum.CALCULATORS);
    });

    test('ignores labels it does not know', () async {
      final vision = service((_) async => http.Response(_scores({'spaceship': 0.99, 'books': 0.2}), 200));

      expect(await vision.classify(_photo), MaterialCategoryEnum.BOOKS);
    });

    test('returns null on an HTTP error', () async {
      for (final status in [401, 429, 500, 503]) {
        final vision = service((_) async => http.Response('{"error":"nope"}', status));
        expect(await vision.classify(_photo), isNull, reason: '$status');
      }
    });

    test('returns null when there is no connection', () async {
      final vision = service((_) async => throw http.ClientException('no route to host'));

      expect(await vision.classify(_photo), isNull);
    });

    test('returns null when the body is not what we expect', () async {
      for (final body in ['not json', '{"error":"loading"}', '[]', '[{"label":"books"}]', 'null']) {
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
