import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'exceptions.dart';
import 'types.dart';

const _defaultBaseUrl = 'https://api.livexface.com/api/v1';

/// The API contract version (`/openapi.json` `info.version`) this release is
/// validated against.
const contractVersion = '1.0.0';

final _keyRandom = Random.secure();
final _jitter = Random();

/// A random UUID v4 to pass as `idempotencyKey`. Generate one per logical
/// operation and reuse it when you retry that operation yourself.
String generateIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _keyRandom.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Main entry point for the LiveXFace SDK.
///
/// ```dart
/// final client = LiveXFaceClient(apiKey: 'lxf_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
///   faceId: 'face_id',
/// );
/// ```
///
/// Collections are created and managed in the dashboard; the API has no
/// endpoints for that, so the client has no collection operations.
class LiveXFaceClient {
  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  /// Automatic retries after the first attempt; 0 (the default) turns them
  /// off. 429 and 503 are retried after `Retry-After` (or a jittered
  /// backoff); network errors and other 5xx only for GET, PATCH, DELETE and
  /// requests with an idempotency key; other 4xx never.
  final int maxRetries;

  /// The longest single wait between retries.
  final Duration maxRetryDelay;

  final Future<void> Function(Duration) _sleep;

  /// [sleep] replaces the wait between retries, e.g. to skip it in tests.
  LiveXFaceClient({
    required this.apiKey,
    this.baseUrl = _defaultBaseUrl,
    http.Client? httpClient,
    this.maxRetries = 0,
    this.maxRetryDelay = const Duration(seconds: 60),
    Future<void> Function(Duration)? sleep,
  })  : _http = httpClient ?? http.Client(),
        _sleep = sleep ?? Future<void>.delayed;

  late final FacesApi faces = FacesApi._(this);

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> get _headers => {
        'X-API-Key': apiKey,
        'Accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Future<Map<String, dynamic>> _get(String path,
          [Map<String, String>? query]) =>
      _send(
          'GET $path',
          () =>
              http.Request('GET', _uri(path, query))..headers.addAll(_headers));

