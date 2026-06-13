import 'package:didwebvh_core/src/url/did_to_https_transformer.dart';
import 'package:test/test.dart';

void main() {
  // A valid 46-character base58btc SCID for testing.
  const scid = 'QmfGEUAcMpzo25kF2Rhn8L2qMSAzMGeyq8kJEMabAxQzK3';

  group('toHttpsUrl — spec examples (section 3.4)', () {
    test('domainOnly', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl('did:webvh:$scid:example.com'),
        'https://example.com/.well-known/did.jsonl',
      );
    });

    test('subdomain', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl('did:webvh:$scid:issuer.example.com'),
        'https://issuer.example.com/.well-known/did.jsonl',
      );
    });

    test('domainWithPath', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl(
          'did:webvh:$scid:example.com:dids:issuer',
        ),
        'https://example.com/dids/issuer/did.jsonl',
      );
    });

    test('domainWithPortAndPath', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl(
          'did:webvh:$scid:example.com%3A3000:dids:issuer',
        ),
        'https://example.com:3000/dids/issuer/did.jsonl',
      );
    });

    test('domainWithPortNoPath', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl('did:webvh:$scid:example.com%3A8080'),
        'https://example.com:8080/.well-known/did.jsonl',
      );
    });
  });

  group('toWitnessUrl', () {
    test('witnessUrlDomainOnly', () {
      expect(
        DidToHttpsTransformer.toWitnessUrl('did:webvh:$scid:example.com'),
        'https://example.com/.well-known/did-witness.json',
      );
    });

    test('witnessUrlWithPath', () {
      expect(
        DidToHttpsTransformer.toWitnessUrl(
          'did:webvh:$scid:example.com:dids:issuer',
        ),
        'https://example.com/dids/issuer/did-witness.json',
      );
    });

    test('witnessUrlWithPortAndPath', () {
      expect(
        DidToHttpsTransformer.toWitnessUrl(
          'did:webvh:$scid:example.com%3A3000:dids:issuer',
        ),
        'https://example.com:3000/dids/issuer/did-witness.json',
      );
    });
  });

  group('toDidWebUrl', () {
    test('toDidWebSimple', () {
      expect(
        DidToHttpsTransformer.toDidWebUrl('did:webvh:$scid:example.com'),
        'did:web:example.com',
      );
    });

    test('toDidWebWithPath', () {
      expect(
        DidToHttpsTransformer.toDidWebUrl(
          'did:webvh:$scid:example.com:dids:issuer',
        ),
        'did:web:example.com:dids:issuer',
      );
    });

    test('toDidWebWithPort', () {
      expect(
        DidToHttpsTransformer.toDidWebUrl(
          'did:webvh:$scid:example.com%3A3000:dids:issuer',
        ),
        'did:web:example.com%3A3000:dids:issuer',
      );
    });
  });

  group('path & query/fragment handling', () {
    test('pathSegmentsArePercentEncoded', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl(
          'did:webvh:$scid:example.com:simple:path',
        ),
        'https://example.com/simple/path/did.jsonl',
      );
    });

    test('queryParamsIgnoredInUrlConstruction', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl(
          'did:webvh:$scid:example.com?versionId=1-abc',
        ),
        'https://example.com/.well-known/did.jsonl',
      );
    });

    test('fragmentIgnoredInUrlConstruction', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl('did:webvh:$scid:example.com#key-1'),
        'https://example.com/.well-known/did.jsonl',
      );
    });
  });

  group('IDNA / Punycode', () {
    test('punycodeEncoding (already-ASCII passthrough)', () {
      expect(
        DidToHttpsTransformer.toHttpsUrl(
          'did:webvh:$scid:xn--example-cua.com',
        ),
        'https://xn--example-cua.com/.well-known/did.jsonl',
      );
    });
  });
}
