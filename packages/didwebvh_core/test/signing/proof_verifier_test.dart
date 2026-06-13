import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:test/test.dart';

import 'test_signer.dart';

void main() {
  group('ProofVerifier', () {
    late TestSigner signer;

    setUpAll(() async {
      signer = await TestSigner.generate();
    });

    Future<DataIntegrityProof> signDocument(Map<String, Object?> doc) async {
      final proof = DataIntegrityProof.defaults()
        ..verificationMethod = signer.verificationMethod
        ..created = DateTime.now().toUtc().toIso8601String();
      final hashData = ProofGenerator.buildHashData(proof, doc);
      proof.proofValue = Base58Btc.encodeMultibase(await signer.sign(hashData));
      return proof;
    }

    test('isAuthorized with matching key', () {
      final proof = DataIntegrityProof.defaults()
        ..verificationMethod = 'did:key:z6MkKey1#z6MkKey1';

      expect(
        ProofVerifier.isAuthorized(proof, ['z6MkKey1', 'z6MkKey2']),
        isTrue,
      );
    });

    test('isAuthorized rejects non-matching key', () {
      final proof = DataIntegrityProof.defaults()
        ..verificationMethod = 'did:key:z6MkKeyX#z6MkKeyX';

      expect(
        ProofVerifier.isAuthorized(proof, ['z6MkKey1', 'z6MkKey2']),
        isFalse,
      );
    });

    test('isAuthorized rejects empty key list', () {
      final proof = DataIntegrityProof.defaults()
        ..verificationMethod = 'did:key:z6MkKey1#z6MkKey1';

      expect(ProofVerifier.isAuthorized(proof, const []), isFalse);
    });

    test('extractMultikey from fragment', () {
      expect(
        ProofVerifier.extractMultikey('did:key:z6Mk123#z6Mk123'),
        'z6Mk123',
      );
    });

    test('extractMultikey from did:key without fragment', () {
      expect(ProofVerifier.extractMultikey('did:key:z6Mk456'), 'z6Mk456');
    });

    test('extractMultikey throws on null', () {
      expect(
        () => ProofVerifier.extractMultikey(null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('extractMultikey throws on invalid format', () {
      expect(
        () => ProofVerifier.extractMultikey('invalid'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('verifyDocument accepts a valid signature', () async {
      final doc = <String, Object?>{'versionId': '1-abc'};
      final proof = await signDocument(doc);

      expect(await ProofVerifier.verifyDocument(proof, doc), isTrue);
    });

    test('verifyDocument rejects a tampered document', () async {
      final doc = <String, Object?>{'versionId': '1-abc'};
      final proof = await signDocument(doc);

      final tampered = <String, Object?>{'versionId': '2-different'};

      expect(await ProofVerifier.verifyDocument(proof, tampered), isFalse);
    });

    test('verifyDocument rejects a tampered proofValue', () async {
      final doc = <String, Object?>{'versionId': '1-abc'};
      final proof = await signDocument(doc);

      // Replace proofValue with a signature over different data.
      final wrong = await signer.sign(Uint8List.fromList(utf8.encode('WRONG')));
      final badProof = DataIntegrityProof.defaults()
        ..verificationMethod = proof.verificationMethod
        ..created = proof.created
        ..proofValue = Base58Btc.encodeMultibase(wrong);

      expect(await ProofVerifier.verifyDocument(badProof, doc), isFalse);
    });
  });
}
