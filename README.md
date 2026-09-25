<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="doc/brand/logo-white.svg">
    <img src="doc/brand/logo.svg" alt="LiveXFace" width="220">
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
  collectionId: collectionId,
  image: imageBytes,
  externalId: 'user-123',
);

// Identify
final result = await client.faces.identify(
  collectionId: collectionId,
  image: imageBytes,
  topK: 3,
);
for (final match in result.matches) {
  print('${match.externalId}: ${match.confidence}');
}
```

The client also covers verify, liveness, attributes and asynchronous batch
registration; see [`example/main.dart`](example/main.dart).

Collections are created and managed in the LiveXFace dashboard, not through
the API, so the client has no collection operations.

## Configuration

| Option | Default | Description |
|---|---|---|
| `apiKey` | — | Your API key (`lxf_live_...` or `lxf_test_...`) |
| `baseUrl` | `https://api.livexface.com/api/v1` | Point at your own instance for on-prem |
| `httpClient` | `http.Client()` | Supply your own client, for example to set timeouts |

## Errors

All API errors extend `LiveXFaceApiException` (with typed subclasses such as
`LiveXFaceNoFaceDetectedException`, `LiveXFaceRateLimitException`); transport
failures throw `LiveXFaceNetworkException`. Every API error carries the
`requestId` the server assigned; quote it when contacting support.
