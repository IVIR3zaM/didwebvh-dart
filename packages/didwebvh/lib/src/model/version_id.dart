import 'package:didwebvh/src/core/exceptions.dart';

/// A did:webvh version identifier of the form `"<versionNumber>-<entryHash>"`.
///
/// For the preliminary first entry of a new log, the raw value is the SCID
/// itself (no leading number and dash); use [VersionId.preliminary] for that
/// case. Faithful port of Java `VersionId`.
class VersionId {
  const VersionId._(this.versionNumber, this.entryHash, this._preliminary);

  /// Creates a non-preliminary version id from a [versionNumber] (>= 1) and a
  /// non-empty [entryHash].
  factory VersionId.of(int versionNumber, String entryHash) {
    if (versionNumber < 1) {
      throw ValidationException(
        'versionNumber must be >= 1, was $versionNumber',
      );
    }
    if (entryHash.isEmpty) {
      throw ValidationException('entryHash must be non-empty');
    }
    return VersionId._(versionNumber, entryHash, false);
  }

  /// Placeholder version id used when computing the first entry hash; the raw
  /// value is the [scid].
  factory VersionId.preliminary(String scid) {
    if (scid.isEmpty) {
      throw ValidationException('scid must be non-empty');
    }
    return VersionId._(0, scid, true);
  }

  /// Parses a `"<number>-<hash>"` version id from [raw].
  factory VersionId.parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      throw ValidationException('versionId must be non-empty');
    }
    final dash = raw.indexOf('-');
    if (dash <= 0 || dash == raw.length - 1) {
      throw ValidationException(
        "versionId must be of the form '<number>-<hash>': $raw",
      );
    }
    final number = int.tryParse(raw.substring(0, dash));
    if (number == null) {
      throw ValidationException('versionId has non-numeric version: $raw');
    }
    return VersionId.of(number, raw.substring(dash + 1));
  }

  /// The numeric version (0 for a preliminary id).
  final int versionNumber;

  /// The entry hash (or the SCID, for a preliminary id).
  final String entryHash;

  final bool _preliminary;

  /// Whether this is the preliminary placeholder id (raw value is the SCID).
  bool get isPreliminary => _preliminary;

  @override
  String toString() =>
      _preliminary ? entryHash : '$versionNumber-$entryHash';

  @override
  bool operator ==(Object other) =>
      other is VersionId &&
      versionNumber == other.versionNumber &&
      _preliminary == other._preliminary &&
      entryHash == other.entryHash;

  @override
  int get hashCode => Object.hash(versionNumber, entryHash, _preliminary);
}
