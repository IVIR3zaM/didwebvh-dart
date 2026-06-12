import 'package:didwebvh_core/src/model/did_document.dart';
import 'package:didwebvh_core/src/model/json.dart';
import 'package:didwebvh_core/src/model/resolution_metadata.dart';

/// Result of resolving a did:webvh DID URL.
///
/// Faithful port of Java `ResolveResult` (a mutable container; setters become
/// direct field assignment in Dart).
class ResolveResult {
  /// Creates an empty result (all fields unset).
  ResolveResult();

  /// The resolved DID document.
  DidDocument? didDocument;

  /// The resolution metadata.
  ResolutionMetadata? metadata;

  /// A machine-readable error code, when resolution failed.
  String? error;

  /// A problem-details object, when resolution failed.
  Map<String, Object?>? problemDetails;

  @override
  bool operator ==(Object other) =>
      other is ResolveResult &&
      didDocument == other.didDocument &&
      metadata == other.metadata &&
      error == other.error &&
      jsonDeepEquals(problemDetails, other.problemDetails);

  @override
  int get hashCode => Object.hash(
        didDocument,
        metadata,
        error,
        jsonDeepHash(problemDetails),
      );
}
