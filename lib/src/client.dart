import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'exceptions.dart';
import 'types.dart';

const _defaultBaseUrl = 'https://api.fr-apiaas.io/api/v1';

/// Main entry point for the FR-APIaaS SDK.
///
/// ```dart
/// final client = FrApiClient(apiKey: 'fr_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
/// );
/// ```
class FrApiClient {
  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  FrApiClient({
    required this.apiKey,
    this.baseUrl = _defaultBaseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  late final FacesApi faces = FacesApi._(this);
  late final CollectionsApi collections = CollectionsApi._(this);

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
    } on FrApiException {
      rethrow;
    } catch (e) {
      throw FrNetworkException('GET $path failed', e);
    }
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    try {
      final res = await _http.post(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _handle(res);
    } on FrApiException {
      rethrow;
    } catch (e) {
      throw FrNetworkException('POST $path failed', e);
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
    } on FrApiException {
      rethrow;
    } catch (e) {
      throw FrNetworkException('POST $path (multipart) failed', e);
    }
  }

  /// Multipart POST with multiple image files (async batch registration).
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
    } on FrApiException {
      rethrow;
    } catch (e) {
      throw FrNetworkException('POST $path (multipart) failed', e);
    }
  }

  Future<void> _delete(String path, [Map<String, String>? query]) async {
    try {
      final res = await _http.delete(_uri(path, query), headers: _headers);
      if (res.statusCode == 204) return;
      _handle(res);
    } on FrApiException {
      rethrow;
    } catch (e) {
      throw FrNetworkException('DELETE $path failed', e);
    }
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }

    final body = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final err = body['error'] as Map<String, dynamic>?;
    final msg = err?['message'] as String? ?? 'API error ${res.statusCode}';
    final code = err?['code'] as String?;

    switch (res.statusCode) {
      case 400:
      case 422:
        if (code == 'NO_FACE_DETECTED') throw FrNoFaceDetectedException(msg);
        throw FrValidationException(msg, code: code);
      case 401:
        throw FrUnauthorizedException(msg, code: code);
      case 403:
        throw FrForbiddenException(msg, code: code);
      case 404:
        throw FrNotFoundException(msg, code: code);
      case 402:
        throw FrQuotaExceededException(msg, code: code);
      case 429:
        throw FrRateLimitException(msg);
      default:
        throw FrServerException(msg, res.statusCode, code: code);
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
// Collections API
// ---------------------------------------------------------------------------

class CollectionsApi {
  final FrApiClient _client;
  CollectionsApi._(this._client);

  Future<PagedList<FaceCollection>> list(
    String orgId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client._get(
      '/organizations/$orgId/collections',
      {'limit': '$limit', 'offset': '$offset'},
    );
    final items = (data as List<dynamic>? ?? [])
        .map((e) => FaceCollection.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedList(items);
  }

  Future<FaceCollection> get(String orgId, String collectionId) async {
    final data =
        await _client._get('/organizations/$orgId/collections/$collectionId');
    return FaceCollection.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Faces API
// ---------------------------------------------------------------------------

class FacesApi {
  final FrApiClient _client;
  FacesApi._(this._client);

  /// Enroll a new face into a collection.
  Future<Face> register({
    required String collectionId,
    required Uint8List image,
    required String externalId,
    Map<String, dynamic>? metadata,
    String? filename,
  }) async {
    final fields = <String, String>{'external_id': externalId};
    if (metadata != null) fields['metadata'] = jsonEncode(metadata);

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
    String? faceId,
    double? threshold,
    String? filename,
  }) async {
    final fields = <String, String>{};
    if (faceId != null) fields['face_id'] = faceId;
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

  /// GDPR erasure — delete all faces for a given external ID.
  Future<void> deleteByExternalId({
    required String collectionId,
    required String externalId,
  }) =>
      _client._delete(
        '/collections/$collectionId/faces',
        {'external_id': externalId},
      );

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
        'external_id': item.externalId,
        'metadata': item.metadata ?? <String, dynamic>{},
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
    final data =
        await _client._get('/collections/$collectionId/batch/$jobId');
    return BatchJob.fromJson(data);
  }
}
