<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/brand/logo-white.svg">
    <img src="docs/brand/logo.svg" alt="LiveXFace" width="220">
  </picture>
</p>

# LiveXFace Flutter SDK

Official Flutter/Dart SDK for [LiveXFace](https://livexface.com) — Face Recognition as a Service.

## Install

```yaml
dependencies:
  livexface: ^0.1.0
```

## Quick start

```dart
import 'package:livexface/livexface.dart';

final client = LiveXFaceClient(apiKey: 'lxf_live_xxxxxxxx');

// Register a face
final face = await client.faces.register(
  collectionId,
  imageBytes,
  externalId: 'user-123',
);

// Identify
final result = await client.faces.identify(collectionId, imageBytes, topK: 3);
for (final match in result.matches) {
  print('${match.externalId}: ${match.confidence}');
}
```

See [`example/main.dart`](example/main.dart) for the full API surface: verify, liveness, attributes, batch register (sync & async), and collection management.

## Configuration

| Option | Default | Description |
|---|---|---|
| `apiKey` | — | Your API key (`lxf_live_...` or `lxf_test_...`) |
| `baseUrl` | `https://api.livexface.com/api/v1` | Point at your own instance for on-prem |
| `timeout` | 30s | Request timeout |

## Errors

All API errors extend `LiveXFaceApiException` (with typed subclasses such as
`LiveXFaceNoFaceDetectedException`, `LiveXFaceRateLimitException`); transport
failures throw `LiveXFaceNetworkException`.
