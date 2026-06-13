import 'package:didwebvh/src/core/exceptions.dart';

/// Parsed representation of a `did:webvh` DID URL.
///
/// Format: `did:webvh:<SCID>:<domain>[:<path>...][?query][#fragment]`.
///
/// Faithful port of the Java `DidWebVhUrl`.
class DidWebVhUrl {
  DidWebVhUrl._(
    this.scid,
    this.domain,
    List<String> pathSegments,
    this.fragment,
    Map<String, String> queryParams,
  )   : pathSegments = List.unmodifiable(pathSegments),
        queryParams = Map.unmodifiable(queryParams);

  /// Parse a `did:webvh` DID URL string into its components.
  ///
  /// Throws [UrlParseException] if the URL is invalid.
  factory DidWebVhUrl.parse(String? didUrl) {
    if (didUrl == null || didUrl.isEmpty) {
      throw UrlParseException('DID URL must not be null or empty');
    }
    if (!didUrl.startsWith(_didPrefix)) {
      throw UrlParseException(
        "DID URL must start with '$_didPrefix', got: $didUrl",
      );
    }

    var remainder = didUrl.substring(_didPrefix.length);

    // Extract fragment
    String? fragment;
    final hashIdx = remainder.indexOf('#');
    if (hashIdx >= 0) {
      fragment = remainder.substring(hashIdx + 1);
      remainder = remainder.substring(0, hashIdx);
    }

    // Extract query parameters
    final queryParams = <String, String>{};
    final questionIdx = remainder.indexOf('?');
    if (questionIdx >= 0) {
      final queryString = remainder.substring(questionIdx + 1);
      remainder = remainder.substring(0, questionIdx);
      _parseQueryParams(queryString, queryParams);
    }

    // Split remaining into colon-separated segments
    final segments = remainder.split(':');
    if (segments.length < 2) {
      throw UrlParseException(
        'DID URL must contain at least SCID and domain segments, got: $didUrl',
      );
    }

    // First segment is the SCID
    final scid = segments[0];
    _validateScid(scid);

    // Second segment is the domain (may contain %3A for port)
    final domain = segments[1];
    _validateDomain(domain);

    // Remaining segments are path
    final pathSegments = <String>[];
    for (var i = 2; i < segments.length; i++) {
      if (segments[i].isEmpty) {
        throw UrlParseException(
          "Path segments must not be empty (found '::' in DID URL): $didUrl",
        );
      }
      pathSegments.add(segments[i]);
    }

    return DidWebVhUrl._(scid, domain, pathSegments, fragment, queryParams);
  }

  static const String _didPrefix = 'did:webvh:';
  static const int _scidLength = 46;
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// The self-certifying identifier (46 base58btc characters).
  final String scid;

  /// The domain segment (may contain `%3A` for an encoded port).
  final String domain;

  /// The colon-separated path segments following the domain.
  final List<String> pathSegments;

  /// The fragment (after `#`), or `null` if none.
  final String? fragment;

  /// The query parameters (after `?`), in insertion order.
  final Map<String, String> queryParams;

  static void _validateScid(String scid) {
    if (scid.length != _scidLength) {
      throw UrlParseException(
        'SCID must be $_scidLength base58btc characters, got '
        '${scid.length} characters: $scid',
      );
    }
    for (var i = 0; i < scid.length; i++) {
      if (!_base58Alphabet.contains(scid[i])) {
        throw UrlParseException(
          "SCID contains invalid base58btc character '${scid[i]}' "
          'at position $i',
        );
      }
    }
  }

  static void _validateDomain(String domain) {
    if (domain.isEmpty) {
      throw UrlParseException('Domain must not be empty');
    }

    // Domain segment (after splitting by ':') cannot contain a raw colon.
    // Ports are encoded as %3A in the DID string; after splitting they
    // appear inside the domain segment as the literal "%3A" substring.

    // Decode percent-encoded port for validation
    var decoded = domain;
    final hasPercentPort = domain.toLowerCase().contains('%3a');
    if (hasPercentPort) {
      decoded = domain.replaceAll(RegExp('%3A', caseSensitive: false), ':');
    }

    // Extract host part (without port) for validation
    var host = decoded;
    final portIdx = decoded.lastIndexOf(':');
    if (portIdx >= 0 && hasPercentPort) {
      final portStr = decoded.substring(portIdx + 1);
      final port = int.tryParse(portStr);
      if (port == null) {
        throw UrlParseException('Invalid port number in domain: $portStr');
      }
      if (port < 1 || port > 65535) {
        throw UrlParseException('Port must be between 1 and 65535, got: $port');
      }
      host = decoded.substring(0, portIdx);
    }

    // Reject IP addresses (IPv4 and IPv6)
    if (_isIpAddress(host)) {
      throw UrlParseException(
        'Domain must be a DNS name, not an IP address: $host',
      );
    }
  }

  static bool _isIpAddress(String host) {
    // IPv6 in brackets
    if (host.startsWith('[') && host.endsWith(']')) {
      return true;
    }
    // IPv4: all digits and dots, at least one dot
    if (host.contains('.') && RegExp(r'^[0-9.]+$').hasMatch(host)) {
      return true;
    }
    return false;
  }

  static void _parseQueryParams(String query, Map<String, String> params) {
    if (query.isEmpty) {
      return;
    }
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq >= 0) {
        params[pair.substring(0, eq)] = pair.substring(eq + 1);
      } else {
        params[pair] = '';
      }
    }
  }

  /// Returns the decoded domain with port (if present); `%3A` becomes a colon.
  String get decodedDomain =>
      domain.replaceAll(RegExp('%3A', caseSensitive: false), ':');

  /// Returns just the hostname, without port.
  String get host {
    final decoded = decodedDomain;
    final portIdx = decoded.lastIndexOf(':');
    if (portIdx >= 0 && domain.toLowerCase().contains('%3a')) {
      return decoded.substring(0, portIdx);
    }
    return decoded;
  }

  /// Returns the port number, or `-1` if no port is specified.
  int get port {
    final decoded = decodedDomain;
    final portIdx = decoded.lastIndexOf(':');
    if (portIdx >= 0 && domain.toLowerCase().contains('%3a')) {
      return int.parse(decoded.substring(portIdx + 1));
    }
    return -1;
  }

  /// Reconstructs the DID string (including query and fragment).
  @override
  String toString() {
    final sb = StringBuffer(_didPrefix)
      ..write(scid)
      ..write(':')
      ..write(domain);
    for (final seg in pathSegments) {
      sb
        ..write(':')
        ..write(seg);
    }
    if (queryParams.isNotEmpty) {
      sb.write('?');
      var first = true;
      queryParams.forEach((key, value) {
        if (!first) {
          sb.write('&');
        }
        sb.write(key);
        if (value.isNotEmpty) {
          sb
            ..write('=')
            ..write(value);
        }
        first = false;
      });
    }
    if (fragment != null) {
      sb
        ..write('#')
        ..write(fragment);
    }
    return sb.toString();
  }

  /// Returns the base DID string (without query parameters and fragment).
  String toBaseDid() {
    final sb = StringBuffer(_didPrefix)
      ..write(scid)
      ..write(':')
      ..write(domain);
    for (final seg in pathSegments) {
      sb
        ..write(':')
        ..write(seg);
    }
    return sb.toString();
  }
}
