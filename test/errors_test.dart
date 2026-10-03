import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livexface/livexface.dart';

void main() {
  test('validation errors expose details', () async {
    final client = LiveXFaceClient(
      apiKey: 'lxf_test_key',
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'requestId': 'r-1',
              'error': {
                'code': 'MULTIPLE_FACES',
                'message': 'multiple faces detected',
                'details': {'faceCount': 2, 'faces': []},
              },
            }),
            422,
            headers: {'content-type': 'application/json'},
          )),
    );

    await expectLater(
      client.faces.register(
          collectionId: 'col',
          image: Uint8List.fromList([1, 2, 3]),
          externalId: 'a'),
      throwsA(isA<LiveXFaceValidationException>()
          .having((e) => e.code, 'code', 'MULTIPLE_FACES')
          .having((e) => e.details?['faceCount'], 'faceCount', 2)),
    );
  });
}
