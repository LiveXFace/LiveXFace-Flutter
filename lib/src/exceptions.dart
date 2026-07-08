/// Exceptions thrown by the Serupa SDK.

/// Base class for all Serupa errors.
sealed class SerupaApiException implements Exception {
  final String message;
  final String? code;

  const SerupaApiException(this.message, {this.code});

  @override
  String toString() => 'SerupaApiException(${code ?? 'unknown'}): $message';
}

/// The request was malformed or failed validation (HTTP 400 / 422).
final class SerupaValidationException extends SerupaApiException {
  const SerupaValidationException(super.message, {super.code});
}

/// Authentication failed — invalid or missing API key (HTTP 401).
final class SerupaUnauthorizedException extends SerupaApiException {
  const SerupaUnauthorizedException(super.message, {super.code});
}

/// The API key does not have access to this resource (HTTP 403).
final class SerupaForbiddenException extends SerupaApiException {
  const SerupaForbiddenException(super.message, {super.code});
}

/// The requested resource does not exist (HTTP 404).
final class SerupaNotFoundException extends SerupaApiException {
  const SerupaNotFoundException(super.message, {super.code});
}

/// No face was detected in the uploaded image (HTTP 422 NO_FACE_DETECTED).
final class SerupaNoFaceDetectedException extends SerupaApiException {
  const SerupaNoFaceDetectedException([String message = 'No face detected in image'])
      : super(message, code: 'NO_FACE_DETECTED');
}

/// A spoof or non-live face was detected (HTTP 422 / liveness check failed).
final class SerupaSpoofDetectedException extends SerupaApiException {
  const SerupaSpoofDetectedException([String message = 'Liveness check failed — spoof detected'])
      : super(message, code: 'SPOOF_DETECTED');
}

/// Rate limit exceeded (HTTP 429).
final class SerupaRateLimitException extends SerupaApiException {
  const SerupaRateLimitException([String message = 'Rate limit exceeded'])
      : super(message, code: 'RATE_LIMIT_EXCEEDED');
}

/// Plan quota exceeded — upgrade required (HTTP 402).
final class SerupaQuotaExceededException extends SerupaApiException {
  const SerupaQuotaExceededException(super.message, {super.code});
}

/// An unexpected server-side error occurred (HTTP 5xx).
final class SerupaServerException extends SerupaApiException {
  final int statusCode;

  const SerupaServerException(super.message, this.statusCode, {super.code});

  @override
  String toString() => 'SerupaServerException($statusCode): $message';
}

/// A network or connectivity error (no HTTP response received).
final class SerupaNetworkException extends SerupaApiException {
  final Object? cause;

  const SerupaNetworkException([String message = 'Network error', this.cause])
      : super(message, code: 'NETWORK_ERROR');
}
