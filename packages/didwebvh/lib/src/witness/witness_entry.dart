/// A single witness identified by a did:key DID.
///
/// Faithful port of Java `WitnessEntry`.
class WitnessEntry {
  /// Creates a witness entry for the given [id] (a did:key DID).
  const WitnessEntry(this.id);

  /// The witness DID.
  final String? id;

  @override
  bool operator ==(Object other) => other is WitnessEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
