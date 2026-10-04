# Changelog

## 1.0.0

**BREAKING:** validated against API contract 2.0.0 (`contractVersion`,
`contract/openapi-2.0.0.json`), in which the stateless active-liveness check
no longer issues a liveness token.

- **BREAKING:** `ActiveLivenessResult` no longer has `livenessToken` or
  `livenessTokenExpiresAt`; `faces.activeLiveness` returns a verdict only
- `faces.createLivenessSession(collectionId:)` returns a `LivenessSession`
  (`sessionId`, `challenges` as ordered step types `blink`, `turn_left`,
  `turn_right`, and `expiresAt`)
- `faces.completeLivenessSession(collectionId:, sessionId:, frames:,
  mirrored:)` returns a `LivenessSessionResult`: the `ActiveLivenessResult`
  fields plus `steps` (`LivenessStep` `type` and `passed`) and, when it
  passed, `livenessToken` and `livenessTokenExpiresAt`. With `maxRetries`
  set it is retried on 429 only, never on 503, another 5xx or a network
  error, since a submission uses the session up
- A spent, expired, unknown or foreign session is 422
  `LIVENESS_SESSION_INVALID`, thrown as `LiveXFaceValidationException` (no new
  exception subtype, so exhaustive `switch`es keep compiling)

### Migrating from 0.x

`activeLiveness` no longer returns a token; create a session, show its
challenges, complete it with the frames:

1. `final s = await client.faces.createLivenessSession(collectionId: id);`
2. Show `s.challenges` in order and capture 5 to 50 frames while the person
   performs them.
3. `final r = await client.faces.completeLivenessSession(collectionId: id,
   sessionId: s.sessionId, frames: frames, mirrored: true);` (set `mirrored`
   to match your frames) before `s.expiresAt`.
4. Pass `r.livenessToken` to `faces.register` or a `BatchRegisterItem` as
   before. On `LIVENESS_SESSION_INVALID` or `SERVICE_BUSY`, start again from
   step 1.

### Also new since 0.1.0

- `contractVersion` names the API contract (`/openapi.json` `info.version`)
  this release is validated against, pinned in `contract/`
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
  `ActiveLivenessResult` verdict
- `faces.register` and `BatchRegisterItem` accept an optional `livenessToken`
- **Breaking (server):** collections that require liveness now refuse
  enrolment without a liveness token (`LIVENESS_TOKEN_REQUIRED`); a bad token
  is `LIVENESS_TOKEN_INVALID` and a different face `LIVENESS_FACE_MISMATCH`.
  Complete a liveness session first and pass its token

## 0.1.0

Initial release.

- `LiveXFaceClient` with API-key authentication
- Collections: list, get, create, update, delete
- Faces: register, list, get, get by external id, delete
- Recognition: verify, identify, compare, liveness
- Face attributes (age, gender, head pose, emotion, glasses, mask)
- Batch register (synchronous and asynchronous job polling)
- Typed models and a `LiveXFaceApiException` hierarchy with `LiveXFaceNetworkException` for transport failures
