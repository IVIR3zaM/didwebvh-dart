/// Exception hierarchy for did:webvh.
///
/// NOTE: this is a **minimal** subset introduced by iteration 2 (crypto
/// primitives) because the JCS, multihash and multikey utilities throw
/// [ValidationException]. Iteration 3 (model classes + exceptions) owns the
/// full hierarchy and may flesh these out; the names and base type mirror the
/// Java `DidWebVhException` / `ValidationException` so it can build on them.
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
