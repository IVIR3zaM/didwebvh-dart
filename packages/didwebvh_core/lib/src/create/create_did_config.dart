import 'dart:convert';

import 'package:didwebvh_core/src/create/create_did_operation.dart';
import 'package:didwebvh_core/src/create/create_did_result.dart';
import 'package:didwebvh_core/src/signing/signer.dart';
import 'package:didwebvh_core/src/witness/witness_config.dart';

/// Builder for configuring a new DID creation.
///
/// Required fields: [domain] and [signer]. Faithful port of Java
/// `CreateDidConfig`; [execute] is `async` (returns a `Future`) per the ported
/// async [Signer].
///
/// Three call styles are supported and fully interchangeable — the optional
/// settings can be supplied however reads best:
///
/// ```dart
/// // 1. Fluent (Java-style chaining; setters return `this`):
/// await DidWebVh.create('example.com', signer)
///     .portable(true)
///     .ttl(3600)
///     .execute();
///
/// // 2. Cascade (idiomatic Dart; `..` ignores the return value):
/// await (DidWebVh.create('example.com', signer)
///       ..portable(true)
///       ..ttl(3600))
///     .execute();
///
/// // 3. Named parameters (set at construction; delegate to the setters):
/// await DidWebVh.create('example.com', signer, portable: true, ttl: 3600)
///     .execute();
/// ```
class CreateDidConfig {
  /// Creates a config for the given [domain] and [signer] (both required).
  ///
  /// Any optional setting may also be supplied here as a named argument; each
  /// non-null value is applied through its like-named setter, so construction
  /// is exactly equivalent to the fluent/cascade forms.
  CreateDidConfig(
    this.domain,
    this.signer, {
    String? path,
    bool? portable,
    int? ttl,
    List<String>? alsoKnownAs,
    List<String>? controllers,
    WitnessConfig? witness,
    List<String>? watchers,
    List<String>? nextKeyHashes,
    Map<String, Object?>? additionalDocumentContent,
  }) {
    if (path != null) this.path(path);
    if (portable != null) this.portable(portable);
    if (ttl != null) this.ttl(ttl);
    if (alsoKnownAs != null) this.alsoKnownAs(alsoKnownAs);
    if (controllers != null) this.controllers(controllers);
    if (witness != null) this.witness(witness);
    if (watchers != null) this.watchers(watchers);
    if (nextKeyHashes != null) this.nextKeyHashes(nextKeyHashes);
    if (additionalDocumentContent != null) {
      this.additionalDocumentContent(additionalDocumentContent);
    }
  }

  /// The web domain (e.g. `example.com`).
  final String? domain;

  /// The signing key to use.
  final Signer? signer;

  String? _path;
  bool? _portable;
  int? _ttl;
  List<String>? _alsoKnownAs;
  List<String>? _controllers;
  WitnessConfig? _witness;
  List<String>? _watchers;
  List<String>? _nextKeyHashes;
  Map<String, Object?>? _additionalDocumentContent;

  /// Sets the DID [path] (extra colon-separated segments).
  CreateDidConfig path(String path) {
    _path = path;
    return this;
  }

  /// Sets whether the DID is portable.
  CreateDidConfig portable(bool portable) {
    _portable = portable;
    return this;
  }

  /// Sets the cache time-to-live in seconds.
  CreateDidConfig ttl(int ttl) {
    _ttl = ttl;
    return this;
  }

  /// Sets the DID Document `alsoKnownAs` aliases.
  CreateDidConfig alsoKnownAs(List<String>? alsoKnownAs) {
    _alsoKnownAs = alsoKnownAs == null ? null : List<String>.of(alsoKnownAs);
    return this;
  }

  /// Sets the DID Document `controller` property.
  ///
  /// Per DID Core v1.0 §5.1.2 `controller` is optional; the webvh spec adds no
  /// requirement on top of that. This method lets callers opt into explicit
  /// controller values:
  ///
  /// - `null` (default) – emit `"controller": "<this DID>"`, the historical
  ///   behaviour;
  /// - empty list – omit the `controller` property entirely;
  /// - one element – emit `"controller": "<did>"` (string form);
  /// - multiple elements – emit `"controller": [...]` (array form).
  CreateDidConfig controllers(List<String>? controllers) {
    _controllers = controllers == null ? null : List<String>.of(controllers);
    return this;
  }

  /// Sets the witness configuration.
  CreateDidConfig witness(WitnessConfig witness) {
    _witness = witness;
    return this;
  }

  /// Sets the watcher URLs.
  CreateDidConfig watchers(List<String>? watchers) {
    _watchers = watchers == null ? null : List<String>.of(watchers);
    return this;
  }

  /// Sets the pre-rotation next-key hashes.
  CreateDidConfig nextKeyHashes(List<String>? nextKeyHashes) {
    _nextKeyHashes =
        nextKeyHashes == null ? null : List<String>.of(nextKeyHashes);
    return this;
  }

  /// Sets additional DID Document content (services, extra verification
  /// methods, etc.). A defensive deep copy is stored.
  CreateDidConfig additionalDocumentContent(Map<String, Object?>? content) {
    _additionalDocumentContent = content == null
        ? null
        : (jsonDecode(jsonEncode(content)) as Map).cast<String, Object?>();
    return this;
  }

  /// Execute the DID creation and return the result.
  Future<CreateDidResult> execute() => CreateDidOperation.execute(this);

  // Package-private accessors for CreateDidOperation (Java's package-private
  // getters). Named with a `Value` suffix where they would otherwise clash with
  // the like-named fluent setter.

  /// The configured DID path, or `null`.
  String? get pathValue => _path;

  /// The configured `portable` flag, or `null` if unset.
  bool? get portableValue => _portable;

  /// The configured `ttl`, or `null` if unset.
  int? get ttlValue => _ttl;

  /// The configured `alsoKnownAs` aliases, or `null`.
  List<String>? get alsoKnownAsValue => _alsoKnownAs;

  /// The configured `controller` values, or `null` (default behaviour).
  List<String>? get controllersValue => _controllers;

  /// The configured witness configuration, or `null`.
  WitnessConfig? get witnessValue => _witness;

  /// The configured watcher URLs, or `null`.
  List<String>? get watchersValue => _watchers;

  /// The configured pre-rotation next-key hashes, or `null`.
  List<String>? get nextKeyHashesValue => _nextKeyHashes;

  /// The configured additional DID Document content, or `null`.
  Map<String, Object?>? get additionalDocumentContentValue =>
      _additionalDocumentContent;
}
