import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/didweb/implicit_services.dart';
import 'package:didwebvh/src/model/did_document.dart';
import 'package:didwebvh/src/url/did_to_https_transformer.dart';
import 'package:didwebvh/src/url/did_webvh_url.dart';

/// Generates a parallel `did:web` DID Document from a resolved `did:webvh` DID
/// Document, as specified in spec section 3.7.10.
///
/// Faithful port of the Java `DidWebPublisher`.
abstract final class DidWebPublisher {
  /// Convert a resolved `did:webvh` DID Document into the parallel `did:web`
  /// DID Document per spec section 3.7.10.
  static DidDocument toDidWeb(DidDocument? resolvedWebVh) {
    if (resolvedWebVh == null) {
      throw ValidationException('resolved did:webvh document is required');
    }
    final didWebVh = resolvedWebVh.id;
    if (didWebVh == null || didWebVh.isEmpty) {
      throw ValidationException('did:webvh document missing id');
    }

    final parsed = DidWebVhUrl.parse(didWebVh);
    final scidPrefix = 'did:webvh:${parsed.scid}:';

    // Step 1: start from the resolved did:webvh DIDDoc (deep copy to avoid
    // mutation).
    final doc = (jsonDecode(jsonEncode(resolvedWebVh.asJsonObject())) as Map)
        .cast<String, Object?>();

    // Step 2: add implicit #files and #whois services if not already present.
    ImplicitServices.addTo(doc, didWebVh);

    // Step 3: text-replace did:webvh:<scid>: with did:web: across the whole
    // document.
    final replaced = jsonEncode(doc).replaceAll(scidPrefix, 'did:web:');
    final webDoc = (jsonDecode(replaced) as Map).cast<String, Object?>();

    // Steps 4 & 5: add the original did:webvh DID to alsoKnownAs and dedupe
    // (removing the did:web DID itself if it landed there from the
    // replacement).
    final didWeb = toDidWebUrl(didWebVh);
    _addAlsoKnownAs(webDoc, didWebVh, didWeb);

    return DidDocument(webDoc);
  }

  /// Convert a `did:webvh` DID string to the equivalent `did:web` DID string.
  static String toDidWebUrl(String didWebVhUrl) =>
      DidToHttpsTransformer.toDidWebUrl(didWebVhUrl);

  static void _addAlsoKnownAs(
    Map<String, Object?> doc,
    String didWebVh,
    String didWeb,
  ) {
    final seen = <String>{};
    final existing = doc['alsoKnownAs'];
    if (existing is List) {
      for (final el in existing) {
        if (el is String) {
          seen.add(el);
        }
      }
    }
    seen
      ..add(didWebVh)
      // Step 5: remove the did:web DID itself if it was duplicated in earlier
      // steps.
      ..remove(didWeb);

    doc['alsoKnownAs'] = seen.toList();
  }
}
