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
    test('sends frame_0..frame_n to the right URL and parses the verdict',
        () async {
      final client = clientReturning(_ok({
        'isLive': true,
        'overallScore': 0.93,
        'framesAnalyzed': 6,
        'framesWithFace': 6,
        'challenges': _challenges(passed: true),
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
      expect(result.challenges.blink.passed, isTrue);
      expect(result.challenges.blink.metrics['blinkCount'], 2);
      expect(result.challenges.headTurn.metrics['yawRange'], 31.5);
      expect(result.challenges.passiveAntispoof.passed, isNull);
      expect(result.challenges.passiveAntispoof.available, isFalse);
    });

    test('the result has no token, even if a server sends one', () async {
      final client = clientReturning(_ok({
        'isLive': true,
        'overallScore': 0.93,
        'framesAnalyzed': 5,
        'framesWithFace': 5,
        'challenges': _challenges(passed: true),
        'livenessToken': 'lvt_abc',
        'livenessTokenExpiresAt': '2026-09-28T10:05:00Z',
      }));

      final result = await client.faces.activeLiveness(
        collectionId: 'col_1',
        frames: List.filled(5, _jpeg),
      );

      expect(result, isNot(isA<LivenessSessionResult>()));
      expect(() => (result as dynamic).livenessToken,
          throwsA(isA<NoSuchMethodError>()));
      expect(() => (result as dynamic).livenessTokenExpiresAt,
          throwsA(isA<NoSuchMethodError>()));
    });

    test('a failed check parses', () async {
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

  group('liveness sessions', () {
    test('create posts no body and returns the challenges in order', () async {
      final client = clientReturning(http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'sessionId': 'lvs_abc',
            'challenges': [
              {'type': 'turn_left'},
              {'type': 'blink'},
              {'type': 'turn_right'},
            ],
            'expiresAt': '2026-10-03T10:01:00Z',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      ));

      final session =
          await client.faces.createLivenessSession(collectionId: 'col_1');

      expect(captured.method, 'POST');
      expect(captured.url.toString(),
          '$_base/collections/col_1/liveness-sessions');
      expect(captured.bodyBytes, isEmpty);
      expect(captured.headers['Idempotency-Key'], isNull);
      expect(session.sessionId, 'lvs_abc');
      expect(session.challenges, ['turn_left', 'blink', 'turn_right']);
      expect(session.expiresAt, DateTime.utc(2026, 10, 3, 10, 1));
    });

    test('complete sends frames and mirrored, and parses steps and token',
        () async {
      final client = clientReturning(_ok({
        'isLive': true,
        'overallScore': 0.91,
        'framesAnalyzed': 25,
        'framesWithFace': 25,
        'challenges': _challenges(passed: true),
        'steps': [
          {'type': 'turn_left', 'passed': true},
          {'type': 'blink', 'passed': true},
        ],
        'livenessToken': 'lvt_abc',
        'livenessTokenExpiresAt': '2026-10-03T10:06:00Z',
      }));

      final result = await client.faces.completeLivenessSession(
        collectionId: 'col_1',
        sessionId: 'lvs_abc',
        frames: List.filled(25, _jpeg),
        mirrored: true,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(),
          '$_base/collections/col_1/liveness-sessions/lvs_abc');
      expect(captured.headers['Idempotency-Key'], isNull);
      final body = _body(captured);
      for (var i = 0; i < 25; i++) {
        expect(body, contains('name="frame_$i"'));
      }
      expect(body, isNot(contains('name="frame_25"')));
      expect(body, contains('name="mirrored"\r\n\r\ntrue\r\n'));

      expect(result.isLive, isTrue);
      expect(result.overallScore, 0.91);
      expect(result.framesAnalyzed, 25);
      expect(result.challenges.blink.passed, isTrue);
      expect([for (final s in result.steps) (s.type, s.passed)],
          [('turn_left', true), ('blink', true)]);
      expect(result.livenessToken, 'lvt_abc');
      expect(result.livenessTokenExpiresAt, DateTime.utc(2026, 10, 3, 10, 6));
    });

    test('mirrored defaults to false', () async {
      final client = clientReturning(_ok({'isLive': false}));
      await client.faces.completeLivenessSession(
          collectionId: 'col_1',
          sessionId: 'lvs_abc',
          frames: List.filled(5, _jpeg));

      expect(_body(captured), contains('name="mirrored"\r\n\r\nfalse\r\n'));
    });

    test('a failing completion has no token', () async {
      final client = clientReturning(_ok({
        'isLive': false,
        'overallScore': 0.4,
        'framesAnalyzed': 20,
        'framesWithFace': 20,
        'challenges': _challenges(passed: false),
        'steps': [
          {'type': 'blink', 'passed': true},
          {'type': 'turn_right', 'passed': false},
        ],
      }));

      final result = await client.faces.completeLivenessSession(
          collectionId: 'col_1',
          sessionId: 'lvs_abc',
          frames: List.filled(20, _jpeg));

      expect(result.isLive, isFalse);
      expect(result.steps.last.type, 'turn_right');
      expect(result.steps.last.passed, isFalse);
      expect(result.livenessToken, isNull);
      expect(result.livenessTokenExpiresAt, isNull);
    });

    test('LIVENESS_SESSION_INVALID arrives as a validation error', () async {
      final client = clientReturning(http.Response(
        jsonEncode({
          'success': false,
          'requestId': 'req-422',
          'error': {
            'code': 'LIVENESS_SESSION_INVALID',
            'message': 'session expired or already used',
          },
        }),
        422,
      ));

      await expectLater(
        client.faces.completeLivenessSession(
            collectionId: 'col_1',
            sessionId: 'lvs_used',
            frames: List.filled(5, _jpeg)),
        throwsA(isA<LiveXFaceValidationException>()
            .having((e) => e.code, 'code', 'LIVENESS_SESSION_INVALID')
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.requestId, 'requestId', 'req-422')),
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
