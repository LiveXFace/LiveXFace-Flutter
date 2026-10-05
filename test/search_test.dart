import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livexface/livexface.dart';

void main() {
  final image = Uint8List.fromList([0xff, 0xd8]);

  test('search parses skips and surfaces typed profile mismatch', () async {
    var conflict = false;
    final httpClient = MockClient((request) async {
      if (conflict) {
        return http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'EMBEDDING_PROFILE_MISMATCH',
                'message': 'no compatible collections'
              }
            }),
            409);
      }
      expect(request.url.path, '/api/v1/search');
      expect(latin1.decode(request.bodyBytes), contains('c1,c2'));
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'matches': [],
              'queryTimeMs': 4,
              'collectionsSearched': 1,
              'skippedCollections': [
                {
                  'id': 'c2',
                  'name': 'Legacy',
                  'reason': 'embedding_profile_mismatch'
                }
              ]
            }
          }),
          200);
    });
    final client = LiveXFaceClient(
        apiKey: 'lxf_test',
        baseUrl: 'https://api.test/api/v1',
        httpClient: httpClient);
    final result =
        await client.faces.search(image: image, collectionIds: ['c1', 'c2']);
    expect(
        result.skippedCollections.single.reason, 'embedding_profile_mismatch');
    conflict = true;
    await expectLater(
        client.faces.search(image: image),
        throwsA(isA<LiveXFaceServerException>()
            .having((e) => e.code, 'code', 'EMBEDDING_PROFILE_MISMATCH')
            .having((e) => e.statusCode, 'status', 409)));
  });
}
