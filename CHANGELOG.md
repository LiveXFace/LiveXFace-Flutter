# Changelog

## 0.1.0

Initial release.

- `IdemityClient` with API-key authentication
- Collections: list, get, create, update, delete
- Faces: register, list, get, get by external id, delete
- Recognition: verify, identify, compare, liveness
- Face attributes (age, gender, head pose, emotion, glasses, mask)
- Batch register (synchronous and asynchronous job polling)
- Typed models and a `IdemityApiException` hierarchy with `IdemityNetworkException` for transport failures
