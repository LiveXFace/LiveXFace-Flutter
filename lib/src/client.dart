import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'exceptions.dart';
import 'types.dart';

const _defaultBaseUrl = 'https://api.livexface.com/api/v1';

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

  LiveXFaceClient({
    required this.apiKey,
    this.baseUrl = _defaultBaseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

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
      [Map<String, String>? query]) async {
    try {
      final res = await _http.get(_uri(path, query), headers: _headers);
      return _handle(res);
    } on LiveXFaceApiException {
      rethrow;
    } catch (e) {
      throw LiveXFaceNetworkException('GET $path failed', e);
    }
  }

  Future<Map<String, dynamic>> _postMultipart(
    String path,
    Uint8List imageBytes, {
    String imageField = 'image',
    Map<String, String>? fields,
    String? filename,
  }) async {
    try {
      final mime =
          lookupMimeType(filename ?? 'image.jpg', headerBytes: imageBytes) ??
              'image/jpeg';
      final req = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers)
        ..files.add(http.MultipartFile.fromBytes(
          imageField,
          imageBytes,
          filename: filename ?? 'image.jpg',
          contentType: _mediaType(mime),
        ));
      if (fields != null) req.fields.addAll(fields);

      final streamed = await _http.send(req);
      final res = await http.Response.fromStream(streamed);
      return _handle(res);
    } on LiveXFaceApiException {
      rethrow;
    } catch (e) {
      throw LiveXFaceNetworkException('POST $path (multipart) failed', e);
    }
  }

  /// Multipart POST with multiple image files (async batch registration,
  /// active liveness).
  Future<Map<String, dynamic>> _postMultipartFiles(
    String path,
    List<http.MultipartFile> files, {
    Map<String, String>? fields,
  }) async {
    try {
      final req = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers)
        ..files.addAll(files);
      if (fields != null) req.fields.addAll(fields);

      final streamed = await _http.send(req);
      final res = await http.Response.fromStream(streamed);
      return _handle(res);
    } on LiveXFaceApiException {
      rethrow;
    } catch (e) {
      throw LiveXFaceNetworkException('POST $path (multipart) failed', e);
    }
  }

  Future<void> _delete(String path, [Map<String, String>? query]) async {
    try {
      final res = await _http.delete(_uri(path, query), headers: _headers);
      if (res.statusCode == 204) return;
      _handle(res);
    } on LiveXFaceApiException {
      rethrow;
    } catch (e) {
      throw LiveXFaceNetworkException('DELETE $path failed', e);
    }
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }

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

    switch (res.statusCode) {
      case 400:
      case 422:
        if (code == 'NO_FACE_DETECTED') {
          throw LiveXFaceNoFaceDetectedException(msg, requestId);
        }
        // Declared long before the API could send it, and never thrown, so
        // a liveness refusal arrived as a generic validation error.
        if (code == 'SPOOF_DETECTED') {
          throw LiveXFaceSpoofDetectedException(msg, requestId);
        }
        throw LiveXFaceValidationException(msg,
            code: code, requestId: requestId);
      case 401:
        throw LiveXFaceUnauthorizedException(msg,
            code: code, requestId: requestId);
      case 403:
        throw LiveXFaceForbiddenException(msg,
            code: code, requestId: requestId);
      case 404:
        throw LiveXFaceNotFoundException(msg, code: code, requestId: requestId);
      case 402:
        throw LiveXFaceQuotaExceededException(msg,
            code: code, requestId: requestId);
      case 429:
        throw LiveXFaceRateLimitException(msg, requestId);
      default:
        throw LiveXFaceServerException(msg, res.statusCode,
            code: code, requestId: requestId);
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
  Future<Face> register({
    required String collectionId,
    required Uint8List image,
    required String externalId,
    Map<String, dynamic>? metadata,
    String? livenessToken,
    String? filename,
  }) async {
    final fields = <String, String>{'external_id': externalId};
    if (metadata != null) fields['metadata'] = jsonEncode(metadata);
    if (livenessToken != null) fields['liveness_token'] = livenessToken;

    final data = await _client._postMultipart(
      '/collections/$collectionId/faces',
      image,
      fields: fields,
      filename: filename,
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
    final files = <http.MultipartFile>[];
    for (var i = 0; i < frames.length; i++) {
      final filename = 'frame_$i.jpg';
      final mime =
          lookupMimeType(filename, headerBytes: frames[i]) ?? 'image/jpeg';
      files.add(http.MultipartFile.fromBytes(
        'frame_$i',
        frames[i],
        filename: filename,
        contentType: _client._mediaType(mime),
      ));
    }

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

  /// Submit up to 100 faces for asynchronous registration.
  ///
  /// Returns the created job immediately; poll [getBatchJob] until
  /// [BatchJob.isFinished].
  Future<BatchJob> batchRegisterAsync({
    required String collectionId,
    required List<BatchRegisterItem> items,
  }) async {
    final files = <http.MultipartFile>[];
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final filename = item.filename ?? '${item.externalId}.jpg';
      final mime =
          lookupMimeType(filename, headerBytes: item.image) ?? 'image/jpeg';
      files.add(http.MultipartFile.fromBytes(
        'images[$i]',
        item.image,
        filename: filename,
        contentType: _client._mediaType(mime),
      ));
      entries.add({
        'externalId': item.externalId,
        'metadata': item.metadata ?? <String, dynamic>{},
        if (item.livenessToken != null) 'livenessToken': item.livenessToken,
      });
    }

    final data = await _client._postMultipartFiles(
      '/collections/$collectionId/faces/batch-async',
      files,
      fields: {'entries': jsonEncode(entries)},
    );
    return BatchJob.fromJson(data);
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
