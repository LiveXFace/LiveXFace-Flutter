import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livexface/livexface.dart';

// Checks every API method against the pinned contract: its path and HTTP
// method exist there, and it sends every field the contract marks required.

const _base = 'https://api.test/api/v1';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

final _item = BatchRegisterItem(
  externalId: 'emp-1',
  image: _jpeg,
  metadata: {'team': 'a'},
  livenessToken: 'lvt_abc',
);

/// Every public method of the API classes in lib/src/client.dart, called with
/// every optional argument that adds a field. A guard test fails when a method
/// there is missing here.
final _calls = <String, Future<Object?> Function(LiveXFaceClient)>{
  'FacesApi.register': (c) => c.faces.register(
      collectionId: 'col_1',
      image: _jpeg,
      externalId: 'emp-1',
      metadata: {'team': 'a'},
      livenessToken: 'lvt_abc',
      filename: 'a.jpg',
      idempotencyKey: 'key-1'),
  'FacesApi.verify': (c) => c.faces.verify(
      collectionId: 'col_1',
      image: _jpeg,
      faceId: 'face_1',
      threshold: 0.5,
      filename: 'a.jpg'),
  'FacesApi.identify': (c) => c.faces.identify(
      collectionId: 'col_1',
      image: _jpeg,
      topK: 3,
      threshold: 0.5,
      filename: 'a.jpg'),
  'FacesApi.liveness': (c) =>
      c.faces.liveness(collectionId: 'col_1', image: _jpeg, filename: 'a.jpg'),
  'FacesApi.activeLiveness': (c) => c.faces
      .activeLiveness(collectionId: 'col_1', frames: List.filled(5, _jpeg)),
  'FacesApi.createLivenessSession': (c) =>
      c.faces.createLivenessSession(collectionId: 'col_1'),
  'FacesApi.completeLivenessSession': (c) => c.faces.completeLivenessSession(
      collectionId: 'col_1',
      sessionId: 'lvs_1',
      frames: List.filled(5, _jpeg),
      mirrored: true),
  'FacesApi.attributes': (c) => c.faces
      .attributes(collectionId: 'col_1', image: _jpeg, filename: 'a.jpg'),
  'FacesApi.delete': (c) =>
      c.faces.delete(collectionId: 'col_1', faceId: 'face_1'),
  'FacesApi.batchRegister': (c) => c.faces.batchRegister(
      collectionId: 'col_1', items: [_item, _item], idempotencyKey: 'key-1'),
  'FacesApi.batchRegisterAsync': (c) => c.faces.batchRegisterAsync(
      collectionId: 'col_1', items: [_item, _item], idempotencyKey: 'key-1'),
  'FacesApi.getBatchJob': (c) =>
      c.faces.getBatchJob(collectionId: 'col_1', jobId: 'job_1'),
};

final _contract = jsonDecode(
        File('contract/openapi-$contractVersion.json').readAsStringSync())
    as Map<String, dynamic>;

/// The names a request sends: multipart field and file names, JSON body
/// top-level keys, query keys and headers (lower-cased).
Set<String> _sentFields(http.Request req) {
  final type = req.headers['content-type'] ?? '';
  return {
    if (type.startsWith('multipart/form-data'))
      for (final m in RegExp(r'; name="([^"]+)"')
          .allMatches(latin1.decode(req.bodyBytes)))
        m[1]!,
    if (type.startsWith('application/json'))
      ...(jsonDecode(req.body) as Map<String, dynamic>).keys,
    ...req.url.queryParameters.keys,
    for (final h in req.headers.keys) h.toLowerCase(),
  };
}

/// [name], or for a repeated field documented by its first name (`images[0]`,
/// `frame_0`), any of its numbered names.
bool _isSent(String name, Set<String> sent) {
  final m = RegExp(r'^(.+?)(\[0\]|_0)$').firstMatch(name);
  if (m == null) return sent.contains(name);
  final n = m[2] == '_0' ? r'_\d+' : r'\[\d+\]';
  final re = RegExp('^${RegExp.escape(m[1]!)}$n\$');
  return sent.any(re.hasMatch);
}

