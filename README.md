<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/brand/logo-white.svg">
    <img src="docs/brand/logo.svg" alt="Idemity" width="220">
  </picture>
</p>

# Idemity Flutter SDK

Official Flutter/Dart SDK for [Idemity](https://idemity.com) — Face Recognition as a Service.

## Install

```yaml
dependencies:
  idemity: ^0.1.0
```

## Quick start

```dart
import 'package:idemity/idemity.dart';

final client = IdemityClient(apiKey: 'idm_live_xxxxxxxx');

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
| `apiKey` | — | Your API key (`idm_live_...` or `idm_test_...`) |
| `baseUrl` | `https://api.idemity.com/api/v1` | Point at your own instance for on-prem |
| `timeout` | 30s | Request timeout |

## Errors

All API errors extend `IdemityApiException` (with typed subclasses such as
`IdemityNoFaceDetectedException`, `IdemityRateLimitException`); transport
failures throw `IdemityNetworkException`.
