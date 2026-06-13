import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import '../signing/test_signer.dart';

/// Faithful port of Java `UpdateDidOperationTest`. The async signer makes
/// `execute()` and `state.validate()` `Future`-returning; everything else
/// mirrors the reference assertions one-for-one. Documents are plain maps
/// (Dart's idiomatic decoded-JSON shape) rather than Gson `JsonObject`s.
void main() {
  late TestSigner signerA;
  late TestSigner signerB;
  late String multikeyB;

  setUpAll(() async {
    signerA = await TestSigner.generate();
    signerB = await TestSigner.generate();
    multikeyB = signerB.verificationMethod.split('#').last;
  });

  // ---------------------------------------------------------------------------
  // Simple update
  // ---------------------------------------------------------------------------

  test('simpleUpdate_addService_chainValidates', () async {
    final state = await _createState('example.com', signerA);

    final newDoc = _addService(_deepCopy(state.lastEntry!.state!));
    final result =
        await DidWebVh.update(state, signerA).newDocument(newDoc).execute();

    expect(result.newEntries, hasLength(1));
    final updated = result.logEntry;
    expect(updated.versionNumber, 2);

    state.appendEntry(updated);
    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(vr.lastValidEntryIndex, 1);
  });

  test('multipleUpdates_chainValidates', () async {
    final state = await _createState('example.com', signerA);

    for (var i = 0; i < 5; i++) {
      final result = await DidWebVh.update(state, signerA).execute();
      state.appendEntry(result.logEntry);
    }

    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(state.logEntries, hasLength(6));
  });

  // ---------------------------------------------------------------------------
  // Parameter update
  // ---------------------------------------------------------------------------

  test('parameterUpdate_changeTtl_chainValidates', () async {
    final state = await _createState('example.com', signerA);

    final changed = Parameters()..ttl = 7200;
    final result = await DidWebVh.update(state, signerA)
        .changedParameters(changed)
        .execute();
    state.appendEntry(result.logEntry);

    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.ttl, 7200);
  });

  // ---------------------------------------------------------------------------
  // Key rotation
  // ---------------------------------------------------------------------------

  test('keyRotation_oldKeyCannotSignSubsequentEntry', () async {
    final state = await _createState('example.com', signerA);

    // Rotate to signerB.
    final rotateParams = Parameters()..updateKeys = [multikeyB];
    final rotated = await DidWebVh.update(state, signerA)
        .changedParameters(rotateParams)
        .execute();
    state.appendEntry(rotated.logEntry);

    // Valid up to here.
    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);

    // Old key (signerA) can no longer sign valid entries.
    final invalidEntry = await DidWebVh.update(state, signerA).execute();
    state.appendEntry(invalidEntry.logEntry);

    final vr2 = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr2.valid, isFalse);
    expect(vr2.failedEntryIndex, 2);
  });

  // ---------------------------------------------------------------------------
  // Validation guards
  // ---------------------------------------------------------------------------

  test('updateAfterDeactivation_throws', () async {
    final state = await _createState('example.com', signerA);
    final deactivation = await DidWebVh.deactivate(state, signerA).execute();
    for (final e in deactivation.newEntries) {
      state.appendEntry(e);
    }

    expect(
      () => DidWebVh.update(state, signerA).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('deactivated'),
        ),
      ),
    );
  });

  // ---------------------------------------------------------------------------
  // DidWebVhState helpers
  // ---------------------------------------------------------------------------

  test('stateToDidLog_roundTrip', () async {
    final state = await _createState('example.com', signerA);
    final result = await DidWebVh.update(state, signerA).execute();
    state.appendEntry(result.logEntry);

    final jsonl = state.toDidLog();
    final reloaded = DidWebVhState.fromDidLog(state.did, jsonl);
    expect(reloaded.logEntries, hasLength(2));
    expect(reloaded.did, state.did);
  });

  test('stateToJson_roundTrip', () async {
    final state = await _createState('example.com', signerA);
    final result = await DidWebVh.update(state, signerA).execute();
    state.appendEntry(result.logEntry);

    final json = state.toJson();
    final reloaded = DidWebVhState.fromJson(json);
    expect(reloaded.logEntries, hasLength(2));
    expect(reloaded.did, state.did);
  });

  test('stateValidate_setsActiveParameters', () async {
    final state = await _createState('example.com', signerA);
    final vr = await state.validate();
    expect(vr.valid, isTrue);
    expect(state.isValidated, isTrue);
    expect(state.activeParameters, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------------

  test('migration_portable_rewritesDid_addsAlsoKnownAs', () async {
    final state = await _createPortableState('old.example.com', signerA);
    final oldDid = state.did;

    final result =
        await DidWebVh.migrate(state, signerA, 'new.example.com').execute();
    expect(result.newEntries, hasLength(1));

    state.appendEntry(result.logEntry);
    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);

    // Document id should now contain the new domain.
    final newDoc = state.lastEntry!.state!;
    final newId = newDoc['id']! as String;
    expect(newId, contains('new.example.com'));
    expect(newId, isNot(contains('old.example.com')));

    // Old DID should be in alsoKnownAs.
    final aka = newDoc['alsoKnownAs'];
    expect(aka, isNotNull);
    expect(aka, contains(oldDid));
  });

  test('migration_notPortable_throws', () async {
    final state = await _createState('example.com', signerA);

    expect(
      () => DidWebVh.migrate(state, signerA, 'new.example.com').execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('portable'),
        ),
      ),
    );
  });

  test('migration_nullExistingState_throws', () async {
    expect(
      () => MigrateDidConfig(null, signerA, 'new.example.com').execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('existingState is required'),
        ),
      ),
    );
  });

  test('migration_nullSigner_throws', () async {
    final state = await _createPortableState('old.example.com', signerA);
    expect(
      () => MigrateDidConfig(state, null, 'new.example.com').execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('signer is required'),
        ),
      ),
    );
  });

  test('migration_nullNewDomain_throws', () async {
    final state = await _createPortableState('old.example.com', signerA);
    expect(
      () => MigrateDidConfig(state, signerA, null).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('newDomain is required'),
        ),
      ),
    );
  });

  test('migration_emptyNewDomain_throws', () async {
    final state = await _createPortableState('old.example.com', signerA);
    expect(
      () => MigrateDidConfig(state, signerA, '').execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('newDomain is required'),
        ),
      ),
    );
  });

  test('migration_deactivatedDid_throws', () async {
    final state = await _createPortableState('old.example.com', signerA);
    final deactivation = await DidWebVh.deactivate(state, signerA).execute();
    state.appendEntry(deactivation.logEntry);

    expect(
      () => DidWebVh.migrate(state, signerA, 'new.example.com').execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('deactivated'),
        ),
      ),
    );
  });

  test('migration_withNewPath_appendsPathSegment', () async {
    final state = await _createPortableState('old.example.com', signerA);

    final result = await DidWebVh.migrate(state, signerA, 'new.example.com')
        .newPath('dids:issuer')
        .execute();
    state.appendEntry(result.logEntry);

    final newId = state.lastEntry!.state!['id']! as String;
    expect(newId, contains(':new.example.com:dids:issuer'));
  });

  test('migration_existingAlsoKnownAsContainsOldDid_isNotDuplicated', () async {
    // Seed the document with an alsoKnownAs that already references the old
    // DID; the migrate op must not append a duplicate.
    final state = await _createPortableState('old.example.com', signerA);
    final oldDid = state.did;

    final docWithAka = _deepCopy(state.lastEntry!.state!);
    docWithAka['alsoKnownAs'] = [oldDid];
    final prep = await DidWebVh.update(state, signerA)
        .newDocument(docWithAka)
        .execute();
    state.appendEntry(prep.logEntry);

    final migrated =
        await DidWebVh.migrate(state, signerA, 'new.example.com').execute();
    state.appendEntry(migrated.logEntry);

    final finalAka = state.lastEntry!.state!['alsoKnownAs']! as List;
    final oldDidCount = finalAka.where((el) => el == oldDid).length;
    expect(oldDidCount, 1, reason: 'old DID appears once in alsoKnownAs');
  });

  // ---------------------------------------------------------------------------
  // Deactivation
  // ---------------------------------------------------------------------------

  test('deactivation_setsDeactivatedFlag', () async {
    final state = await _createState('example.com', signerA);

    final result = await DidWebVh.deactivate(state, signerA).execute();
    expect(result.newEntries, hasLength(1));

    final entry = result.logEntry;
    expect(entry.parameters!.deactivated, isTrue);
    expect(entry.parameters!.updateKeys, isEmpty);

    state.appendEntry(entry);
    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.deactivated, isTrue);
  });

  test('deactivation_withPreRotation_producesTwoEntries', () async {
    // Create DID with pre-rotation: nextKeyHashes = [hash(B)].
    final hashOfB = PreRotationHashGenerator.generateHash(multikeyB);
    final state =
        await _createStateWithPreRotation('example.com', signerA, hashOfB);

    final result = await DidWebVh.deactivate(state, signerA)
        .nextRotationSigner(signerB)
        .execute();

    expect(result.newEntries, hasLength(2));

    // Intermediate entry: reveals B, clears nextKeyHashes.
    final intermediate = result.newEntries[0];
    expect(intermediate.parameters!.updateKeys, [multikeyB]);
    expect(intermediate.parameters!.nextKeyHashes, isEmpty);

    // Final entry: deactivated=true, updateKeys=[].
    final finalEntry = result.newEntries[1];
    expect(finalEntry.parameters!.deactivated, isTrue);
    expect(finalEntry.parameters!.updateKeys, isEmpty);

    // Append both and validate.
    for (final e in result.newEntries) {
      state.appendEntry(e);
    }
    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.deactivated, isTrue);
  });

  test('deactivation_withPreRotation_missingNextSigner_throws', () async {
    final hashOfB = PreRotationHashGenerator.generateHash(multikeyB);
    final state =
        await _createStateWithPreRotation('example.com', signerA, hashOfB);

    expect(
      () => DidWebVh.deactivate(state, signerA).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('nextRotationSigner'),
        ),
      ),
    );
  });

  test('deactivation_alreadyDeactivated_throws', () async {
    final state = await _createState('example.com', signerA);
    final result = await DidWebVh.deactivate(state, signerA).execute();
    for (final e in result.newEntries) {
      state.appendEntry(e);
    }

    expect(
      () => DidWebVh.deactivate(state, signerA).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('deactivated'),
        ),
      ),
    );
  });

  // ---------------------------------------------------------------------------
  // End-to-end
  // ---------------------------------------------------------------------------

  test('endToEnd_createUpdateMigrateDeactivate', () async {
    // Create portable DID.
    final state = await _createPortableState('old.example.com', signerA);

    // Update 3×.
    for (var i = 0; i < 3; i++) {
      final r = await DidWebVh.update(state, signerA).execute();
      state.appendEntry(r.logEntry);
    }

    // Migrate.
    final migrated =
        await DidWebVh.migrate(state, signerA, 'new.example.com').execute();
    state.appendEntry(migrated.logEntry);
    // After migration the canonical DID reflects the new domain (SCID
    // preserved).
    expect(state.did, contains('new.example.com'));

    // Update 2× after migration.
    for (var i = 0; i < 2; i++) {
      final r = await DidWebVh.update(state, signerA).execute();
      state.appendEntry(r.logEntry);
    }

    // Deactivate.
    final deact = await DidWebVh.deactivate(state, signerA).execute();
    for (final e in deact.newEntries) {
      state.appendEntry(e);
    }

    final vr = await LogChainValidator().validate(state.logEntries, state.did);
    expect(vr.valid, isTrue);
    expect(vr.activeParameters!.deactivated, isTrue);
    // 1 create + 3 updates + 1 migrate + 2 updates + 1 deactivate = 8.
    expect(state.logEntries, hasLength(8));
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

Future<DidWebVhState> _createState(String domain, Signer signer) async {
  final created = await DidWebVh.create(domain, signer).execute();
  return DidWebVhState.from(created.did, created.logEntry);
}

Future<DidWebVhState> _createPortableState(String domain, Signer signer) async {
  final created =
      await DidWebVh.create(domain, signer).portable(true).execute();
  return DidWebVhState.from(created.did, created.logEntry);
}

Future<DidWebVhState> _createStateWithPreRotation(
  String domain,
  Signer signer,
  String nextKeyHash,
) async {
  final created = await DidWebVh.create(domain, signer)
      .nextKeyHashes([nextKeyHash]).execute();
  return DidWebVhState.from(created.did, created.logEntry);
}

Map<String, Object?> _addService(Map<String, Object?> doc) {
  doc['service'] = [
    <String, Object?>{
      'id': '${doc['id']}#linked-domain',
      'type': 'LinkedDomains',
      'serviceEndpoint': 'https://example.com',
    },
  ];
  return doc;
}

Map<String, Object?> _deepCopy(Map<String, Object?> doc) =>
    (jsonDecode(jsonEncode(doc)) as Map).cast<String, Object?>();
