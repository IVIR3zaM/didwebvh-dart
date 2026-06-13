import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/url/did_webvh_url.dart';
import 'package:test/test.dart';

void main() {
  // A valid 46-character base58btc SCID for testing.
  const scid = 'QmfGEUAcMpzo25kF2Rhn8L2qMSAzMGeyq8kJEMabAxQzK3';

  group('DidWebVhUrl.parse', () {
    test('parseSimpleDomain', () {
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com');

      expect(url.scid, scid);
      expect(url.domain, 'example.com');
      expect(url.host, 'example.com');
      expect(url.port, -1);
      expect(url.pathSegments, isEmpty);
      expect(url.fragment, isNull);
      expect(url.queryParams, isEmpty);
    });

    test('parseSubdomain', () {
      final url = DidWebVhUrl.parse('did:webvh:$scid:issuer.example.com');

      expect(url.domain, 'issuer.example.com');
      expect(url.host, 'issuer.example.com');
      expect(url.pathSegments, isEmpty);
    });

    test('parseWithPath', () {
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com:dids:issuer');

      expect(url.domain, 'example.com');
      expect(url.pathSegments, ['dids', 'issuer']);
    });

    test('parseWithPercentEncodedPort', () {
      final url =
          DidWebVhUrl.parse('did:webvh:$scid:example.com%3A3000:dids:issuer');

      expect(url.domain, 'example.com%3A3000');
      expect(url.decodedDomain, 'example.com:3000');
      expect(url.host, 'example.com');
      expect(url.port, 3000);
      expect(url.pathSegments, ['dids', 'issuer']);
    });

    test('parseWithPortNoPath', () {
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com%3A8080');

      expect(url.host, 'example.com');
      expect(url.port, 8080);
      expect(url.pathSegments, isEmpty);
    });

    test('parseWithFragment', () {
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com#key-1');

      expect(url.domain, 'example.com');
      expect(url.fragment, 'key-1');
    });

    test('parseWithQueryParams', () {
      final url = DidWebVhUrl.parse(
        'did:webvh:$scid:example.com?versionId=1-abc&versionTime=2024-01-01',
      );

      expect(url.queryParams['versionId'], '1-abc');
      expect(url.queryParams['versionTime'], '2024-01-01');
    });

    test('parseWithQueryAndFragment', () {
      final url = DidWebVhUrl.parse(
        'did:webvh:$scid:example.com:path?versionNumber=2#key-1',
      );

      expect(url.pathSegments, ['path']);
      expect(url.queryParams['versionNumber'], '2');
      expect(url.fragment, 'key-1');
    });

    test('toStringRoundTrip', () {
      const did = 'did:webvh:$scid:example.com%3A3000:dids:issuer';
      final url = DidWebVhUrl.parse(did);
      expect(url.toString(), did);
    });

    test('toStringRoundTripWithQueryAndFragment', () {
      const did = 'did:webvh:$scid:example.com:path?versionId=1-abc#key-1';
      final url = DidWebVhUrl.parse(did);
      expect(url.toString(), did);
    });

    test('toBaseDidStripsQueryAndFragment', () {
      final url = DidWebVhUrl.parse(
        'did:webvh:$scid:example.com:path?versionId=1#key-1',
      );
      expect(url.toBaseDid(), 'did:webvh:$scid:example.com:path');
    });
  });

  group('DidWebVhUrl.parse — invalid', () {
    test('rejectNull', () {
      expect(
        () => DidWebVhUrl.parse(null),
        throwsA(isA<UrlParseException>()),
      );
    });

    test('rejectEmpty', () {
      expect(
        () => DidWebVhUrl.parse(''),
        throwsA(isA<UrlParseException>()),
      );
    });

    test('rejectWrongPrefix', () {
      expect(
        () => DidWebVhUrl.parse('did:web:$scid:example.com'),
        throwsA(
          isA<UrlParseException>().having(
            (e) => e.message,
            'message',
            contains('did:webvh:'),
          ),
        ),
      );
    });

    test('rejectShortScid', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:abc:example.com'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('46')),
        ),
      );
    });

    test('rejectScidWithInvalidChars', () {
      // 'l' (lowercase L) is not in the base58btc alphabet.
      const badScid = 'Al1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1';
      expect(
        () => DidWebVhUrl.parse('did:webvh:$badScid:example.com'),
        throwsA(
          isA<UrlParseException>().having(
            (e) => e.message,
            'message',
            contains('invalid base58btc character'),
          ),
        ),
      );
    });

    test('rejectIpAddress', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid:192.168.1.1'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('IP address')),
        ),
      );
    });

    test('rawColonParsesAsPath', () {
      // Raw colon is the path separator — "3000" becomes a path segment.
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com:3000');
      expect(url.domain, 'example.com');
      expect(url.port, -1);
      expect(url.pathSegments, ['3000']);
    });

    test('rejectEmptyPathSegment', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid:example.com::issuer'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('empty')),
        ),
      );
    });

    test('rejectMissingDomain', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid'),
        throwsA(
          isA<UrlParseException>().having(
            (e) => e.message,
            'message',
            contains('at least SCID and domain'),
          ),
        ),
      );
    });

    test('rejectEmptyDomain', () {
      // SCID followed by an empty domain segment.
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid::path'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('Domain')),
        ),
      );
    });

    test('rejectPortOutOfRange', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid:example.com%3A99999'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('Port')),
        ),
      );
    });

    test('rejectNonNumericPort', () {
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid:example.com%3Aabc'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('port')),
        ),
      );
    });

    test('rejectIpv6BracketedAddress', () {
      // Bracketed host triggers the IPv6 branch.
      expect(
        () => DidWebVhUrl.parse('did:webvh:$scid:[host]'),
        throwsA(
          isA<UrlParseException>()
              .having((e) => e.message, 'message', contains('IP address')),
        ),
      );
    });

    test('queryParamWithoutEqualsStoredWithEmptyValue', () {
      final url = DidWebVhUrl.parse(
        'did:webvh:$scid:example.com?flag&versionNumber=2',
      );
      expect(url.queryParams['flag'], '');
      expect(url.queryParams['versionNumber'], '2');
    });

    test('toStringRoundTripsMultipleQueryParams', () {
      const input =
          'did:webvh:$scid:example.com?versionNumber=2&versionId=2-Qmabc';
      final url = DidWebVhUrl.parse(input);
      expect(url.toString(), contains('&'));
      expect(url.toString(), contains('versionNumber=2'));
      expect(url.toString(), contains('versionId=2-Qmabc'));
    });

    test('caseInsensitivePercentEncoding', () {
      // %3a (lowercase) should also work.
      final url = DidWebVhUrl.parse('did:webvh:$scid:example.com%3a443');
      expect(url.port, 443);
      expect(url.host, 'example.com');
    });
  });
}
