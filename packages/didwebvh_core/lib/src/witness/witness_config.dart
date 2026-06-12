import 'package:didwebvh_core/src/model/json.dart';
import 'package:didwebvh_core/src/witness/witness_entry.dart';

/// Witness configuration: a threshold and a list of witnesses.
///
/// Faithful port of Java `WitnessConfig` together with its
/// `WitnessConfigTypeAdapter`. An empty config serializes as `{}` (matching the
/// Python/TS implementations), and a configured one as
/// `{"threshold":N,"witnesses":[...]}`, so canonicalized hashes align across
/// implementations.
class WitnessConfig {
  /// Creates a config with the given [threshold] and [witnesses].
  WitnessConfig(this.threshold, List<WitnessEntry>? witnesses)
      : witnesses = witnesses == null
            ? const []
            : List<WitnessEntry>.unmodifiable(witnesses);

  /// Returns a config representing "no witnesses" (`witness: {}` in the spec).
  factory WitnessConfig.empty() => WitnessConfig(0, const []);

  /// Parses a witness config from a decoded JSON object [json].
  ///
  /// Accepts the empty form (`{}`), a missing field, or the configured form;
  /// mirrors the lenient reader of `WitnessConfigTypeAdapter`.
  factory WitnessConfig.fromJson(Map<String, Object?> json) {
    final threshold = (json['threshold'] as num?)?.toInt() ?? 0;
    final witnesses = <WitnessEntry>[];
    final rawWitnesses = json['witnesses'];
    if (rawWitnesses is List) {
      for (final item in rawWitnesses) {
        final id = item is Map ? item['id'] as String? : null;
        witnesses.add(WitnessEntry(id));
      }
    }
    return WitnessConfig(threshold, witnesses);
  }

  /// The witness threshold.
  final int threshold;

  /// The configured witnesses (possibly empty, never null).
  final List<WitnessEntry> witnesses;

  /// Returns `true` if this config has at least one witness configured.
  bool get isActive => witnesses.isNotEmpty;

  /// Serializes this config in the spec's `witness` form (`{}` when inactive).
  Map<String, Object?> toJson() {
    if (!isActive) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      'threshold': threshold,
      'witnesses': [
        for (final entry in witnesses) <String, Object?>{'id': entry.id},
      ],
    };
  }

  @override
  bool operator ==(Object other) =>
      other is WitnessConfig &&
      threshold == other.threshold &&
      jsonDeepEquals(witnesses, other.witnesses);

  @override
  int get hashCode => Object.hash(threshold, jsonDeepHash(witnesses));
}
