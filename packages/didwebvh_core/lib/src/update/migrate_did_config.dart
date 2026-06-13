import 'package:didwebvh_core/src/core/did_webvh_state.dart';
import 'package:didwebvh_core/src/signing/signer.dart';
import 'package:didwebvh_core/src/update/migrate_did_operation.dart';
import 'package:didwebvh_core/src/update/update_did_result.dart';

/// Builder for configuring a DID migration (spec section 3.7.6).
///
/// Required fields: [existingState], [signer], and [newDomain]. The DID must
/// have been created with `portable: true`. Faithful port of Java
/// `MigrateDidConfig`; [execute] is `async`.
class MigrateDidConfig {
  /// Creates a config for migrating [existingState] (signed by [signer]) to
  /// [newDomain]. An optional [newPath] may also be supplied here.
  MigrateDidConfig(
    this.existingState,
    this.signer,
    this.newDomain, {
    String? newPath,
  }) {
    if (newPath != null) this.newPath(newPath);
  }

  /// The current DID state.
  final DidWebVhState? existingState;

  /// The authorised signing key.
  final Signer? signer;

  /// The target domain (e.g. `new.example.com`).
  final String? newDomain;

  String? _newPath;

  /// Optional path component for the new DID (e.g. `dids:issuer`).
  MigrateDidConfig newPath(String path) {
    _newPath = path;
    return this;
  }

  /// Execute the migration and return the result.
  Future<UpdateDidResult> execute() => MigrateDidOperation.execute(this);

  /// The configured new-DID path component, or `null`.
  String? get newPathValue => _newPath;
}
