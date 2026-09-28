# Changelog

## Unreleased

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