  Future<Map<String, dynamic>> _postMultipart(
    String path,
    Uint8List imageBytes, {
    String imageField = 'image',
    Map<String, String>? fields,
    String? filename,
    String? idempotencyKey,
  }) {
    final name = filename ?? 'image.jpg';
    final mime = lookupMimeType(name, headerBytes: imageBytes) ?? 'image/jpeg';
    return _postMultipartFiles(
      path,
      () => [
        http.MultipartFile.fromBytes(imageField, imageBytes,
            filename: name, contentType: _mediaType(mime)),
      ],
      fields: fields,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Multipart POST with multiple image files (batch registration,
  /// active liveness).
  ///
  /// [files] is called once per attempt: a [http.MultipartFile] can only be
  /// sent once, so a retry needs fresh ones.
  Future<Map<String, dynamic>> _postMultipartFiles(
    String path,
    List<http.MultipartFile> Function() files, {
    Map<String, String>? fields,
    String? idempotencyKey,
  }) =>
      _send('POST $path (multipart)', () {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers)
          ..files.addAll(files());
        if (idempotencyKey != null) {
          req.headers['Idempotency-Key'] = idempotencyKey;
        }
        if (fields != null) req.fields.addAll(fields);
        return req;
      });

  Future<void> _delete(String path, [Map<String, String>? query]) => _send(
      'DELETE $path',
      () =>
          http.Request('DELETE', _uri(path, query))..headers.addAll(_headers));

  /// The key enrolment and batch calls send: the caller's, else one generated
  /// per call when retries are on, so every attempt carries the same key.
  String? _idempotencyKey(String? key) =>
      key ?? (maxRetries > 0 ? generateIdempotencyKey() : null);

  /// Sends the request [build] makes, retrying per [maxRetries]: 429 and 503
  /// always; network errors and other 5xx only when repeating is harmless
  /// (GET, PATCH, DELETE, or a request with an `Idempotency-Key`).
  Future<Map<String, dynamic>> _send(
      String label, http.BaseRequest Function() build) async {
    for (var attempt = 0;; attempt++) {
      final req = build();
      final repeatable =
          const {'GET', 'PATCH', 'DELETE'}.contains(req.method) ||
              req.headers.containsKey('Idempotency-Key');
      int? retryAfter;
      try {
        final res = await http.Response.fromStream(await _http.send(req));
        return _handle(res);
      } on LiveXFaceApiException catch (e) {
        final status = e.statusCode ?? 0;
        final throttled = status == 429 || status == 503;
        if (attempt >= maxRetries ||
            !(throttled || (repeatable && status >= 500))) {
          rethrow;
        }
        if (throttled) retryAfter = e.retryAfter;
      } catch (e) {
        if (attempt >= maxRetries || !repeatable) {
          throw LiveXFaceNetworkException('$label failed', e);
        }
      }
      await _sleep(_retryDelay(attempt, retryAfter));
    }
  }

  /// `Retry-After` when given, else 0.5 s * 2^attempt with full jitter; both
  /// capped at [maxRetryDelay].
  Duration _retryDelay(int attempt, int? retryAfter) {
    final cap = maxRetryDelay.inMicroseconds;
    if (retryAfter != null) {
      return Duration(microseconds: min(retryAfter * 1000000, cap));
    }
    final backoff = min(500000 * pow(2, attempt), cap);
    return Duration(microseconds: (_jitter.nextDouble() * backoff).round());
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }

    final retryAfter = int.tryParse(res.headers['retry-after']?.trim() ?? '');

    // An unknown route answers with a plain-text 404, not the JSON envelope.
    // Decoding that used to throw, and the caller then reported a network
    // failure for what was an HTTP error.
    var body = <String, dynamic>{};
    try {
      final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Not JSON; fall through with the status code alone.
    }
    final err = body['error'] as Map<String, dynamic>?;
    final msg = err?['message'] as String? ?? 'API error ${res.statusCode}';
    final code = err?['code'] as String?;
    // Quote this when contacting support.
    final requestId = body['requestId'] as String?;
    final details = err?['details'] as Map<String, dynamic>?;
    final status = res.statusCode;

    switch (status) {
      case 400:
      case 422:
        if (code == 'NO_FACE_DETECTED') {
          throw LiveXFaceNoFaceDetectedException(msg, requestId, status);
        }
        // Declared long before the API could send it, and never thrown, so
        // a liveness refusal arrived as a generic validation error.
        if (code == 'SPOOF_DETECTED') {
          throw LiveXFaceSpoofDetectedException(msg, requestId, status);
        }
        throw LiveXFaceValidationException(msg,
            code: code,
            requestId: requestId,
            details: details,
            statusCode: status);
      case 401:
        throw LiveXFaceUnauthorizedException(msg,
            code: code,
            requestId: requestId,
            details: details,
            statusCode: status);
      case 403:
        throw LiveXFaceForbiddenException(msg,
            code: code,
            requestId: requestId,
            details: details,
            statusCode: status);
      case 404:
        throw LiveXFaceNotFoundException(msg,
            code: code,
            requestId: requestId,
            details: details,
            statusCode: status);
      case 402:
        throw LiveXFaceQuotaExceededException(msg,
            code: code,
            requestId: requestId,
            details: details,
            statusCode: status);
      case 429:
        throw LiveXFaceRateLimitException(msg, requestId, retryAfter);
      default:
        throw LiveXFaceServerException(msg, status,
            code: code,
            requestId: requestId,
            details: details,
            retryAfter: retryAfter);
    }
  }

  // ignore: deprecated_member_use
  http.MediaType _mediaType(String mime) {
    final parts = mime.split('/');
    return http.MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
  }

  void dispose() => _http.close();
}

// ---------------------------------------------------------------------------
// Faces API
// ---------------------------------------------------------------------------

class FacesApi {
  final LiveXFaceClient _client;
  FacesApi._(this._client);

  /// Enroll a new face into a collection.
  ///
  /// A collection that requires liveness refuses enrolment without a
  /// [livenessToken] from [activeLiveness] (`LIVENESS_TOKEN_REQUIRED`); a
  /// spent, expired or foreign token is `LIVENESS_TOKEN_INVALID`, and a token
  /// earned by a different face is `LIVENESS_FACE_MISMATCH`.
  ///
  /// With an [idempotencyKey] (see [generateIdempotencyKey]) a repeat of the
  /// same call within 24 hours returns the first result instead of enrolling
  /// the face twice.
  Future<Face> register({
    required String collectionId,
    required Uint8List image,
    required String externalId,
    Map<String, dynamic>? metadata,
    String? livenessToken,
    String? filename,
    String? idempotencyKey,
  }) async {
    final fields = <String, String>{'external_id': externalId};
    if (metadata != null) fields['metadata'] = jsonEncode(metadata);
    if (livenessToken != null) fields['liveness_token'] = livenessToken;

    final data = await _client._postMultipart(
      '/collections/$collectionId/faces',
      image,
      fields: fields,
      filename: filename,
      idempotencyKey: _client._idempotencyKey(idempotencyKey),
    );
    return Face.fromJson(data);
  }

  /// 1:1 verification — compare a probe image against a stored face.
  Future<VerifyResult> verify({
    required String collectionId,
    required Uint8List image,
    required String faceId,
    double? threshold,
    String? filename,
  }) async {
    final fields = <String, String>{'face_id': faceId};
    if (threshold != null) fields['threshold'] = threshold.toString();

    final data = await _client._postMultipart(
      '/collections/$collectionId/verify',
      image,
      fields: fields,
      filename: filename,
    );
    return VerifyResult.fromJson(data);
  }

