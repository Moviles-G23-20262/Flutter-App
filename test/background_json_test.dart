import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/dto/marketplace_models.dart';
import 'package:flutter_front_end/model/services/background_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tells which isolate mapped an item: "parse-json-list" is the background one.
String _isolateName(Map<String, dynamic> _) => Isolate.current.debugName ?? '';

Map<String, dynamic> _wishlistJson(int i) => {
      'id': 'w$i',
      'userId': 'ana',
      'materialId': 'm$i',
      'createdAt': '2026-10-20T10:00:00.000Z',
    };

void main() {
  group('decodeJson', () {
    test('a short answer and a long one decode to the same value', () async {
      final text = jsonEncode([for (var i = 0; i < 50; i++) _wishlistJson(i)]);

      final onUiThread = await decodeJson(text, threshold: text.length + 1);
      final inIsolate = await decodeJson(text, threshold: 1);

      expect(inIsolate, onUiThread);
      expect((inIsolate as List).length, 50);
    });

    test('invalid JSON still throws a FormatException from the isolate', () async {
      expect(decodeJson('{"oops"', threshold: 1), throwsA(isA<FormatException>()));
    });
  });

  group('parseListInBackground', () {
    test('a short list is mapped on the UI thread', () async {
      final names = await parseListInBackground([<String, dynamic>{}, <String, dynamic>{}], _isolateName, threshold: 3);

      expect(names, isNot(contains('parse-json-list')));
    });

    test('a long list is mapped in a background isolate', () async {
      final names = await parseListInBackground(List.filled(5, <String, dynamic>{}), _isolateName, threshold: 3);

      expect(names.toSet(), {'parse-json-list'});
    });

    test('entities come back complete and in the same order', () async {
      final json = [for (var i = 0; i < backgroundParseThreshold + 20; i++) _wishlistJson(i)];

      final items = await parseListInBackground(json, wishlistItemFromJson);

      expect(items.map((w) => w.id), [for (var i = 0; i < json.length; i++) 'w$i']);
      expect(items.last.materialId, 'm${json.length - 1}');
    });
  });

  group('ApiClient', () {
    ApiClient clientAnswering(int status, String body) => ApiClient(
          baseUrl: 'https://api.test',
          client: MockClient((_) async => http.Response(body, status)),
        );

    test('a long answer (decoded in an isolate) arrives the same as a short one', () async {
      final long = jsonEncode([for (var i = 0; i < 1000; i++) _wishlistJson(i)]);
      expect(long.length, greaterThan(backgroundDecodeThreshold));

      final decoded = await clientAnswering(200, long).get('/wishlist-items') as List;

      expect(decoded.length, 1000);
      expect(decoded.first['id'], 'w0');
    });

    test('errors are still reported with the server message', () async {
      final client = clientAnswering(409, jsonEncode({'message': 'Already in your wishlist'}));

      expect(
        client.get('/wishlist-items'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Already in your wishlist')),
      );
    });

    test('an empty body is null', () async {
      expect(await clientAnswering(204, '').delete('/wishlist-items/w1'), isNull);
    });
  });
}
