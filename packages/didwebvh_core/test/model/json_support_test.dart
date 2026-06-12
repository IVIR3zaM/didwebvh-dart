import 'package:didwebvh_core/src/model/data_integrity_proof.dart';
import 'package:didwebvh_core/src/model/json_support.dart';
import 'package:test/test.dart';

void main() {
  group('JsonSupport', () {
    test('gson() keeps explicit null fields; compact() omits them', () {
      final proof = DataIntegrityProof()
        ..type = 'DataIntegrityProof'
        ..proofValue = 'zSig';

      // Keep-null (≈ serializeNulls): every field present, nulls written.
      expect(
        JsonSupport.gson(proof),
        '{"type":"DataIntegrityProof","cryptosuite":null,'
        '"verificationMethod":null,"proofPurpose":null,"created":null,'
        '"proofValue":"zSig"}',
      );

      // Omit-null (canonical log line shape).
      expect(
        JsonSupport.compact(proof),
        '{"type":"DataIntegrityProof","proofValue":"zSig"}',
      );
    });

    test('DataIntegrityProof.defaults populates the spec defaults', () {
      final p = DataIntegrityProof.defaults();
      expect(p.type, DataIntegrityProof.defaultType);
      expect(p.cryptosuite, DataIntegrityProof.defaultCryptosuite);
      expect(p.proofPurpose, DataIntegrityProof.defaultProofPurpose);
      expect(p.verificationMethod, isNull);
    });

    test('DataIntegrityProof value equality and hashCode', () {
      final a = DataIntegrityProof.defaults()..proofValue = 'z1';
      final b = DataIntegrityProof.defaults()..proofValue = 'z1';
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      b.proofValue = 'z2';
      expect(a, isNot(b));
    });
  });
}
