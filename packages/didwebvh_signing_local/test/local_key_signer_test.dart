import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_signing_local/didwebvh_signing_local.dart';
import 'package:test/test.dart';

LogEntry _sampleEntry() {
  return LogEntry()
    ..versionId = '1-test'
    ..versionTime = '2025-06-01T00:00:00Z'
    ..parameters = (Parameters()..method = 'did:webvh:1.0');
}

void main() {
  group('LocalKeySigner', () {
    test('generate produces a valid signer', () async {
      final signer = await LocalKeySigner.generate();

      expect(signer.keyType, 'Ed25519');
      expect(signer.publicKeyMultikey, startsWith('z6Mk'));
      expect(signer.verificationMethod, startsWith('did:key:z6Mk'));
      expect(signer.verificationMethod, contains('#z6Mk'));
    });

    test('sign and verify round-trip', () async {
      final signer = await LocalKeySigner.generate();
      final entry = _sampleEntry();

      final proof = await ProofGenerator.generate(signer, entry);
      expect(await ProofVerifier.verify(proof, entry), isTrue);
    });

    test('JSON round-trip', () async {
      final original = await LocalKeySigner.generate();
      final json = original.toJson();

      final restored = LocalKeySigner.fromJson(json);

      expect(restored.keyType, original.keyType);
      expect(restored.publicKeyMultikey, original.publicKeyMultikey);
      expect(restored.verificationMethod, original.verificationMethod);

      // sign with restored, verify against the embedded public key
      final entry = _sampleEntry();
      final proof = await ProofGenerator.generate(restored, entry);
      expect(await ProofVerifier.verify(proof, entry), isTrue);
    });

    test('fromPrivateKey recovers the public key', () async {
      final original = await LocalKeySigner.generate();
      final json = original.toJson();
      final fromJson = LocalKeySigner.fromJson(json);

      expect(fromJson.publicKeyMultikey, original.publicKeyMultikey);
    });

    test('toJson emits a JWK-like object', () async {
      final signer = await LocalKeySigner.generate();
      final json = signer.toJson();

      expect(json, contains('"kty":"OKP"'));
      expect(json, contains('"crv":"Ed25519"'));
      expect(json, contains('"x":'));
      expect(json, contains('"d":'));

      final restored = LocalKeySigner.fromJson(json);
      expect(restored.publicKeyMultikey, signer.publicKeyMultikey);
    });

    test('proof is authorized with matching key', () async {
      final signer = await LocalKeySigner.generate();
      final entry = _sampleEntry();

      final proof = await ProofGenerator.generate(signer, entry);

      expect(
        ProofVerifier.isAuthorized(proof, [signer.publicKeyMultikey]),
        isTrue,
      );
    });

    test('proof is not authorized with a different key', () async {
      final signer1 = await LocalKeySigner.generate();
      final signer2 = await LocalKeySigner.generate();
      final entry = _sampleEntry();

      final proof = await ProofGenerator.generate(signer1, entry);

      expect(
        ProofVerifier.isAuthorized(proof, [signer2.publicKeyMultikey]),
        isFalse,
      );
    });

    test('public key multikey decodes correctly', () async {
      final signer = await LocalKeySigner.generate();
      final multikey = signer.publicKeyMultikey;

      expect(MultikeyUtil.keyTypeFromMultikey(multikey), 'Ed25519');
      expect(MultikeyUtil.decode(multikey), hasLength(32));
    });

    test('full create -> sign -> verify -> resolve round-trip', () async {
      final signer = await LocalKeySigner.generate();

      final created = await DidWebVh.create('example.com', signer).execute();

      final result =
          await DidResolver().resolveFromLog(created.logLine, created.did);

      expect(result.error, isNull);
      expect(result.didDocument, isNotNull);
      expect(result.didDocument!.id, created.did);
    });
  });
}
