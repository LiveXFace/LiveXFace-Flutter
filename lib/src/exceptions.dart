/// Exceptions thrown by the FR-APIaaS SDK.

/// Base class for all FR-APIaaS errors.
sealed class FrApiException implements Exception {
  final String message;
  final String? code;

  const FrApiException(this.message, {this.code});

  @override
  String toString() => 'FrApiException(${code ?? 'unknown'}): $message';
}

/// The request was malformed or failed validation (HTTP 400 / 422).
final class FrValidationException extends FrApiException {
  const FrValidationException(super.message, {super.code});
}

/// Authentication failed — invalid or missing API key (HTTP 401).
final class FrUnauthorizedException extends FrApiException {
  const FrUnauthorizedException(super.message, {super.code});
}

/// The API key does not have access to this resource (HTTP 403).
final class FrForbiddenException extends FrApiException {
  const FrForbiddenException(super.message, {super.code});
}

/// The requested resource does not exist (HTTP 404).
final class FrNotFoundException extends FrApiException {
  const FrNotFoundException(super.message, {super.code});
}

/// No face was detected in the uploaded image (HTTP 422 NO_FACE_DETECTED).
final class FrNoFaceDetectedException extends FrApiException {
  const FrNoFaceDetectedException([String message = 'No face detected in image'])
      : super(message, code: 'NO_FACE_DETECTED');
}

/// A spoof or non-live face was detected (HTTP 422 / liveness check failed).
final class FrSpoofDetectedException extends FrApiException {
  const FrSpoofDetectedException([String message = 'Liveness check failed — spoof detected'])
      : super(message, code: 'SPOOF_DETECTED');
}

/// Rate limit exceeded (HTTP 429).
final class FrRateLimitException extends FrApiException {
  const FrRateLimitException([String message = 'Rate limit exceeded'])
      : super(message, code: 'RATE_LIMIT_EXCEEDED');
}

/// Plan quota exceeded — upgrade required (HTTP 402).
final class FrQuotaExceededException extends FrApiException {
  const FrQuotaExceededException(super.message, {super.code});
}

/// An unexpected server-side error occurred (HTTP 5xx).
final class FrServerException extends FrApiException {
  final int statusCode;

  const FrServerException(super.message, this.statusCode, {super.code});

  @override
  String toString() => 'FrServerException($statusCode): $message';
}

/// A network or connectivity error (no HTTP response received).
final class FrNetworkException extends FrApiException {
  final Object? cause;

  const FrNetworkException([String message = 'Network error', this.cause])
      : super(message, code: 'NETWORK_ERROR');
}
