import 'dart:convert';

import 'package:didwebvh_core/src/url/did_webvh_url.dart';
import 'package:punycode/punycode.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Transforms `did:webvh` DIDs to HTTPS URLs per spec section 3.4.
///
/// Faithful port of the Java `DidToHttpsTransformer`.
class DidToHttpsTransformer {
  DidToHttpsTransformer._();

  static const String _didLogFile = 'did.jsonl';
  static const String _witnessFile = 'did-witness.json';
  static const String _wellKnown = '.well-known';

  /// Transform a `did:webvh` DID to the HTTPS URL of its DID Log file
  /// (`did.jsonl`).
  static String toHttpsUrl(String did) => _buildUrl(did, _didLogFile);

  /// Transform a `did:webvh` DID to the HTTPS URL of its witness proof file
  /// (`did-witness.json`).
  static String toWitnessUrl(String did) => _buildUrl(did, _witnessFile);

  /// Convert a `did:webvh` DID to the equivalent `did:web` DID.
  ///
  /// The SCID segment is removed and the method name changes from `webvh` to
  /// `web`. All other segments remain the same.
  static String toDidWebUrl(String didWebVh) {
    final parsed = DidWebVhUrl.parse(didWebVh);

    final sb = StringBuffer('did:web:')..write(parsed.domain);
    for (final seg in parsed.pathSegments) {
      sb
        ..write(':')
        ..write(seg);
    }
    return sb.toString();
  }

  static String _buildUrl(String did, String filename) {
    final parsed = DidWebVhUrl.parse(did);

    // Step 3: Transform domain segment
    var host = parsed.host;
    final port = parsed.port;

    // Apply Unicode normalization (NFC) and IDNA/Punycode
    host = unorm.nfc(host);
    host = _idnaToAscii(host);

    // Step 4: Transform path segments
    final pathSegments = parsed.pathSegments;

    // Step 5: Reconstruct HTTPS URL
    final url = StringBuffer('https://')..write(host);
    if (port > 0) {
      url
        ..write(':')
        ..write(port);
    }
    url.write('/');

    if (pathSegments.isEmpty) {
      url
        ..write(_wellKnown)
        ..write('/')
        ..write(filename);
    } else {
      for (var i = 0; i < pathSegments.length; i++) {
        if (i > 0) {
          url.write('/');
        }
        url.write(percentEncode(pathSegments[i]));
      }
      url
        ..write('/')
        ..write(filename);
    }

    return url.toString();
  }

  /// Convert a (NFC-normalized) host to its ASCII (Punycode) form, mirroring
  /// Java's `IDN.toASCII(host, ALLOW_UNASSIGNED)`.
  ///
  /// Per RFC 3490 ToASCII, all-ASCII labels pass through unchanged (no
  /// nameprep, no case-folding). Labels containing non-ASCII code points are
  /// nameprepped (approximated here as NFKC + lowercase, the IDNA2003
  /// stringprep mapping) and Punycode-encoded with the `xn--` ACE prefix.
  static String _idnaToAscii(String host) {
    // IDNA label separators: U+002E, U+3002, U+FF0E, U+FF61.
    final labels = host.split(RegExp('[.。．｡]'));
    return labels.map(_labelToAscii).join('.');
  }

  static String _labelToAscii(String label) {
    if (_isAllAscii(label)) {
      return label;
    }
    final prepped = unorm.nfkc(label).toLowerCase();
    return 'xn--${punycodeEncode(prepped)}';
  }

  static bool _isAllAscii(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) >= 0x80) {
        return false;
      }
    }
    return true;
  }

  /// Percent-encode a path segment per RFC 3986.
  ///
  /// Unreserved characters (ALPHA / DIGIT / "-" / "." / "_" / "~") are not
  /// encoded.
  static String percentEncode(String segment) {
    final sb = StringBuffer();
    final bytes = utf8.encode(segment);
    for (final b in bytes) {
      final c = b & 0xFF;
      if (_isUnreserved(c)) {
        sb.writeCharCode(c);
      } else {
        sb
          ..write('%')
          ..write(c.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return sb.toString();
  }

  static bool _isUnreserved(int c) {
    return (c >= 0x41 && c <= 0x5A) // A-Z
        || (c >= 0x61 && c <= 0x7A) // a-z
        || (c >= 0x30 && c <= 0x39) // 0-9
        || c == 0x2D // -
        || c == 0x2E // .
        || c == 0x5F // _
        || c == 0x7E; // ~
  }
}
