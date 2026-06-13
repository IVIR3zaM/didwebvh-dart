import 'package:didwebvh/src/model/parameters.dart';

/// Result of a log chain validation run.
///
/// Faithful port of Java `ValidationResult`.
class ValidationResult {
  ValidationResult._(
    this.valid,
    this.lastValidEntryIndex,
    this.failureReason,
    this.failedEntryIndex,
    this.activeParameters,
  );

  /// Creates a successful result whose last valid entry is at [lastIndex].
  factory ValidationResult.success(
    int lastIndex,
    Parameters? activeParameters,
  ) =>
      ValidationResult._(true, lastIndex, null, -1, activeParameters);

  /// Creates a failed result with the given indices, [reason], and parameters.
  factory ValidationResult.failure(
    int lastValidIndex,
    int failedIndex,
    String reason,
    Parameters? activeParameters,
  ) =>
      ValidationResult._(
        false,
        lastValidIndex,
        reason,
        failedIndex,
        activeParameters,
      );

  /// Whether the log chain is valid.
  final bool valid;

  /// Index of the last entry that validated, or `-1`.
  final int lastValidEntryIndex;

  /// The failure reason, or `null` when [valid].
  final String? failureReason;

  /// Index of the entry that failed, or `-1`.
  final int failedEntryIndex;

  /// The accumulated active parameters at the point validation stopped.
  final Parameters? activeParameters;
}
