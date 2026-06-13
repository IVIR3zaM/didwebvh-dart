/// Exception hierarchy for did:webvh.
///
/// Faithful port of the Java `core/` exception classes
/// (`DidWebVhException`, `ValidationException`, `SigningException`,
/// `UrlParseException`, `ResolutionException`).
library;

/// Base runtime exception for all did:webvh errors.
///
/// Faithful port of `DidWebVhException` (Java `extends RuntimeException`).
class DidWebVhException implements Exception {
  /// Creates an exception with a [message] and an optional underlying [cause].
  DidWebVhException(this.message, [this.cause]);

  /// Human-readable description of the failure.
  final String message;

  /// The underlying cause, if this exception wraps another error.
  final Object? cause;

  @override
  String toString() => 'DidWebVhException: $message';
}

/// Thrown when input data fails validation.
///
/// Faithful port of `ValidationException`.
class ValidationException extends DidWebVhException {
  /// Creates a validation exception with a [message] and optional [cause].
  ValidationException(super.message, [super.cause]);

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when signing or proof generation fails.
///
/// Faithful port of `SigningException`.
class SigningException extends DidWebVhException {
  /// Creates a signing exception with a [message] and optional [cause].
  SigningException(super.message, [super.cause]);

  @override
  String toString() => 'SigningException: $message';
}

/// Thrown when a did:webvh URL cannot be parsed.
///
/// Faithful port of `UrlParseException`.
class UrlParseException extends DidWebVhException {
  /// Creates a URL parse exception with a [message] and optional [cause].
  UrlParseException(super.message, [super.cause]);

  @override
  String toString() => 'UrlParseException: $message';
}

/// Thrown when DID resolution fails.
///
/// Faithful port of `ResolutionException`. Carries an optional machine-readable
/// [error] code and, when present, a derived RFC 9457 style [problemDetails]
/// object (`type`/`title`/`detail`).
class ResolutionException extends DidWebVhException {
  /// Creates a resolution exception with only a [message] (no error code).
  ResolutionException(super.message, [super.cause])
      : error = null,
        _problemDetails = null;

  /// Creates a resolution exception with a machine-readable [error] code, from
  /// which the [problemDetails] object is derived.
  ResolutionException.withError(String message, this.error, [Object? cause])
      : _problemDetails = _problemDetailsFor(error, message),
        super(message, cause);

  static const String _problemTypePrefix = 'urn:didwebvh:error:';

  /// Machine-readable error code (e.g. `invalidDid`, `notFound`), or `null`.
  final String? error;

  final Map<String, Object?>? _problemDetails;

  /// A defensive copy of the derived problem-details object, or `null`.
  Map<String, Object?>? get problemDetails =>
      _problemDetails == null ? null : Map<String, Object?>.of(_problemDetails);

  static Map<String, Object?> _problemDetailsFor(
    String? error,
    String message,
  ) {
    return <String, Object?>{
      'type': _problemTypePrefix + _safeProblemType(error),
      'title': _titleFor(error),
      'detail': message,
    };
  }

  static String _safeProblemType(String? error) {
    if (error == null || error.isEmpty) {
      return 'unknown';
    }
    return error.replaceAll(RegExp('[^A-Za-z0-9._~-]'), '-');
  }

  static String _titleFor(String? error) {
    if (error == 'invalidDid') {
      return 'Invalid DID';
    }
    if (error == 'notFound') {
      return 'Not Found';
    }
    if (error == 'httpError') {
      return 'HTTP Error';
    }
    return error == null || error.isEmpty ? 'Resolution Error' : error;
  }

  @override
  String toString() => 'ResolutionException: $message';
}
