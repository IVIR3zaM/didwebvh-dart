/// Result of a witness proof validation run.
///
/// Faithful port of Java `WitnessValidationResult`.
class WitnessValidationResult {
  WitnessValidationResult._(
    this.valid,
    this.failureReason,
    this.failedEntryIndex,
  );

  /// Creates a successful result.
  factory WitnessValidationResult.success() =>
      WitnessValidationResult._(true, null, -1);

  /// Creates a failed result for [failedEntryIndex] with the given [reason].
  factory WitnessValidationResult.failure(
    int failedEntryIndex,
    String reason,
  ) =>
      WitnessValidationResult._(false, reason, failedEntryIndex);

  /// Whether the witness proofs validate.
  final bool valid;

  /// The failure reason, or `null` when [valid].
  final String? failureReason;

  /// Index of the entry that failed witnessing, or `-1`.
  final int failedEntryIndex;
}
