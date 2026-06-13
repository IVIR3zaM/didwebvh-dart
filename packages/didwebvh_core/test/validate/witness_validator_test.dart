import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:test/test.dart';

import 'validation_test_helpers.dart';

/// Port of Java `WitnessValidatorTest`.
void main() {
  late Signer authorSigner;
  late Signer witnessSigner1;
  late Signer witnessSigner2;
  late String witnessDid1;
  late String witnessDid2;
  final validator = WitnessValidator();

  setUpAll(() async {
    authorSigner = await makeTestSigner();
    witnessSigner1 = await makeTestSigner();
    witnessSigner2 = await makeTestSigner();
    witnessDid1 =
        'did:key:${extractMultikey(witnessSigner1.verificationMethod)}';
    witnessDid2 =
        'did:key:${extractMultikey(witnessSigner2.verificationMethod)}';
  });

  Future<WitnessProofEntry> makeProofEntry(
    String versionId,
    List<Signer> signers,
  ) async {
    final doc = <String, Object?>{'versionId': versionId};
    final proofs = [for (final s in signers) await signDocument(s, doc)];
    return WitnessProofEntry.of(versionId, proofs);
  }

  Future<WitnessProofCollection> makeWitnessProofs(
    String versionId,
    List<Signer> signers,
  ) async {
    return WitnessProofCollection([await makeProofEntry(versionId, signers)]);
  }

  Future<CreateDidResult> createWithWitness(
    int threshold,
    List<WitnessEntry> witnesses,
  ) {
    final wc = WitnessConfig(threshold, witnesses);
    return DidWebVh.create('example.com', authorSigner).witness(wc).execute();
  }

  test('validSingleWitnessProof', () async {
    final create = await createWithWitness(1, [WitnessEntry(witnessDid1)]);
    final entry = create.logEntry;

    final proofs = await makeWitnessProofs(entry.versionId!, [witnessSigner1]);
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isTrue);
  });

  test('validTwoOfTwoWitnessProofs', () async {
    final create = await createWithWitness(
      2,
      [WitnessEntry(witnessDid1), WitnessEntry(witnessDid2)],
    );
    final entry = create.logEntry;

    final proofs = await makeWitnessProofs(
      entry.versionId!,
      [witnessSigner1, witnessSigner2],
    );
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isTrue);
  });

  test('validOneOfTwoThresholdProofs', () async {
    final create = await createWithWitness(
      1,
      [WitnessEntry(witnessDid1), WitnessEntry(witnessDid2)],
    );
    final entry = create.logEntry;

    final proofs = await makeWitnessProofs(entry.versionId!, [witnessSigner1]);
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isTrue);
  });

  test('insufficientWitnessProofsFails', () async {
    final create = await createWithWitness(
      2,
      [WitnessEntry(witnessDid1), WitnessEntry(witnessDid2)],
    );
    final entry = create.logEntry;

    final proofs = await makeWitnessProofs(entry.versionId!, [witnessSigner1]);
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isFalse);
    expect(result.failedEntryIndex, 0);
    expect(result.failureReason, contains('insufficient'));
  });

  test('missingWitnessProofEntryFails', () async {
    final create = await createWithWitness(1, [WitnessEntry(witnessDid1)]);
    final entry = create.logEntry;

    final proofs = await makeWitnessProofs('99-wronghash', [witnessSigner1]);
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isFalse);
    expect(result.failureReason, contains('insufficient witness proofs'));
  });

  test('unknownWitnessProofIgnored', () async {
    final create = await createWithWitness(1, [WitnessEntry(witnessDid1)]);
    final entry = create.logEntry;

    final stranger = await makeTestSigner();
    final proofs = await makeWitnessProofs(entry.versionId!, [stranger]);
    final result = await validator.validate([entry], proofs, 0);

    expect(result.valid, isFalse);
    expect(result.failureReason, contains('insufficient'));
  });

  test('nullWitnessProofCollectionFails', () async {
    final create = await createWithWitness(1, [WitnessEntry(witnessDid1)]);
    final result = await validator.validate([create.logEntry], null, 0);

    expect(result.valid, isFalse);
    expect(result.failureReason, contains('null'));
  });

  test('noWitnessConfigSkipsValidation', () async {
    final create = await DidWebVh.create('example.com', authorSigner).execute();
    final result = await validator.validate(
      [create.logEntry],
      WitnessProofCollection(const []),
      0,
    );

    expect(result.valid, isTrue);
  });

  test('crossDidWitnessReplayRejected', () async {
    final wc = WitnessConfig(1, [WitnessEntry(witnessDid1)]);
    final create = await DidWebVh.create('example.com', authorSigner)
        .witness(wc)
        .execute();
    final e1 = create.logEntry;

    final witnessOff = Parameters()..witness = WitnessConfig.empty();
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      authorSigner,
      changedParams: witnessOff,
    );

    final foreignProofs = await makeWitnessProofs(
      '3-zForeignDidEntryHashThatDoesNotExistInThisLog',
      [witnessSigner1],
    );

    final result = await validator.validate([e1, e2], foreignProofs, 0);

    expect(result.valid, isFalse);
    expect(result.failureReason, contains('insufficient witness proofs'));
  });

  test('witnessListReductionStillRequiresPriorList', () async {
    final create = await createWithWitness(
      2,
      [WitnessEntry(witnessDid1), WitnessEntry(witnessDid2)],
    );
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      authorSigner,
      changedParams: Parameters()
        ..witness = WitnessConfig(1, [WitnessEntry(witnessDid1)]),
    );

    final proofs = WitnessProofCollection([
      await makeProofEntry(e2.versionId!, [witnessSigner1, witnessSigner2]),
    ]);

    final result = await validator.validate([e1, e2], proofs, 0);
    expect(result.valid, isTrue);
  });

  test('witnessListReductionWithOnlyNewListFails', () async {
    final create = await createWithWitness(
      2,
      [WitnessEntry(witnessDid1), WitnessEntry(witnessDid2)],
    );
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      authorSigner,
      changedParams: Parameters()
        ..witness = WitnessConfig(1, [WitnessEntry(witnessDid1)]),
    );

    final proofs = WitnessProofCollection([
      await makeProofEntry(e2.versionId!, [witnessSigner1]),
    ]);

    final result = await validator.validate([e1, e2], proofs, 0);
    expect(result.valid, isFalse);
    expect(result.failureReason, contains('insufficient'));
  });

  test('fromEntryIndexRespected', () async {
    final create = await DidWebVh.create('example.com', authorSigner).execute();
    final e1 = create.logEntry;

    final wc = WitnessConfig(1, [WitnessEntry(witnessDid1)]);
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      authorSigner,
      changedParams: Parameters()..witness = wc,
    );

    final proofs = await makeWitnessProofs(e2.versionId!, [witnessSigner1]);

    final result = await validator.validate([e1, e2], proofs, 1);
    expect(result.valid, isTrue);
  });
}
