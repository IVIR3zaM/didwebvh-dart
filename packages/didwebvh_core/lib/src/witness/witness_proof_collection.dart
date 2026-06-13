import 'package:didwebvh_core/src/model/json.dart';
import 'package:didwebvh_core/src/model/json_support.dart';
import 'package:didwebvh_core/src/witness/witness_proof_entry.dart';

/// Collection of witness proof entries, matching the `did-witness.json` file
/// layout.
///
/// Faithful port of Java `WitnessProofCollection`. The on-disk
/// `did-witness.json` is a bare JSON array of [WitnessProofEntry]; parse it
/// into a list and wrap it with this collection (mirroring Java's
/// `gson.fromJson(json, WitnessProofEntry[].class)` plus the list constructor).
class WitnessProofCollection implements JsonModel {
  /// Creates a collection wrapping [entries] (a defensive copy is stored).
  WitnessProofCollection([List<WitnessProofEntry>? entries])
      : _entries = entries == null
            ? null
            : List<WitnessProofEntry>.unmodifiable(entries);

  /// Parses a collection from its object form (`{"entries":[...]}`), the shape
  /// Gson produces for a `WitnessProofCollection` (distinct from the bare
  /// `did-witness.json` array, which is parsed entry-by-entry).
  factory WitnessProofCollection.fromJson(Map<String, Object?> json) {
    final entries = json['entries'];
    return WitnessProofCollection(
      entries is List
          ? [
              for (final item in entries)
                WitnessProofEntry.fromJson((item as Map).cast()),
            ]
          : null,
    );
  }

  final List<WitnessProofEntry>? _entries;

  /// The proof entries (never `null`; empty when none were configured).
  List<WitnessProofEntry> get entries => _entries ?? const [];

  @override
  Map<String, Object?> toJson({bool omitNull = false}) => <String, Object?>{
        'entries': _entries?.map((e) => e.toJson(omitNull: omitNull)).toList(),
      };

  @override
  bool operator ==(Object other) =>
      other is WitnessProofCollection &&
      jsonDeepEquals(_entries, other._entries);

  @override
  int get hashCode => jsonDeepHash(_entries);
}
