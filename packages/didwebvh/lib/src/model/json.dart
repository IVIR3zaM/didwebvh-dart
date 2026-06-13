/// Deep structural equality and hashing for decoded JSON values.
///
/// The Java models lean on Gson's `JsonObject`/`JsonArray` (and `List`)
/// `equals`/`hashCode`, which are deep. Dart's built-in `Map`/`List` equality
/// is identity-based, so the ported value classes use these helpers to
/// reproduce the same observable equality semantics.
library;

/// Returns `true` when [a] and [b] are structurally equal, recursing into
/// [Map]s and [List]s and comparing scalars with `==`.
bool jsonDeepEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || !jsonDeepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!jsonDeepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

/// Computes a hash for [value] consistent with [jsonDeepEquals].
///
/// [Map] hashing is order-independent (matching `JsonObject`); [List] hashing
/// is order-sensitive.
int jsonDeepHash(Object? value) {
  if (value is Map) {
    var hash = 0;
    for (final entry in value.entries) {
      hash ^= Object.hash(entry.key, jsonDeepHash(entry.value));
    }
    return hash;
  }
  if (value is List) {
    return Object.hashAll(value.map<Object?>(jsonDeepHash));
  }
  return value.hashCode;
}
