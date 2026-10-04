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
  livexface: ^1.0.0
```

Validated against API contract 2.0.0 (`/openapi.json` `info.version`),
exposed as `contractVersion`. The test suite checks every client method's HTTP
method, path and required fields against the pinned `contract/openapi-2.0.0.json`;
to move to a new contract, copy the release asset `openapi-<version>.json` into
`contract/` and update `CONTRACT_VERSION` and `contractVersion`.

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

### Liveness-protected enrolment

Collections that require liveness refuse enrolment without a liveness token,
and only a completed liveness session earns one. The server picks the steps
(one blink and one or two head turns, in random order); show them to the
person, capture 5 to 50 frames while they perform them, and submit the frames
once, before the session expires (60 seconds by default). `turn_left` and
`turn_right` mean the person's own left and right: pass `mirrored: true` when
your frames are mirrored like a selfie preview. The token is single-use, valid
for 5 minutes and bound to the collection.

```dart
final session =
    await client.faces.createLivenessSession(collectionId: collectionId);

// Show each prompt in order and capture frames while the person follows them.
final frames = await captureWhilePrompting(session.challenges); // List<Uint8List>

final check = await client.faces.completeLivenessSession(
  collectionId: collectionId,
  sessionId: session.sessionId,
  frames: frames,
  mirrored: true, // front-camera frames, as previewed
);
if (check.isLive) {
  await client.faces.register(
    collectionId: collectionId,
    image: frames.first,
    externalId: 'user-123',
    livenessToken: check.livenessToken,
  );
} else {
  // check.steps says which step was not seen; start a new session.
}
```

A session is judged once: completing it again, after it expired, or on
another collection fails with `LIVENESS_SESSION_INVALID` (422, a
`LiveXFaceValidationException`); create a new session. Fewer than 5 frames is
`IMAGE_REQUIRED` (400) and keeps the session. A 503 `SERVICE_BUSY` arrives
after the server used the session up, so it also means starting a new session.
With `maxRetries` set, `completeLivenessSession` is retried only on 429 (the
rate limiter answers before the session is touched), never on 503, another
5xx or a network error: a repeat would only come back as
`LIVENESS_SESSION_INVALID` and hide the cause.

`activeLiveness` still runs the same checks on a burst of frames without a
session, but returns a verdict only and never a token.

Enrolment then fails with `LIVENESS_TOKEN_REQUIRED` (400) when no token is
sent, `LIVENESS_TOKEN_INVALID` (422) for a spent, expired or foreign token,
and `LIVENESS_FACE_MISMATCH` (422) when the image is not the face that passed.
`BatchRegisterItem` takes a `livenessToken` per item.

### Batch enrolment

```dart
final items = [
  BatchRegisterItem(externalId: 'emp-1', image: photo1),
  BatchRegisterItem(externalId: 'emp-2', image: photo2),
];

// Up to 20 faces; waits for every result.
final batch = await client.faces.batchRegister(
  collectionId: 'col_id',
  items: items,
);
for (final r in batch.results) {
  print('${r.externalId}: ${r.face?.id ?? r.error}');
}

// Up to 100 faces as a background job; poll getBatchJob until isFinished.
final job = await client.faces.batchRegisterAsync(
  collectionId: 'col_id',
  items: items,
);
```

A failed item does not fail a synchronous batch: `succeeded`, `failed` and
each result's `error` say which faces were enrolled.

The client also covers verify, liveness and attributes; see
[`example/main.dart`](example/main.dart).

Collections are created and managed in the LiveXFace dashboard, not through
the API, so the client has no collection operations.

## Configuration

| Option | Default | Description |
|---|---|---|
| `apiKey` | — | Your API key (`lxf_live_...` or `lxf_test_...`) |
| `baseUrl` | `https://api.livexface.com/api/v1` | Point at your own instance for on-prem |
| `httpClient` | `http.Client()` | Supply your own client, for example to set timeouts |
| `maxRetries` | `0` | Automatic retries after the first attempt; `0` turns them off (see [Production retries](#production-retries)) |
| `maxRetryDelay` | `Duration(seconds: 60)` | The longest single wait between retries |

## Errors

All API errors extend `LiveXFaceApiException` (with typed subclasses such as
`LiveXFaceNoFaceDetectedException`, `LiveXFaceRateLimitException`); transport
failures throw `LiveXFaceNetworkException`. Every API error carries the
`requestId` the server assigned; quote it when contacting support.
Each also exposes `statusCode`, `code`, `message`, `details` (when the API
sent any) and `retryAfter`: the seconds a 429 or 503 response's `Retry-After`
header asked you to wait, or `null`.
Codes without a subclass of their own arrive on the class for their status;
for example `LIVENESS_SESSION_INVALID` and `LIVENESS_TOKEN_INVALID` are
`LiveXFaceValidationException`s, so check `e.code`.

## Idempotent requests

`faces.register`, `faces.batchRegister` and `faces.batchRegisterAsync` take
an `idempotencyKey`.
The API remembers the response to a keyed request for 24 hours: repeating the
same request with the same key returns the stored response, with the header
`Idempotent-Replayed: true`, instead of enrolling the face (or starting the
job) a second time. Use one key per logical operation;
`generateIdempotencyKey()` returns a random UUID v4.

- The same key with a different request is refused with 422
  `IDEMPOTENCY_KEY_MISMATCH`.
- The same key while the first request is still running is refused with 409
  `IDEMPOTENCY_KEY_IN_USE`; retry it later.
- 429 and 5xx responses are not remembered, so repeating the request with the
  same key runs it again.
- Any other 4xx response *is* remembered and replayed. After fixing the cause
  (another photo, a fresh liveness token), send the new attempt with a new key.

## Production retries

Retries are off by default. With `maxRetries` set, the client retries 429 and
503 after their `Retry-After` (capped at `maxRetryDelay`), or after a jittered
exponential backoff when there is none. Network errors and other 5xx are
retried only for GET, PATCH and DELETE calls and for calls that carry an
idempotency key; other 4xx are never retried. `completeLivenessSession` is the
exception: it is retried on 429 only (see
[Liveness-protected enrolment](#liveness-protected-enrolment)). Enrolment and batch calls send
the same key on every attempt, generating one when you gave none.

```dart
final client = LiveXFaceClient(apiKey: 'lxf_live_xxxxxxxx', maxRetries: 3);

// Keep the key with the job that owns it so a restart reuses it.
final key = generateIdempotencyKey();
try {
  final face = await client.faces.register(
    collectionId: 'col_id',
    image: imageBytes,
    externalId: 'employee-42',
    idempotencyKey: key,
  );
  print('Enrolled ${face.id}');
} on LiveXFaceApiException catch (e) {
  // After the last retry: e.retryAfter says how long the API asked to wait.
  print('${e.statusCode} ${e.code}, retry after ${e.retryAfter}s, '
      'request ${e.requestId}');
}
```
