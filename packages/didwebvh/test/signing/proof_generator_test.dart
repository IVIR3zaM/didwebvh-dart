import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import 'test_signer.dart';

void main() {
  group('ProofGenerator', () {
    late TestSigner testSigner;

    setUpAll(() async {
      testSigner = await TestSigner.generate();
    });

    LogEntry sampleEntry() => LogEntry()
      ..versionId = '1-abc'
      ..versionTime = '2025-01-01T00:00:00Z'
      ..parameters = (Parameters()..method = 'did:webvh:1.0');

    test('generate produces a valid structure', () async {
      final entry = sampleEntry();

      final proof = await ProofGenerator.generate(testSigner, entry);

      expect(proof.type, DataIntegrityProof.defaultType);
      expect(proof.cryptosuite, DataIntegrityProof.defaultCryptosuite);
      expect(proof.proofPurpose, DataIntegrityProof.defaultProofPurpose);
      expect(proof.verificationMethod, testSigner.verificationMethod);
      expect(proof.created, isNotNull);
      expect(proof.proofValue, startsWith('z'));
    });

    test('generated proof verifies', () async {
      final entry = sampleEntry();

      final proof = await ProofGenerator.generate(testSigner, entry);

      expect(await ProofVerifier.verify(proof, entry), isTrue);
    });

    test('tampered data fails verification', () async {
      final entry = sampleEntry();

      final proof = await ProofGenerator.generate(testSigner, entry);

      final tampered = sampleEntry()..versionId = '2-xyz';

      expect(await ProofVerifier.verify(proof, tampered), isFalse);
    });

    test('tampered proofValue fails verification', () async {
      final entry = sampleEntry();

      final proof = await ProofGenerator.generate(testSigner, entry);

      // decode, flip a byte, re-encode
      final sig = Base58Btc.decodeMultibase(proof.proofValue!);
      sig[0] ^= 0xFF;
      proof.proofValue = Base58Btc.encodeMultibase(sig);

      expect(await ProofVerifier.verify(proof, entry), isFalse);
    });
  });
}
