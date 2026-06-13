import 'package:didwebvh/src/url/did_to_https_transformer.dart';

/// Adds the implicit `#files` and `#whois` services defined for `did:webvh`
/// by spec §3.8 and §3.9 to a DID Document.
///
/// These services are defined by the method itself and MUST be present in the
/// resolved DID Document unless the controller has overridden them by declaring
/// services with the same id (or fragment) explicitly.
///
/// Faithful port of Java `didweb/ImplicitServices`. Only [addTo] (the surface
/// the resolver needs) is ported here as a minimal dependency for iteration 9;
/// the full `didweb/` package lands in iteration 11.
abstract final class ImplicitServices {
  static const String _filesId = '#files';
  static const String _whoisId = '#whois';
  static const String _wellKnownSegment = '/.well-known/';
  static const String _didLogFilename = 'did.jsonl';
  static const String _whoisFilename = 'whois.vp';

  /// Mutates [doc] in place, appending the implicit `#files` and `#whois`
  /// services if not already present (compared by service fragment, either as
  /// a bare fragment or a fully qualified id).
  ///
  /// [did] is the DID string used to construct fully-qualified service ids.
  static void addTo(Map<String, Object?> doc, String? did) {
    if (did == null || did.isEmpty) {
      return;
    }
    final httpsBase = _httpsBase(did);

    final List<Object?> services;
    final existing = doc['service'];
    if (existing is List) {
      services = existing;
    } else {
      services = <Object?>[];
      doc['service'] = services;
    }

    if (!_hasServiceWithId(services, did, _filesId)) {
      services.add(<String, Object?>{
        'id': '$did$_filesId',
        'type': 'relativeRef',
        'serviceEndpoint': httpsBase,
      });
    }

    if (!_hasServiceWithId(services, did, _whoisId)) {
      services.add(<String, Object?>{
        '@context': 'https://identity.foundation/linked-vp/contexts/v1',
        'id': '$did$_whoisId',
        'type': 'LinkedVerifiablePresentation',
        'serviceEndpoint': '$httpsBase$_whoisFilename',
      });
    }
  }

  /// Computes the HTTPS base URL for implicit service endpoints: the
  /// DID-to-HTTPS URL with the trailing `did.jsonl` filename removed and any
  /// `.well-known/` segment stripped.
  static String _httpsBase(String did) {
    final didLogUrl = DidToHttpsTransformer.toHttpsUrl(did);
    var base =
        didLogUrl.substring(0, didLogUrl.length - _didLogFilename.length);
    final idx = base.indexOf(_wellKnownSegment);
    if (idx >= 0) {
      base = base.substring(0, idx + 1) +
          base.substring(idx + _wellKnownSegment.length);
    }
    return base;
  }

  static bool _hasServiceWithId(
    List<Object?> services,
    String did,
    String fragment,
  ) {
    final absolute = '$did$fragment';
    for (final el in services) {
      if (el is! Map) {
        continue;
      }
      final id = el['id'];
      if (id is! String) {
        continue;
      }
      if (fragment == id || absolute == id) {
        return true;
      }
    }
    return false;
  }
}
