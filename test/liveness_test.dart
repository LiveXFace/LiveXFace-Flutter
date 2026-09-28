import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livexface/livexface.dart';

const _base = 'https://api.test/api/v1';

/// JPEG magic bytes, enough for the mime sniffer.
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

http.Response _ok(Map<String, dynamic> data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );

/// Multipart bodies are bytes; latin1 keeps them 1:1 for string matching.
String _body(http.Request req) => latin1.decode(req.bodyBytes);

Map<String, dynamic> _challenges({required bool passed}) => {
      'blink': {'passed': passed, 'available': true, 'blinkCount': 2},
      'headTurn': {'passed': passed, 'available': true, 'yawRange': 31.5},
      'passiveAntispoof': {'passed': null, 'available': false},
    };

void main() {
  late http.Request captured;

  LiveXFaceClient clientReturning(http.Response response) => LiveXFaceClient(
        apiKey: 'lxf_test_key',
        baseUrl: _base,
        httpClient: MockClient((req) async {
          captured = req;
          return response;
        }),
      );

  group('activeLiveness', () {
    test('sends frame_0..frame_n to the right URL and parses the token',
        () async {
      final client = clientReturning(_ok({
        'isLive': true,
        'overallScore': 0.93,
        'framesAnalyzed': 6,
        'framesWithFace': 6,
        'challenges': _challenges(passed: true),
        'livenessToken': 'lvt_abc',
        'livenessTokenExpiresAt': '2026-09-28T10:05:00Z',
      }));

      final result = await client.faces.activeLiveness(
        collectionId: 'col_1',
        frames: List.filled(6, _jpeg),
      );

      expect(captured.method, 'POST');
      expect(
          captured.url.toString(), '$_base/collections/col_1/active-liveness');
      expect(captured.headers['X-API-Key'], 'lxf_test_key');
      final body = _body(captured);
      for (var i = 0; i < 6; i++) {
        expect(body, contains('name="frame_$i"'));
      }
      expect(body, isNot(contains('name="frame_6"')));

      expect(result.isLive, isTrue);
      expect(result.overallScore, 0.93);
      expect(result.framesAnalyzed, 6);
      expect(result.framesWithFace, 6);
      expect(result.livenessToken, 'lvt_abc');
      expect(result.livenessTokenExpiresAt, DateTime.utc(2026, 9, 28, 10, 5));
      expect(result.challenges.blink.passed, isTrue);
      expect(result.challenges.blink.metrics['blinkCount'], 2);
      expect(result.challenges.headTurn.metrics['yawRange'], 31.5);
      expect(result.challenges.passiveAntispoof.passed, isNull);
      expect(result.challenges.passiveAntispoof.available, isFalse);
    });

    test('a failed check parses with no token', () async {
      final client = clientReturning(_ok({
        'isLive': false,
        'overallScore': 0.21,
        'framesAnalyzed': 5,
        'framesWithFace': 4,
        'challenges': _challenges(passed: false),
      }));

      final result = await client.faces.activeLiveness(
        collectionId: 'col_1',
        frames: List.filled(5, _jpeg),
      );

      expect(result.isLive, isFalse);
      expect(result.livenessToken, isNull);
      expect(result.livenessTokenExpiresAt, isNull);
      expect(result.challenges.blink.passed, isFalse);
      expect(result.challenges.headTurn.passed, isFalse);
    });

    test('too few frames surfaces the 400 as a validation error', () async {
      final client = clientReturning(http.Response(
        jsonEncode({
          'success': false,
          'error': {'code': 'IMAGE_REQUIRED', 'message': 'need 5 frames'},
        }),
        400,
      ));

      expect(
        client.faces
            .activeLiveness(collectionId: 'col_1', frames: [_jpeg, _jpeg]),
        throwsA(isA<LiveXFaceValidationException>()
            .having((e) => e.code, 'code', 'IMAGE_REQUIRED')),
      );
    });
  });

  group('register', () {
    final face = {
      'id': 'face_1',
      'collectionId': 'col_1',
      'externalId': 'user-1',
      'createdAt': '2026-09-28T10:00:00Z',
    };

    test('sends liveness_token when given', () async {
      final client = clientReturning(_ok(face));
      await client.faces.register(
        collectionId: 'col_1',
        image: _jpeg,
        externalId: 'user-1',
        livenessToken: 'lvt_abc',
      );

      expect(captured.url.toString(), '$_base/collections/col_1/faces');
      final body = _body(captured);
      expect(body, contains('name="liveness_token"'));
      expect(body, contains('lvt_abc'));
    });

    test('omits liveness_token when not given', () async {
      final client = clientReturning(_ok(face));
      await client.faces.register(
        collectionId: 'col_1',
        image: _jpeg,
        externalId: 'user-1',
      );

      expect(_body(captured), isNot(contains('liveness_token')));
    });

    test('LIVENESS_TOKEN_INVALID arrives as a validation error', () async {
      final client = clientReturning(http.Response(
        jsonEncode({
          'success': false,
          'error': {'code': 'LIVENESS_TOKEN_INVALID', 'message': 'spent'},
        }),
        422,
      ));

      expect(
        client.faces.register(
            collectionId: 'col_1',
            image: _jpeg,
            externalId: 'user-1',
            livenessToken: 'lvt_used'),
        throwsA(isA<LiveXFaceValidationException>()
            .having((e) => e.code, 'code', 'LIVENESS_TOKEN_INVALID')),
      );
    });
  });

  group('batchRegisterAsync', () {
    test('entries serialize livenessToken only when set', () async {
      final client = clientReturning(_ok({'id': 'job_1', 'status': 'queued'}));
      await client.faces.batchRegisterAsync(
        collectionId: 'col_1',
        items: [
          BatchRegisterItem(
              externalId: 'a', image: _jpeg, livenessToken: 'lvt_a'),
          BatchRegisterItem(externalId: 'b', image: _jpeg),
        ],
      );

      expect(captured.url.toString(),
          '$_base/collections/col_1/faces/batch-async');
      final body = _body(captured);
      final match = RegExp(r'name="entries"\r\n\r\n(.*?)\r\n--', dotAll: true)
          .firstMatch(body);
      expect(match, isNotNull);
      final entries = jsonDecode(match!.group(1)!) as List<dynamic>;
      expect(entries[0], {
        'externalId': 'a',
        'metadata': <String, dynamic>{},
        'livenessToken': 'lvt_a'
      });
      expect(entries[1], {'externalId': 'b', 'metadata': <String, dynamic>{}});
    });
  });
}
