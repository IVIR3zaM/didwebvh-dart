import 'package:didwebvh_core/src/model/json.dart';
import 'package:didwebvh_core/src/model/json_support.dart';
import 'package:didwebvh_core/src/witness/witness_config.dart';

/// Metadata returned alongside a resolved DID Document.
///
/// Faithful port of Java `ResolutionMetadata`.
class ResolutionMetadata implements JsonModel {
  /// Creates an empty metadata object (all fields unset).
  ResolutionMetadata();

  /// Parses metadata from a decoded JSON object [json].
  factory ResolutionMetadata.fromJson(Map<String, Object?> json) {
    final witness = json['witness'];
    return ResolutionMetadata()
      ..versionId = json['versionId'] as String?
      ..versionTime = json['versionTime'] as String?
      ..created = json['created'] as String?
      ..updated = json['updated'] as String?
      ..scid = json['scid'] as String?
      ..portable = json['portable'] as bool?
      ..deactivated = json['deactivated'] as bool?
      ..ttl = json['ttl'] as String?
      ..witness =
          witness is Map ? WitnessConfig.fromJson(witness.cast()) : null
      ..watchers = _stringList(json['watchers']);
  }

  /// The resolved version id.
  String? versionId;

  /// The resolved version time.
  String? versionTime;

  /// The DID creation timestamp.
  String? created;

  /// The DID last-updated timestamp.
  String? updated;

  /// The self-certifying identifier.
  String? scid;

  /// Whether the DID is portable.
  bool? portable;

  /// Whether the DID is deactivated.
  bool? deactivated;

  /// The cache time-to-live (as a string).
  String? ttl;

  /// The witness configuration.
  WitnessConfig? witness;

  /// The watcher URLs.
  List<String>? watchers;

  @override
  Map<String, Object?> toJson({bool omitNull = false}) {
    final json = <String, Object?>{};
    void put(String key, Object? value) {
      if (value != null || !omitNull) {
        json[key] = value;
      }
    }

    put('versionId', versionId);
    put('versionTime', versionTime);
    put('created', created);
    put('updated', updated);
    put('scid', scid);
    put('portable', portable);
    put('deactivated', deactivated);
    put('ttl', ttl);
    put('witness', witness?.toJson());
    put('watchers', watchers);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is ResolutionMetadata &&
      versionId == other.versionId &&
      versionTime == other.versionTime &&
      created == other.created &&
      updated == other.updated &&
      scid == other.scid &&
      portable == other.portable &&
      deactivated == other.deactivated &&
      ttl == other.ttl &&
      witness == other.witness &&
      jsonDeepEquals(watchers, other.watchers);

  @override
  int get hashCode => Object.hash(
        versionId,
        versionTime,
        created,
        updated,
        scid,
        portable,
        deactivated,
        ttl,
        witness,
        jsonDeepHash(watchers),
      );

  static List<String>? _stringList(Object? value) {
    if (value is List) {
      return [for (final item in value) item as String];
    }
    return null;
  }
}
