/// Controls when HTTP resolution retrieves `did-witness.json`.
///
/// Faithful port of Java `ResolveOptions.WitnessFetchMode`.
enum WitnessFetchMode {
  /// Fetch witness proofs opportunistically and ignore 404 unless the log
  /// requires them.
  proactive,

  /// Fetch witness proofs only after the log is parsed and witness parameters
  /// are active.
  whenRequired,
}

/// Options that select a specific DID log version during resolution.
///
/// Faithful port of Java `ResolveOptions`, which exposes a fluent `Builder`.
/// Mirroring that public surface (and matching `CreateDidConfig`), three call
/// styles are supported and fully interchangeable:
///
/// ```dart
/// // 1. Fluent (Java-style chaining; setters return `this`):
/// ResolveOptions().versionNumber(1).witnessFetchMode(mode);
///
/// // 2. Cascade (idiomatic Dart; `..` ignores the return value):
/// ResolveOptions()
///   ..versionNumber(1)
///   ..witnessFetchMode(mode);
///
/// // 3. Named parameters (set at construction; delegate to the setters):
/// ResolveOptions(versionNumber: 1, witnessFetchMode: mode);
/// ```
class ResolveOptions {
  /// Creates options selecting at most one version (by [versionId],
  /// [versionTime], or [versionNumber]) with the given [witnessFetchMode].
  ///
  /// Any optional setting may also be supplied here as a named argument; each
  /// non-null value is applied through its like-named setter, so construction
  /// is exactly equivalent to the fluent/cascade forms.
  ResolveOptions({
    String? versionId,
    String? versionTime,
    int? versionNumber,
    WitnessFetchMode? witnessFetchMode,
  }) {
    if (versionId != null) this.versionId(versionId);
    if (versionTime != null) this.versionTime(versionTime);
    if (versionNumber != null) this.versionNumber(versionNumber);
    if (witnessFetchMode != null) this.witnessFetchMode(witnessFetchMode);
  }

  /// Returns options with no version selector and proactive witness fetch.
  factory ResolveOptions.defaults() => ResolveOptions();

  String? _versionId;
  String? _versionTime;
  int? _versionNumber;
  WitnessFetchMode _witnessFetchMode = WitnessFetchMode.proactive;

  /// Selects a specific DID log entry by its full versionId string.
  ResolveOptions versionId(String versionId) {
    _versionId = versionId;
    return this;
  }

  /// Selects the log entry that was active at the given ISO 8601 UTC instant.
  ResolveOptions versionTime(String versionTime) {
    _versionTime = versionTime;
    return this;
  }

  /// Selects a specific DID log entry by its version number.
  ResolveOptions versionNumber(int versionNumber) {
    _versionNumber = versionNumber;
    return this;
  }

  /// Sets how witness proofs are fetched during HTTP resolution; a `null`
  /// value resets to [WitnessFetchMode.proactive] (Java's builder default).
  ResolveOptions witnessFetchMode(WitnessFetchMode? witnessFetchMode) {
    _witnessFetchMode = witnessFetchMode ?? WitnessFetchMode.proactive;
    return this;
  }

  // Package-facing accessors. Named with a `Value` suffix where they would
  // otherwise clash with the like-named fluent setter (mirrors Java's
  // package-private getters and the `CreateDidConfig` convention).

  /// The versionId selector, or `null` if not set.
  String? get versionIdValue => _versionId;

  /// The versionTime selector, or `null` if not set.
  String? get versionTimeValue => _versionTime;

  /// The versionNumber selector, or `null` if not set.
  int? get versionNumberValue => _versionNumber;

  /// The witness fetch mode.
  WitnessFetchMode get witnessFetchModeValue => _witnessFetchMode;

  /// Returns a copy of these options with any unset version selector filled in
  /// from [fallback]; the witness fetch mode of `this` is always preserved.
  ResolveOptions withFallbacks(ResolveOptions? fallback) {
    if (fallback == null) {
      return this;
    }
    return ResolveOptions(
      versionId: _versionId ?? fallback._versionId,
      versionTime: _versionTime ?? fallback._versionTime,
      versionNumber: _versionNumber ?? fallback._versionNumber,
      witnessFetchMode: _witnessFetchMode,
    );
  }

  /// Whether more than one of versionId, versionTime, and versionNumber is set.
  bool get hasMultipleVersionSelectors {
    var count = 0;
    if (_versionId != null) {
      count++;
    }
    if (_versionTime != null) {
      count++;
    }
    if (_versionNumber != null) {
      count++;
    }
    return count > 1;
  }
}
