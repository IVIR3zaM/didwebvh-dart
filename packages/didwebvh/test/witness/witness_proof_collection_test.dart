import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

/// Port of Java `WitnessProofCollectionTest`.
void main() {
  test('serializesWitnessConfigShape', () {
    final wc = WitnessConfig(2, const [
      WitnessEntry('did:key:z6Mk1'),
      WitnessEntry('did:key:z6Mk2'),
    ]);
    final json = jsonEncode(wc.toJson());
    expect(
      json,
      '{"threshold":2,"witnesses":[{"id":"did:key:z6Mk1"},'
      '{"id":"did:key:z6Mk2"}]}',
    );
    expect(
      WitnessConfig.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      ),
      wc,
    );
  });

  test('proofCollectionRoundTrip', () {
    final proof = DataIntegrityProof.defaults()
      ..verificationMethod = 'did:key:z6Mk1#z6Mk1'
      ..proofValue = 'zSig';
    final coll = WitnessProofCollection([
      WitnessProofEntry.of('1-QmHash', [proof]),
    ]);
    final json = jsonEncode(coll.toJson(omitNull: true));
    final decoded = WitnessProofCollection.fromJson(
      (jsonDecode(json) as Map).cast<String, Object?>(),
    );
    expect(decoded, coll);
    expect(decoded.entries, hasLength(1));
    expect(decoded.entries[0].versionId, '1-QmHash');
  });
}
