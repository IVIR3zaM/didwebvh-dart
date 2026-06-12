import 'dart:convert';

import 'package:didwebvh_core/src/model/json.dart';

/// Thin wrapper around a decoded JSON object representing a DID Document.
///
/// No validation is performed — this is purely a convenience container.
/// Faithful port of Java `DidDocument`.
class DidDocument {
  /// Wraps [json] (a `null` value yields an empty document).
  DidDocument(Map<String, Object?>? json) : _json = json ?? <String, Object?>{};

  final Map<String, Object?> _json;

  /// Returns the underlying JSON object.
  Map<String, Object?> asJsonObject() => _json;

  /// The `id` field, or `null`.
  String? get id => _stringOrNull('id');

  /// The `controller` field, normalized to a list of strings, or `null`.
  List<String>? get controller => _stringOrArray('controller');

  /// The `alsoKnownAs` field, normalized to a list of strings, or `null`.
  List<String>? get alsoKnownAs => _stringOrArray('alsoKnownAs');

  /// The `verificationMethod` array, or `null` when absent/not an array.
  List<Object?>? get verificationMethod => _arrayOrNull('verificationMethod');

  /// The `service` array, or `null` when absent/not an array.
  List<Object?>? get service => _arrayOrNull('service');

  /// Returns a new [DidDocument] with the `id` field replaced by [id].
  DidDocument withId(String id) {
    final copy = (jsonDecode(jsonEncode(_json)) as Map).cast<String, Object?>();
    copy['id'] = id;
    return DidDocument(copy);
  }

  String? _stringOrNull(String name) {
    final value = _json[name];
    return value is String ? value : null;
  }

  List<Object?>? _arrayOrNull(String name) {
    final value = _json[name];
    return value is List ? value : null;
  }

  List<String>? _stringOrArray(String name) {
    final value = _json[name];
    if (value == null) {
      return null;
    }
    if (value is List) {
      return List<String>.unmodifiable(value.map((e) => e as String));
    }
    return List<String>.unmodifiable([value as String]);
  }

  @override
  bool operator ==(Object other) =>
      other is DidDocument && jsonDeepEquals(_json, other._json);

  @override
  int get hashCode => jsonDeepHash(_json);
}
