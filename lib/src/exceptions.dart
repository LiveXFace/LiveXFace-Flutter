/// Exceptions thrown by the LiveXFace SDK.

/// Base class for all LiveXFace errors.
sealed class LiveXFaceApiException implements Exception {
  final String message;
  final String? code;

  const LiveXFaceApiException(this.message, {this.code});

  @override
  String toString() => 'LiveXFaceApiException(${code ?? 'unknown'}): $message';
}

/// The request was malformed or failed validation (HTTP 400 / 422).
final class LiveXFaceValidationException extends LiveXFaceApiException {
  const LiveXFaceValidationException(super.message, {super.code});
}

/// Authentication failed — invalid or missing API key (HTTP 401).
final class LiveXFaceUnauthorizedException extends LiveXFaceApiException {
  const LiveXFaceUnauthorizedException(super.message, {super.code});
}

/// The API key does not have access to this resource (HTTP 403).
final class LiveXFaceForbiddenException extends LiveXFaceApiException {
  const LiveXFaceForbiddenException(super.message, {super.code});
}

/// The requested resource does not exist (HTTP 404).
final class LiveXFaceNotFoundException extends LiveXFaceApiException {
  const LiveXFaceNotFoundException(super.message, {super.code});
}

/// No face was detected in the uploaded image (HTTP 422 NO_FACE_DETECTED).
final class LiveXFaceNoFaceDetectedException extends LiveXFaceApiException {
  const LiveXFaceNoFaceDetectedException([String message = 'No face detected in image'])
      : super(message, code: 'NO_FACE_DETECTED');
}

/// A spoof or non-live face was detected (HTTP 422 / liveness check failed).
final class LiveXFaceSpoofDetectedException extends LiveXFaceApiException {
  const LiveXFaceSpoofDetectedException([String message = 'Liveness check failed — spoof detected'])
      : super(message, code: 'SPOOF_DETECTED');
}

/// Rate limit exceeded (HTTP 429).
final class LiveXFaceRateLimitException extends LiveXFaceApiException {
  const LiveXFaceRateLimitException([String message = 'Rate limit exceeded'])
      : super(message, code: 'RATE_LIMIT_EXCEEDED');
}

/// Plan quota exceeded — upgrade required (HTTP 402).
final class LiveXFaceQuotaExceededException extends LiveXFaceApiException {
  const LiveXFaceQuotaExceededException(super.message, {super.code});
}

/// An unexpected server-side error occurred (HTTP 5xx).
final class LiveXFaceServerException extends LiveXFaceApiException {
  final int statusCode;

  const LiveXFaceServerException(super.message, this.statusCode, {super.code});

  @override
  String toString() => 'LiveXFaceServerException($statusCode): $message';
}

/// A network or connectivity error (no HTTP response received).
final class LiveXFaceNetworkException extends LiveXFaceApiException {
  final Object? cause;

  const LiveXFaceNetworkException([String message = 'Network error', this.cause])
      : super(message, code: 'NETWORK_ERROR');
}
