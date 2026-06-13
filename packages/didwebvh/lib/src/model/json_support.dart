import 'dart:convert';

/// A model type that serializes to a JSON-object map.
///
/// The single [toJson] entry point replaces Java's two configured Gson
/// instances: passing `omitNull: false` mirrors `serializeNulls()`
/// (explicit nulls kept), while `omitNull: true` mirrors the compact instance
/// used to produce canonical log lines.
// ignore: one_member_abstracts
abstract interface class JsonModel {
  /// Serializes this model to a JSON-object map.
  ///
  /// When [omitNull] is `true`, fields whose value is `null` are omitted
  /// entirely (rather than written as `null`).
  Map<String, Object?> toJson({bool omitNull = false});
}

/// Shared JSON encoders for did:webvh model serialization.
///
/// Faithful port of Java's `JsonSupport`: [gson] preserves explicit nulls
/// (round-trip tests), [compact] omits them (canonical log lines). Dart's
/// [jsonEncode] already disables HTML escaping and emits no insignificant
/// whitespace, matching the Java configuration.
abstract final class JsonSupport {
  /// Encodes [model] keeping explicit null fields (≈ Gson `serializeNulls()`).
  static String gson(JsonModel model) => jsonEncode(model.toJson());

  /// Encodes [model] omitting null fields (≈ the compact Gson instance).
  static String compact(JsonModel model) =>
      jsonEncode(model.toJson(omitNull: true));
}
