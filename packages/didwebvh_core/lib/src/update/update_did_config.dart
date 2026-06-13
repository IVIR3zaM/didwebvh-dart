import 'dart:convert';

import 'package:didwebvh_core/src/core/did_webvh_state.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:didwebvh_core/src/signing/signer.dart';
import 'package:didwebvh_core/src/update/update_did_operation.dart';
import 'package:didwebvh_core/src/update/update_did_result.dart';

/// Builder for configuring a standard DID update (spec section 3.6.3).
///
/// Required fields: [existingState] and [signer]. Faithful port of Java
/// `UpdateDidConfig`; [execute] is `async` (returns a `Future`) per the ported
/// async [Signer]. The three call styles (fluent, cascade, named parameters)
/// match [the create builder]; see `docs/PORTING-DECISIONS.md` §8.
class UpdateDidConfig {
  /// Creates a config for the given [existingState] and [signer] (both
  /// required). The optional update settings may also be supplied here as named
  /// arguments; each non-null value is applied through its like-named setter.
  UpdateDidConfig(
    this.existingState,
    this.signer, {
    Map<String, Object?>? newDocument,
    Parameters? changedParameters,
  }) {
    if (newDocument != null) this.newDocument(newDocument);
    if (changedParameters != null) this.changedParameters(changedParameters);
  }

  /// The current DID state (all existing log entries).
  final DidWebVhState? existingState;

  /// The authorised signing key.
  final Signer? signer;

  Map<String, Object?>? _newDocument;
  Parameters? _changedParameters;

  /// Replace the DID Document state. If not set the existing state document is
  /// kept. A defensive deep copy is stored.
  UpdateDidConfig newDocument(Map<String, Object?>? document) {
    _newDocument = document == null
        ? null
        : (jsonDecode(jsonEncode(document)) as Map).cast<String, Object?>();
    return this;
  }

  /// Partial parameters to change. Only non-null fields are applied on top of
  /// the current active parameters. Pass an empty `Parameters()` (all-null) to
  /// include an empty `{}` parameters delta.
  UpdateDidConfig changedParameters(Parameters? parameters) {
    _changedParameters = parameters;
    return this;
  }

  /// Execute the update and return the result.
  Future<UpdateDidResult> execute() => UpdateDidOperation.execute(this);

  /// The configured replacement document, or `null` to carry forward.
  Map<String, Object?>? get newDocumentValue => _newDocument;

  /// The configured parameter delta, or `null` for an empty delta.
  Parameters? get changedParametersValue => _changedParameters;
}
