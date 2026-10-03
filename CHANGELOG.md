# Changelog

## Unreleased

- `contractVersion` names the API contract (`/openapi.json` `info.version`)
  this release is validated against: 1.0.0, pinned in `contract/`
- `faces.batchRegister(collectionId:, items:, idempotencyKey:)` enrolls up to
  20 faces synchronously (`POST /collections/{id}/faces/batch`) and returns a
  `BatchResponse` (`succeeded`, `failed`, `results` of `BatchFaceResult`)
- `faces.register`, `faces.batchRegister` and `faces.batchRegisterAsync`
  accept an optional `idempotencyKey`, sent as the `Idempotency-Key` header; the top-level
  `generateIdempotencyKey()` returns a random UUID v4
- Opt-in retries: `LiveXFaceClient(maxRetries:, maxRetryDelay:)`. 429 and 503
  honour `Retry-After`; network errors and other 5xx are retried only for
  GET/PATCH/DELETE and keyed requests; enrolment and batch calls reuse one key
  across attempts. Off by default
- `LiveXFaceApiException` exposes `statusCode` and `retryAfter`; the
  401/402/403/404 and server exceptions now carry `details` too
- `faces.activeLiveness(collectionId:, frames:)` runs the multi-frame active
  liveness check (blink, head turn, passive anti-spoof) and returns an
  `ActiveLivenessResult` with a single-use `livenessToken` when it passes
- `faces.register` and `BatchRegisterItem` accept an optional `livenessToken`
- **Breaking (server):** collections that require liveness now refuse
  enrolment without a liveness token (`LIVENESS_TOKEN_REQUIRED`); a bad token
  is `LIVENESS_TOKEN_INVALID` and a different face `LIVENESS_FACE_MISMATCH`.
  Run `activeLiveness` first and pass its token

## 0.1.0

Initial release.

- `LiveXFaceClient` with API-key authentication
- Collections: list, get, create, update, delete
- Faces: register, list, get, get by external id, delete
- Recognition: verify, identify, compare, liveness
- Face attributes (age, gender, head pose, emotion, glasses, mask)
- Batch register (synchronous and asynchronous job polling)
- Typed models and a `LiveXFaceApiException` hierarchy with `LiveXFaceNetworkException` for transport failures
