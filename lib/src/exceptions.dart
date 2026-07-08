/// Exceptions thrown by the Idemity SDK.

/// Base class for all Idemity errors.
sealed class IdemityApiException implements Exception {
  final String message;
  final String? code;

  const IdemityApiException(this.message, {this.code});

  @override
  String toString() => 'IdemityApiException(${code ?? 'unknown'}): $message';
}

/// The request was malformed or failed validation (HTTP 400 / 422).
final class IdemityValidationException extends IdemityApiException {
  const IdemityValidationException(super.message, {super.code});
}

/// Authentication failed — invalid or missing API key (HTTP 401).
final class IdemityUnauthorizedException extends IdemityApiException {
  const IdemityUnauthorizedException(super.message, {super.code});
}

/// The API key does not have access to this resource (HTTP 403).
final class IdemityForbiddenException extends IdemityApiException {
  const IdemityForbiddenException(super.message, {super.code});
}

/// The requested resource does not exist (HTTP 404).
final class IdemityNotFoundException extends IdemityApiException {
  const IdemityNotFoundException(super.message, {super.code});
}

/// No face was detected in the uploaded image (HTTP 422 NO_FACE_DETECTED).
final class IdemityNoFaceDetectedException extends IdemityApiException {
  const IdemityNoFaceDetectedException([String message = 'No face detected in image'])
      : super(message, code: 'NO_FACE_DETECTED');
}

/// A spoof or non-live face was detected (HTTP 422 / liveness check failed).
final class IdemitySpoofDetectedException extends IdemityApiException {
  const IdemitySpoofDetectedException([String message = 'Liveness check failed — spoof detected'])
      : super(message, code: 'SPOOF_DETECTED');
}

/// Rate limit exceeded (HTTP 429).
final class IdemityRateLimitException extends IdemityApiException {
  const IdemityRateLimitException([String message = 'Rate limit exceeded'])
      : super(message, code: 'RATE_LIMIT_EXCEEDED');
}

/// Plan quota exceeded — upgrade required (HTTP 402).
final class IdemityQuotaExceededException extends IdemityApiException {
  const IdemityQuotaExceededException(super.message, {super.code});
}

/// An unexpected server-side error occurred (HTTP 5xx).
final class IdemityServerException extends IdemityApiException {
  final int statusCode;

  const IdemityServerException(super.message, this.statusCode, {super.code});

  @override
  String toString() => 'IdemityServerException($statusCode): $message';
}

/// A network or connectivity error (no HTTP response received).
final class IdemityNetworkException extends IdemityApiException {
  final Object? cause;

  const IdemityNetworkException([String message = 'Network error', this.cause])
      : super(message, code: 'NETWORK_ERROR');
}
