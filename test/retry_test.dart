import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livexface/livexface.dart';

const _base = 'https://api.test/api/v1';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

const _face = {
  'id': 'face_1',
  'collectionId': 'col_1',
  'externalId': 'emp-1',
  'createdAt': '2026-10-03T10:00:00Z',
};

http.Response _json(int status, Map<String, dynamic> body,
        [Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json', ...headers});

http.Response _error(int status, String code,
        [Map<String, String> headers = const {}]) =>
    _json(
        status,
        {
          'success': false,
          'requestId': 'req-$status',
          'error': {'code': code, 'message': code.toLowerCase()},
        },
        headers);

final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  late List<http.Request> requests;
  late List<Duration> sleeps;

  /// A client whose server answers each request with the next of [responses];
  /// a `null` entry fails the request as a transport error.
  LiveXFaceClient client(List<http.Response?> responses, {int maxRetries = 0}) {
    final queue = [...responses];
    return LiveXFaceClient(
      apiKey: 'lxf_test_key',
      baseUrl: _base,
      maxRetries: maxRetries,
      sleep: (d) async => sleeps.add(d),
      httpClient: MockClient((req) async {
        requests.add(req);
        return queue.removeAt(0) ??
            (throw http.ClientException('Connection reset by peer'));
      }),
    );
  }

  Future<Face> register(LiveXFaceClient c, {String? idempotencyKey}) =>
      c.faces.register(
          collectionId: 'col_1',
          image: _jpeg,
          externalId: 'emp-1',
          idempotencyKey: idempotencyKey);

  setUp(() {
    requests = [];
    sleeps = [];
  });

  test(
      '429 exposes status, code, requestId and retryAfter; no retry by default',
      () async {
    final c = client([
      _error(429, 'RATE_LIMIT_EXCEEDED', {'retry-after': '12'})
    ]);

    await expectLater(
      register(c),
      throwsA(isA<LiveXFaceRateLimitException>()
          .having((e) => e.statusCode, 'statusCode', 429)
          .having((e) => e.code, 'code', 'RATE_LIMIT_EXCEEDED')
          .having((e) => e.requestId, 'requestId', 'req-429')
          .having((e) => e.retryAfter, 'retryAfter', 12)),
    );
    expect(requests, hasLength(1));
  });

  test('503 with Retry-After is retried with the same generated key', () async {
    final c = client([
      _error(503, 'SERVICE_BUSY', {'retry-after': '5'}),
      _json(201, {'success': true, 'data': _face}),
    ], maxRetries: 2);

    final face = await register(c);

    expect(face.id, 'face_1');
    expect(requests, hasLength(2));
    final key = requests[0].headers['idempotency-key'];
    expect(key, matches(_uuidV4));
    expect(requests[1].headers['idempotency-key'], key);
    expect(sleeps, [const Duration(seconds: 5)]);
  });

  test('Retry-After is capped at maxRetryDelay', () async {
    final c = LiveXFaceClient(
      apiKey: 'k',
      baseUrl: _base,
      maxRetries: 1,
      maxRetryDelay: const Duration(seconds: 2),
      sleep: (d) async => sleeps.add(d),
      httpClient: MockClient((_) async =>
          _error(429, 'RATE_LIMIT_EXCEEDED', {'retry-after': '3600'})),
    );

    await expectLater(register(c), throwsA(isA<LiveXFaceRateLimitException>()));
    expect(sleeps, [const Duration(seconds: 2)]);
  });

  test('a dropped connection is retried and the replay returned', () async {
    // A real socket closed without an answer, not a mocked exception.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final keys = <String?>[];
    server.listen((req) async {
      keys.add(req.headers.value('idempotency-key'));
      await req.drain<void>();
      if (keys.length == 1) {
        (await req.response.detachSocket(writeHeaders: false)).destroy();
        return;
      }
      req.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..headers.set('Idempotent-Replayed', 'true')
        ..write(jsonEncode({'success': true, 'data': _face}));
      await req.response.close();
    });

    final c = LiveXFaceClient(
      apiKey: 'k',
      baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
      maxRetries: 1,
      sleep: (d) async => sleeps.add(d),
    );
    addTearDown(c.dispose);

    final face = await register(c, idempotencyKey: 'enrol-emp-1');

    expect(face.id, 'face_1');
    expect(keys, ['enrol-emp-1', 'enrol-emp-1']);
  });

  test('422 is never retried', () async {
    final c = client([_error(422, 'NO_FACE_DETECTED')], maxRetries: 3);

    await expectLater(
      register(c),
      throwsA(isA<LiveXFaceNoFaceDetectedException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.requestId, 'requestId', 'req-422')),
    );
    expect(requests, hasLength(1));
  });

  test('caller key is sent; no key and retries off sends no header', () async {
    final ok = _json(201, {'success': true, 'data': _face});
    final job = _json(202, {
      'success': true,
      'data': {'id': 'job_1', 'status': 'pending', 'total': 1},
    });
    final c = client([ok, ok, job, job]);

    await register(c, idempotencyKey: 'caller-key');
    await register(c);
    final items = [BatchRegisterItem(image: _jpeg, externalId: 'emp-1')];
    await c.faces.batchRegisterAsync(
        collectionId: 'col_1', items: items, idempotencyKey: 'batch-key');
    await c.faces.batchRegisterAsync(collectionId: 'col_1', items: items);

    expect(requests.map((r) => r.headers['idempotency-key']),
        ['caller-key', null, 'batch-key', null]);
  });

  test('generateIdempotencyKey returns distinct UUID v4 strings', () {
    final a = generateIdempotencyKey();
    final b = generateIdempotencyKey();
    expect(a, matches(_uuidV4));
    expect(b, matches(_uuidV4));
    expect(a, isNot(b));
  });

  group('a POST without a key', () {
    Future<IdentifyResult> identify(LiveXFaceClient c) =>
        c.faces.identify(collectionId: 'col_1', image: _jpeg);

    test('is not retried on a network error', () async {
      final c = client([null, null], maxRetries: 3);
      await expectLater(identify(c), throwsA(isA<LiveXFaceNetworkException>()));
      expect(requests, hasLength(1));
    });

    test('is not retried on a 500', () async {
      final c = client([_error(500, 'INTERNAL_ERROR')], maxRetries: 3);
      await expectLater(
          identify(c),
          throwsA(isA<LiveXFaceServerException>()
              .having((e) => e.statusCode, 'statusCode', 500)));
      expect(requests, hasLength(1));
    });

    test('is retried on a 503, then surfaces the last error', () async {
      final c = client([
        _error(503, 'SERVICE_BUSY'),
        _error(503, 'SERVICE_BUSY', {'retry-after': '1'}),
      ], maxRetries: 1);
      await expectLater(
          identify(c),
          throwsA(isA<LiveXFaceServerException>()
              .having((e) => e.retryAfter, 'retryAfter', 1)));
      expect(requests, hasLength(2));
      expect(requests[0].headers['idempotency-key'], isNull);
      // No Retry-After: jittered backoff within 0.5 s.
      expect(
          sleeps.single, lessThanOrEqualTo(const Duration(milliseconds: 500)));
    });
  });

  group('liveness-session completion', () {
    Future<LivenessSessionResult> complete(LiveXFaceClient c) =>
        c.faces.completeLivenessSession(
            collectionId: 'col_1',
            sessionId: 'lvs_1',
            frames: List.filled(5, _jpeg));

    test('is not retried on a dropped connection', () async {
      final c = client([null, null], maxRetries: 3);
      await expectLater(complete(c), throwsA(isA<LiveXFaceNetworkException>()));
      expect(requests, hasLength(1));
      expect(requests.single.headers['idempotency-key'], isNull);
      expect(sleeps, isEmpty);
    });

    test('is not retried on a 503: the session is already used up', () async {
      final c = client([
        _error(503, 'SERVICE_BUSY', {'retry-after': '1'}),
        _json(200, {
          'success': true,
          'data': {'isLive': true}
        }),
      ], maxRetries: 3);
      await expectLater(
          complete(c),
          throwsA(isA<LiveXFaceServerException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.code, 'code', 'SERVICE_BUSY')));
      expect(requests, hasLength(1));
      expect(sleeps, isEmpty);
    });

    test('is retried on a 429 after Retry-After', () async {
      final c = client([
        _error(429, 'RATE_LIMIT_EXCEEDED', {'retry-after': '2'}),
        _json(200, {
          'success': true,
          'data': {'isLive': true, 'livenessToken': 'lvt_abc'},
        }),
      ], maxRetries: 3);
      final result = await complete(c);
      expect(result.livenessToken, 'lvt_abc');
      expect(requests, hasLength(2));
      expect(sleeps, [const Duration(seconds: 2)]);
    });
  });

  group('batchRegister', () {
    final items = [
      BatchRegisterItem(
          image: _jpeg, externalId: 'emp-1', livenessToken: 'lvt_1'),
      BatchRegisterItem(
          image: _jpeg, externalId: 'emp-2', metadata: {'team': 'ops'}),
    ];
    final ok = _json(200, {
      'success': true,
      'data': {
        'succeeded': 1,
        'failed': 1,
        'results': [
          {'externalId': 'emp-1', 'face': _face},
          {'externalId': 'emp-2', 'error': 'no face detected'},
        ],
      },
    });

    test('posts images[i] and entries and parses per-item results', () async {
      final c = client([ok]);

      final res = await c.faces.batchRegister(
          collectionId: 'col_1', items: items, idempotencyKey: 'batch-key');

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/collections/col_1/faces/batch');
      expect(req.headers['idempotency-key'], 'batch-key');
      final body = latin1.decode(req.bodyBytes);
      expect(body, contains('name="images[0]"; filename="emp-1.jpg"'));
      expect(body, contains('name="images[1]"; filename="emp-2.jpg"'));
      expect(
          body,
          contains(jsonEncode([
            {'externalId': 'emp-1', 'metadata': {}, 'livenessToken': 'lvt_1'},
            {
              'externalId': 'emp-2',
              'metadata': {'team': 'ops'}
            },
          ])));

      expect(res.succeeded, 1);
      expect(res.failed, 1);
      expect(res.results[0].face?.id, 'face_1');
      expect(res.results[1].face, isNull);
      expect(res.results[1].error, 'no face detected');
    });

    test('a 503 is retried with the same generated key', () async {
      final c = client([
        _error(503, 'SERVICE_BUSY', {'retry-after': '2'}),
        ok,
      ], maxRetries: 1);

      final res =
          await c.faces.batchRegister(collectionId: 'col_1', items: items);

      expect(res.succeeded, 1);
      expect(requests, hasLength(2));
      final key = requests[0].headers['idempotency-key'];
      expect(key, matches(_uuidV4));
      expect(requests[1].headers['idempotency-key'], key);
      expect(sleeps, [const Duration(seconds: 2)]);
    });
  });
}
