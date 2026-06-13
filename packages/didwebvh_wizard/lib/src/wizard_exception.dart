/// Thrown when the wizard cannot continue (invalid input, missing files,
/// aborted flow).
///
/// Faithful port of Java `WizardException`.
class WizardException implements Exception {
  /// Creates a wizard exception with a [message] and an optional [cause].
  WizardException(this.message, [this.cause]);

  /// Human-readable description of the failure.
  final String message;

  /// The underlying cause, if this exception wraps another error.
  final Object? cause;

  @override
  String toString() => 'WizardException: $message';
}
