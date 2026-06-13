import 'dart:convert';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_core/src/crypto/entry_hash_generator.dart';
import 'package:test/test.dart';

import 'validation_test_helpers.dart';

/// Port of Java `LogChainValidatorTest`.
void main() {
  late Signer signer;
  final validator = LogChainValidator();

  setUpAll(() async {
    signer = await makeTestSigner();
  });

  /// Build a real next entry whose versionTime is the given string.
  Future<LogEntry> buildEntryWithVersionTime(
    LogEntry previous,
    String versionTime,
    int newVersion,
  ) async {
    final preliminary = LogEntry()
      ..versionId = previous.versionId
      ..versionTime = versionTime
      ..parameters = Parameters()
      ..state = deepCopyState(previous.state!);
    final entryHash = EntryHashGenerator.generate(
      preliminary.toJsonLine(),
      previous.versionId!,
    );
    preliminary.versionId = '$newVersion-$entryHash';
    final proof = await ProofGenerator.generate(signer, preliminary);
    return preliminary..proof = [proof];
  }

  test('singleEntryValid', () async {
    final result = await DidWebVh.create('example.com', signer).execute();
    final entries = [result.logEntry];

    final vr = await validator.validate(entries, result.did);

    expect(vr.valid, isTrue);
    expect(vr.lastValidEntryIndex, 0);
    expect(vr.failureReason, isNull);
  });

  test('multiEntryValid', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;

    final state2 = deepCopyState(e1.state!)..['updated'] = 'true';
    final e2 = await buildUpdateEntry(e1, create.did, signer, newState: state2);

    final state3 = deepCopyState(state2)..['updated2'] = 'true';
    final e3 = await buildUpdateEntry(e2, create.did, signer, newState: state3);

    final vr = await validator.validate([e1, e2, e3], create.did);

    expect(vr.valid, isTrue);
    expect(vr.lastValidEntryIndex, 2);
  });

  test('tamperedEntryHashFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(e1, create.did, signer);

    final tamperedState = deepCopyState(e2.state!)..['attacker'] = 'was here';
    final tampered = LogEntry()
      ..versionId = e2.versionId
      ..versionTime = e2.versionTime
      ..parameters = e2.parameters
      ..state = tamperedState
      ..proof = e2.proof;

    final vr = await validator.validate([e1, tampered], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failedEntryIndex, 1);
    expect(vr.lastValidEntryIndex, 0);
    expect(vr.failureReason, contains('entry hash'));
  });

  test('tamperedProofFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(e1, create.did, signer);

    final wrongSig = await signer.sign(utf8.encode('WRONG_DATA'));
    final wrongProofValue = Base58Btc.encodeMultibase(wrongSig);

    final originalProof = e2.proof![0];
    final badProof = DataIntegrityProof()
      ..type = originalProof.type
      ..cryptosuite = originalProof.cryptosuite
      ..verificationMethod = originalProof.verificationMethod
      ..proofPurpose = originalProof.proofPurpose
      ..created = originalProof.created
      ..proofValue = wrongProofValue;

    final tampered = LogEntry()
      ..versionId = e2.versionId
      ..versionTime = e2.versionTime
      ..parameters = e2.parameters
      ..state = e2.state
      ..proof = [badProof];

    final vr = await validator.validate([e1, tampered], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failedEntryIndex, 1);
    expect(vr.failureReason!.toLowerCase(), contains('proof'));
  });

  test('wrongSigningKeyFails', () async {
    final unauthorizedSigner = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;

    final e2 = await buildUpdateEntry(e1, create.did, unauthorizedSigner);

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failedEntryIndex, 1);
    expect(vr.lastValidEntryIndex, 0);
    expect(vr.failureReason, contains('updateKeys'));
  });

  test('versionNumberGapFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(e1, create.did, signer);

    final fakeVersionId = '3-${e2.entryHash}';
    final e2bad = LogEntry()
      ..versionId = fakeVersionId
      ..versionTime = e2.versionTime
      ..parameters = e2.parameters
      ..state = e2.state
      ..proof = e2.proof;

    final vr = await validator.validate([e1, e2bad], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failedEntryIndex, 1);
    expect(vr.failureReason, contains('versionNumber'));
  });

  test('versionTimeOrderingFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;

    final oldTime = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 3600))
        .toIso8601String();
    final preliminary = LogEntry()
      ..versionId = e1.versionId
      ..versionTime = oldTime
      ..parameters = Parameters()
      ..state = deepCopyState(e1.state!);
    final entryHash = EntryHashGenerator.generate(
      preliminary.toJsonLine(),
      e1.versionId!,
    );
    preliminary.versionId = '2-$entryHash';
    final proof = await ProofGenerator.generate(signer, preliminary);
    final e2 = preliminary..proof = [proof];

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('versionTime'));
  });

  test('scidTamperingFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;

    final tamperedParams = original.parameters!.merge(
      Parameters()..scid = 'zFakeSCIDXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    );
    final tampered = LogEntry()
      ..versionId = original.versionId
      ..versionTime = original.versionTime
      ..parameters = tamperedParams
      ..state = original.state
      ..proof = original.proof;

    final vr = await validator.validate([tampered], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('scid'));
  });

  test('preRotationValidChain', () async {
    final signer2 = await makeTestSigner();
    final multikey2 = extractMultikey(signer2.verificationMethod);
    final hash2 = PreRotationHashGenerator.generateHash(multikey2);

    final create = await DidWebVh.create('example.com', signer)
        .nextKeyHashes([hash2]).execute();
    final e1 = create.logEntry;

    final rotateParams = Parameters()..updateKeys = [multikey2];
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer2,
      changedParams: rotateParams,
    );

    final vr = await validator.validate([e1, e2], create.did);
    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.updateKeys, [multikey2]);
  });

  test('preRotationWrongKeyFails', () async {
    final signer2 = await makeTestSigner();
    final hash2 = PreRotationHashGenerator.generateHash(
      extractMultikey(signer2.verificationMethod),
    );

    final create = await DidWebVh.create('example.com', signer)
        .nextKeyHashes([hash2]).execute();
    final e1 = create.logEntry;

    final signer3 = await makeTestSigner();
    final multikey3 = extractMultikey(signer3.verificationMethod);
    final wrongRotate = Parameters()..updateKeys = [multikey3];
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer3,
      changedParams: wrongRotate,
    );

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('nextKeyHashes'));
  });

  test('deactivationStopsChain', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;

    final deactParams = Parameters()..deactivated = true;
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer,
      changedParams: deactParams,
    );

    final vr2 = await validator.validate([e1, e2], create.did);
    expect(vr2.valid, isTrue);
    expect(vr2.activeParameters!.deactivated, isTrue);

    final e3 = await buildUpdateEntry(e2, create.did, signer);
    final vr3 = await validator.validate([e1, e2, e3], create.did);

    expect(vr3.valid, isFalse);
    expect(vr3.failedEntryIndex, 2);
    expect(vr3.lastValidEntryIndex, 1);
  });

  test('missingMethodInFirstEntryFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;

    final noMethod = Parameters()
      ..scid = original.parameters!.scid
      ..updateKeys = original.parameters!.updateKeys;

    final bad = LogEntry()
      ..versionId = original.versionId
      ..versionTime = original.versionTime
      ..parameters = noMethod
      ..state = original.state
      ..proof = original.proof;

    final vr = await validator.validate([bad], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('method'));
  });

  test('missingScidInFirstEntryFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;
    final noScid = Parameters()
      ..method = original.parameters!.method
      ..updateKeys = original.parameters!.updateKeys;

    final bad = LogEntry()
      ..versionId = original.versionId
      ..versionTime = original.versionTime
      ..parameters = noScid
      ..state = original.state
      ..proof = original.proof;

    final vr = await validator.validate([bad], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('scid'));
  });

  test('missingUpdateKeysInFirstEntryFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;
    final noKeys = Parameters()
      ..method = original.parameters!.method
      ..scid = original.parameters!.scid
      ..updateKeys = const [];

    final bad = LogEntry()
      ..versionId = original.versionId
      ..versionTime = original.versionTime
      ..parameters = noKeys
      ..state = original.state
      ..proof = original.proof;

    final vr = await validator.validate([bad], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('updatekeys'));
  });

  test('methodVersionDecreaseFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final activeMethod = e1.parameters!.method!;
    final lowerMethod =
        activeMethod.replaceFirst(RegExp(r':\d+\.\d+$'), ':0.9');

    final downgrade = Parameters()..method = lowerMethod;
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer,
      changedParams: downgrade,
    );

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(
      vr.failureReason!.toLowerCase(),
      contains('method version must not decrease'),
    );
  });

  test('scidInSecondEntryFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;

    final badParams = Parameters()..scid = 'zSomeSCID';
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer,
      changedParams: badParams,
    );

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('scid'));
  });

  test('witnessBadThresholdFails', () async {
    final badWitness =
        WitnessConfig(3, [const WitnessEntry('did:key:z6MkWit')]);

    final create = await DidWebVh.create('example.com', signer)
        .witness(badWitness)
        .execute();

    final vr = await validator.validate([create.logEntry], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('threshold'));
  });

  test('emptyLogFails', () async {
    final vr = await validator.validate([], 'did:webvh:test');
    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('empty'));
  });

  test('didDocumentIdMismatchFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final vr = await validator.validate(
      [create.logEntry],
      'did:webvh:zzz:wrong.com',
    );

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('expectedDid'));
  });

  test('nullExpectedDidSkipsIdCheck', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final vr = await validator.validate([create.logEntry], null);

    expect(vr.valid, isTrue);
  });

  test('gracefulDegradation', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final e2 = await buildUpdateEntry(e1, create.did, signer);

    final e3valid = await buildUpdateEntry(e2, create.did, signer);
    final tamperedState = deepCopyState(e3valid.state!)..['bad'] = 'data';
    final e3 = LogEntry()
      ..versionId = e3valid.versionId
      ..versionTime = e3valid.versionTime
      ..parameters = e3valid.parameters
      ..state = tamperedState
      ..proof = e3valid.proof;

    final vr = await validator.validate([e1, e2, e3], create.did);

    expect(vr.valid, isFalse);
    expect(vr.lastValidEntryIndex, 1);
    expect(vr.failedEntryIndex, 2);
  });

  test('activeParametersAccumulatedCorrectly', () async {
    final create =
        await DidWebVh.create('example.com', signer).ttl(600).execute();
    final e1 = create.logEntry;

    final ttlChange = Parameters()..ttl = 1200;
    final e2 = await buildUpdateEntry(
      e1,
      create.did,
      signer,
      changedParams: ttlChange,
    );

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.ttl, 1200);
  });

  test('defaultTtlAppliedWhenNotSetInLog', () async {
    final create = await DidWebVh.create('example.com', signer).execute();

    final vr = await validator.validate([create.logEntry], create.did);

    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.ttl, 3600);
  });

  test('specDefaultsReturnedWhenNotSetInLog', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final vr = await validator.validate([create.logEntry], create.did);

    expect(vr.valid, isTrue);
    final active = vr.activeParameters!;
    expect(active.portable, isFalse);
    expect(active.deactivated, isFalse);
    expect(active.watchers, isEmpty);
    expect(active.witness, isNotNull);
    expect(active.witness!.isActive, isFalse);
  });

  test('preRotationOmitUpdateKeysFails', () async {
    final signer2 = await makeTestSigner();
    final hash2 = PreRotationHashGenerator.generateHash(
      extractMultikey(signer2.verificationMethod),
    );

    final create = await DidWebVh.create('example.com', signer)
        .nextKeyHashes([hash2]).execute();
    final e1 = create.logEntry;

    // Entry 2 omits updateKeys entirely AND is signed by the old key.
    final e2 = await buildUpdateEntry(e1, create.did, signer);

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('updatekeys'));
    expect(vr.failureReason!.toLowerCase(), contains('pre-rotation'));
  });

  test('portableScidSwapFails', () async {
    final create =
        await DidWebVh.create('example.com', signer).portable(true).execute();
    final e1 = create.logEntry;

    final state2 = deepCopyState(e1.state!);
    final originalId = state2['id']! as String;
    final parts = originalId.split(':');
    parts[2] = 'QmAttackerChosenSCID000000000000000000000000000';
    state2['id'] = parts.join(':');

    final e2 = await buildUpdateEntry(e1, create.did, signer, newState: state2);

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('scid'));
  });

  test('invalidVersionIdFormatFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;
    final malformed = LogEntry()
      ..versionId = 'not-a-version-id'
      ..versionTime = original.versionTime
      ..parameters = original.parameters
      ..state = original.state
      ..proof = original.proof;

    final vr = await validator.validate([malformed], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('invalid versionid'));
  });

  test('invalidVersionTimeFormatFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final e2 = await buildEntryWithVersionTime(e1, 'not-a-timestamp', 2);

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('invalid versiontime'));
  });

  test('lastVersionTimeInFutureFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final e1 = create.logEntry;
    final farFuture = DateTime.now()
        .toUtc()
        .add(const Duration(seconds: 7200))
        .toIso8601String();
    final e2 = await buildEntryWithVersionTime(e1, farFuture, 2);

    final vr = await validator.validate([e1, e2], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('future'));
  });

  test('witnessThresholdZeroFails', () async {
    final zeroThreshold =
        WitnessConfig(0, [const WitnessEntry('did:key:z6MkWit')]);

    final create = await DidWebVh.create('example.com', signer)
        .witness(zeroThreshold)
        .execute();

    final vr = await validator.validate([create.logEntry], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason!.toLowerCase(), contains('threshold'));
  });

  test('noProofFails', () async {
    final create = await DidWebVh.create('example.com', signer).execute();
    final original = create.logEntry;
    final noProof = LogEntry()
      ..versionId = original.versionId
      ..versionTime = original.versionTime
      ..parameters = original.parameters
      ..state = original.state;

    final vr = await validator.validate([noProof], create.did);

    expect(vr.valid, isFalse);
    expect(vr.failureReason, contains('proof'));
  });
}