Map<String, dynamic> _resolve(Map<String, dynamic> schema) {
  final ref = schema[r'$ref'] as String?;
  if (ref == null) return schema;
  Object? node = _contract;
  for (final part in ref.substring(2).split('/')) {
    node = (node as Map<String, dynamic>)[part];
  }
  return _resolve(node as Map<String, dynamic>);
}

/// The contract's required inputs for [op], other than path parameters.
List<String> _required(Map<String, dynamic> op) {
  final content =
      (op['requestBody'] as Map<String, dynamic>?)?['content'] as Map? ?? {};
  return [
    for (final p in (op['parameters'] as List? ?? []).cast<Map>())
      if (p['required'] == true && p['in'] != 'path')
        p['in'] == 'header'
            ? (p['name'] as String).toLowerCase()
            : p['name'] as String,
    for (final media in content.values)
      ...(_resolve((media as Map)['schema'] as Map<String, dynamic>)['required']
                  as List? ??
              [])
          .cast<String>(),
  ];
}

/// Why [req] breaks the contract, or null when it does not.
String? _violation(http.Request req) {
  final method = req.method.toLowerCase();
  final path = req.url.path.substring(Uri.parse(_base).path.length);
  final paths = _contract['paths'] as Map<String, dynamic>;
  // The most literal template wins: /faces/batch over /faces/{face_id}.
  final templates = paths.keys
      .where((t) => RegExp(
              '^${t.split(RegExp(r'\{[^}]+\}')).map(RegExp.escape).join('[^/]+')}\$')
          .hasMatch(path))
      .toList()
    ..sort((a, b) => '{'.allMatches(a).length - '{'.allMatches(b).length);
  if (templates.isEmpty) return '$path matches no contract path';
  final template = templates.firstWhere(
      (t) => (paths[t] as Map).containsKey(method),
      orElse: () => '');
  if (template.isEmpty) {
    return '${req.method} is not allowed on ${templates.first}';
  }
  final sent = _sentFields(req);
  final missing = _required(paths[template][method] as Map<String, dynamic>)
      .where((f) => !_isSent(f, sent))
      .toList();
  return missing.isEmpty
      ? null
      : '${req.method} $template misses required $missing';
}

void main() {
  test('contractVersion matches CONTRACT_VERSION and the pinned contract', () {
    expect(contractVersion, File('CONTRACT_VERSION').readAsStringSync().trim());
    expect(contractVersion, (_contract['info'] as Map)['version']);
  });

  for (final entry in _calls.entries) {
    test('${entry.key} matches the contract', () async {
      final requests = <http.Request>[];
      final c = LiveXFaceClient(
        apiKey: 'lxf_test_key',
        baseUrl: _base,
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response('', 204);
        }),
      );
      try {
        await entry.value(c);
      } on TypeError {
        // An empty body does not parse into every result type; only the
        // request is under test here.
      }

      expect(requests, hasLength(1));
      final req = requests.single;
      expect(_violation(req), isNull,
          reason: '${entry.key} sends ${req.method} ${req.url.path}');
    });
  }

  test('every public API method is checked against the contract', () {
    final source = File('lib/src/client.dart').readAsStringSync();
    final found = <String>{};
    final classes = RegExp(r'^class (\w+Api) \{$', multiLine: true);
    for (final cls in classes.allMatches(source)) {
      final end = source.indexOf(RegExp(r'^class ', multiLine: true), cls.end);
      final body = source.substring(cls.end, end < 0 ? source.length : end);
      for (final m in RegExp(r'^\s+Future<.*?>\s+([a-z]\w*)\(', multiLine: true)
          .allMatches(body)) {
        found.add('${cls[1]}.${m[1]}');
      }
    }
    expect(found, isNotEmpty);
    expect(_calls.keys.toSet(), found);
  });
}
