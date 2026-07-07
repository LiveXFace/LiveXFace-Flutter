import 'dart:io';

import 'package:fr_apiaas/fr_apiaas.dart';

void main() async {
  final client = FrApiClient(apiKey: 'fr_live_xxxxxxxxxxxxxxxx');

  // Load image bytes from disk (or from camera/gallery in a real app)
  final imageBytes = await File('photo.jpg').readAsBytes();

  try {
    // 1. Enroll
    final face = await client.faces.register(
      collectionId: 'your-collection-id',
      image: imageBytes,
      externalId: 'user_42',
      metadata: {'name': 'Jane Doe', 'department': 'Engineering'},
    );
    print('Enrolled: ${face.id}');

    // 2. Verify liveness
    final liveness = await client.faces.liveness(
      collectionId: 'your-collection-id',
      image: imageBytes,
    );
    print('Live: ${liveness.isLive} (score: ${liveness.livenessScore})');

    // 3. Identify
    final result = await client.faces.identify(
      collectionId: 'your-collection-id',
      image: imageBytes,
      topK: 3,
    );
    for (final match in result.matches) {
      print('Match: ${match.externalId} — ${(match.confidence * 100).toStringAsFixed(1)}%');
    }
  } on FrNoFaceDetectedException {
    print('No face found in the image.');
  } on FrRateLimitException {
    print('Rate limit hit — retry after a moment.');
  } on FrApiException catch (e) {
    print('API error [${e.code}]: ${e.message}');
  } finally {
    client.dispose();
  }
}