  /// 1:N identification — find the closest matching face(s) in a collection.
  Future<IdentifyResult> identify({
    required String collectionId,
    required Uint8List image,
    int topK = 5,
    double? threshold,
    String? filename,
  }) async {
    final fields = <String, String>{'top_k': '$topK'};
    if (threshold != null) fields['threshold'] = threshold.toString();

    final data = await _client._postMultipart(
      '/collections/$collectionId/identify',
      image,
      fields: fields,
      filename: filename,
    );
    return IdentifyResult.fromJson(data);
  }

  /// Liveness detection — determine whether the presented face is live.
  Future<LivenessResult> liveness({
    required String collectionId,
    required Uint8List image,
    String? filename,
  }) async {
    final data = await _client._postMultipart(
      '/collections/$collectionId/liveness',
      image,
      filename: filename,
    );
    return LivenessResult.fromJson(data);
  }

  /// Active liveness — analyse a short burst of frames (5 to 50, JPEG or
  /// PNG) for a blink, a head turn and passive anti-spoofing.
  ///
  /// When the check passes, the result carries a single-use
  /// [ActiveLivenessResult.livenessToken], valid for 5 minutes and bound to
  /// this organization and collection, to pass to [register] or a batch item.
  Future<ActiveLivenessResult> activeLiveness({
    required String collectionId,
    required List<Uint8List> frames,
  }) async {
    List<http.MultipartFile> files() => [
          for (var i = 0; i < frames.length; i++)
            http.MultipartFile.fromBytes(
              'frame_$i',
              frames[i],
              filename: 'frame_$i.jpg',
              contentType: _client._mediaType(
                  lookupMimeType('frame_$i.jpg', headerBytes: frames[i]) ??
                      'image/jpeg'),
            ),
        ];

    final data = await _client._postMultipartFiles(
      '/collections/$collectionId/active-liveness',
      files,
    );
    return ActiveLivenessResult.fromJson(data);
  }

  /// Face attribute detection — age and gender.
  Future<FaceAttributes> attributes({
    required String collectionId,
    required Uint8List image,
    String? filename,
  }) async {
    final data = await _client._postMultipart(
      '/collections/$collectionId/attributes',
      image,
      filename: filename,
    );
    return FaceAttributes.fromJson(data);
  }

  /// Delete a face by ID.
  Future<void> delete({
    required String collectionId,
    required String faceId,
  }) =>
      _client._delete('/collections/$collectionId/faces/$faceId');

  /// Enroll up to 20 faces in one request and wait for the outcome of each.
  ///
  /// A failed item does not fail the call: check [BatchResponse.results].
  /// With an [idempotencyKey] a repeat of the same call within 24 hours
  /// returns the first response instead of enrolling the faces again.
  Future<BatchResponse> batchRegister({
    required String collectionId,
    required List<BatchRegisterItem> items,
    String? idempotencyKey,
  }) async =>
      BatchResponse.fromJson(await _postBatch(
          '/collections/$collectionId/faces/batch', items, idempotencyKey));

  /// Submit up to 100 faces for asynchronous registration.
  ///
  /// Returns the created job immediately; poll [getBatchJob] until
  /// [BatchJob.isFinished].
  ///
  /// With an [idempotencyKey] a repeat of the same call within 24 hours
  /// returns the first job instead of starting a second one.
  Future<BatchJob> batchRegisterAsync({
    required String collectionId,
    required List<BatchRegisterItem> items,
    String? idempotencyKey,
  }) async =>
      BatchJob.fromJson(await _postBatch(
          '/collections/$collectionId/faces/batch-async',
          items,
          idempotencyKey));

  /// Sends [items] as `images[i]` files plus an `entries` JSON array.
  Future<Map<String, dynamic>> _postBatch(
      String path, List<BatchRegisterItem> items, String? idempotencyKey) {
    final names = [
      for (final item in items) item.filename ?? '${item.externalId}.jpg',
    ];
    List<http.MultipartFile> files() => [
          for (var i = 0; i < items.length; i++)
            http.MultipartFile.fromBytes(
              'images[$i]',
              items[i].image,
              filename: names[i],
              contentType: _client._mediaType(
                  lookupMimeType(names[i], headerBytes: items[i].image) ??
                      'image/jpeg'),
            ),
        ];
    final entries = [
      for (final item in items)
        {
          'externalId': item.externalId,
          'metadata': item.metadata ?? <String, dynamic>{},
          if (item.livenessToken != null) 'livenessToken': item.livenessToken,
        },
    ];

    return _client._postMultipartFiles(
      path,
      files,
      fields: {'entries': jsonEncode(entries)},
      idempotencyKey: _client._idempotencyKey(idempotencyKey),
    );
  }

  /// Fetch the status (and, when available, per-image results) of an async
  /// batch registration job.
  Future<BatchJob> getBatchJob({
    required String collectionId,
    required String jobId,
  }) async {
    final data = await _client._get('/collections/$collectionId/batch/$jobId');
    return BatchJob.fromJson(data);
  }
}
