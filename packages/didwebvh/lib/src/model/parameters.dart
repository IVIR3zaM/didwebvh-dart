import 'package:didwebvh/src/model/json.dart';
import 'package:didwebvh/src/model/json_support.dart';
import 'package:didwebvh/src/witness/witness_config.dart';

/// did:webvh log entry parameters (spec section 3.7.1).
///
/// All fields are optional; an entry with no parameter changes serializes to
/// `{}`. Use [merge] to apply a later entry's changes onto the effective set.
/// Faithful port of Java `Parameters`.
class Parameters implements JsonModel {
  /// Creates an empty parameters object (all fields unset).
  Parameters();

  /// Parses parameters from a decoded JSON object [json].
  factory Parameters.fromJson(Map<String, Object?> json) {
    final witness = json['witness'];
    return Parameters()
      ..method = json['method'] as String?
      ..scid = json['scid'] as String?
      ..updateKeys = _stringList(json['updateKeys'])
      ..nextKeyHashes = _stringList(json['nextKeyHashes'])
      ..witness =
          witness is Map ? WitnessConfig.fromJson(witness.cast()) : null
      ..watchers = _stringList(json['watchers'])
      ..portable = json['portable'] as bool?
      ..deactivated = json['deactivated'] as bool?
      ..ttl = (json['ttl'] as num?)?.toInt();
  }

  /// Returns parameters pre-populated with spec-defined defaults (section
  /// 3.7.1): `ttl` = 3600, `portable` = false, `deactivated` = false,
  /// `witness` = empty config, `watchers` = empty list.
  factory Parameters.defaults() => Parameters()
    ..ttl = 3600
    ..portable = false
    ..deactivated = false
    ..witness = WitnessConfig.empty()
    ..watchers = const [];

  /// The did:webvh method/version (e.g. `did:webvh:1.0`).
  String? method;

  /// The self-certifying identifier.
  String? scid;

  /// The active update keys (base58btc multikeys).
  List<String>? updateKeys;

  /// The pre-rotation next-key hashes.
  List<String>? nextKeyHashes;

  /// The witness configuration.
  WitnessConfig? witness;

  /// The watcher URLs.
  List<String>? watchers;

  /// Whether the DID is portable.
  bool? portable;

  /// Whether the DID is deactivated.
  bool? deactivated;

  /// The cache time-to-live in seconds (`0` means "do not cache").
  int? ttl;

  /// Applies [other]'s non-null fields on top of this instance, returning a new
  /// object. Both `this` and [other] are left unmodified.
  Parameters merge(Parameters? other) {
    final out = Parameters()
      ..method = method
      ..scid = scid
      ..updateKeys = updateKeys
      ..nextKeyHashes = nextKeyHashes
      ..witness = witness
      ..watchers = watchers
      ..portable = portable
      ..deactivated = deactivated
      ..ttl = ttl;
    if (other == null) {
      return out;
    }
    if (other.method != null) {
      out.method = other.method;
    }
    if (other.scid != null) {
      out.scid = other.scid;
    }
    if (other.updateKeys != null) {
      out.updateKeys = other.updateKeys;
    }
    if (other.nextKeyHashes != null) {
      out.nextKeyHashes = other.nextKeyHashes;
    }
    if (other.witness != null) {
      out.witness = other.witness;
    }
    if (other.watchers != null) {
      out.watchers = other.watchers;
    }
    if (other.portable != null) {
      out.portable = other.portable;
    }
    if (other.deactivated != null) {
      out.deactivated = other.deactivated;
    }
    if (other.ttl != null) {
      out.ttl = other.ttl;
    }
    return out;
  }

  @override
  Map<String, Object?> toJson({bool omitNull = false}) {
    final json = <String, Object?>{};
    void put(String key, Object? value) {
      if (value != null || !omitNull) {
        json[key] = value;
      }
    }

    put('method', method);
    put('scid', scid);
    put('updateKeys', updateKeys);
    put('nextKeyHashes', nextKeyHashes);
    put('witness', witness?.toJson());
    put('watchers', watchers);
    put('portable', portable);
    put('deactivated', deactivated);
    put('ttl', ttl);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is Parameters &&
      method == other.method &&
      scid == other.scid &&
      jsonDeepEquals(updateKeys, other.updateKeys) &&
      jsonDeepEquals(nextKeyHashes, other.nextKeyHashes) &&
      witness == other.witness &&
      jsonDeepEquals(watchers, other.watchers) &&
      portable == other.portable &&
      deactivated == other.deactivated &&
      ttl == other.ttl;

  @override
  int get hashCode => Object.hash(
        method,
        scid,
        jsonDeepHash(updateKeys),
        jsonDeepHash(nextKeyHashes),
        witness,
        jsonDeepHash(watchers),
        portable,
        deactivated,
        ttl,
      );

  static List<String>? _stringList(Object? value) {
    if (value is List) {
      return [for (final item in value) item as String];
    }
    return null;
  }
}
