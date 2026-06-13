import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh/src/resolve/log_processor.dart';
import 'package:test/test.dart';

import '../validate/validation_test_helpers.dart';
import 'resolve_test_support.dart';

/// Port of Java `LogProcessorTest`.
void main() {
  final processor = LogProcessor();

  String plusSeconds(String iso, int s) =>
      DateTime.parse(iso).add(Duration(seconds: s)).toUtc().toIso8601String();
  String minusMicro(String iso) => DateTime.parse(iso)
      .subtract(const Duration(microseconds: 1))
      .toUtc()
      .toIso8601String();

  Matcher invalidDid(String messageFragment) => throwsA(
        isA<ResolutionException>()
            .having((e) => e.message, 'message', contains(messageFragment)),
      );

  test('resolvedDocumentIncludesImplicitFilesAndWhoisServices', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    final result = await processor.process(
      create.logLine,
      null,
      create.did,
      ResolveOptions.defaults(),
    );

    final services =
        result.didDocument!.asJsonObject()['service']! as List<Object?>;
    expect(services, hasLength(2));

    final files = services[0]! as Map<String, Object?>;
    expect(files['id'], '${create.did}#files');
    expect(files['type'], 'relativeRef');
    expect(files['serviceEndpoint'], 'https://example.com/');

    final whois = services[1]! as Map<String, Object?>;
    expect(whois['id'], '${create.did}#whois');
    expect(whois['type'], 'LinkedVerifiablePresentation');
    expect(whois['serviceEndpoint'], 'https://example.com/whois.vp');
  });

  test('resolvesLatestEntryWithMetadata', () async {
    final signer = await makeTestSigner();
    final create =
        await DidWebVh.create('example.com', signer).ttl(600).execute();

    final result = await processor.process(
      create.logLine,
      null,
      create.did,
      ResolveOptions.defaults(),
    );

    expect(result.didDocument!.id, create.did);
    expect(result.metadata!.versionId, create.logEntry.versionId);
    expect(result.metadata!.created, create.logEntry.versionTime);
    expect(result.metadata!.ttl, '600');
    expect(result.metadata!.deactivated, isFalse);
  });

  test('resolvesSpecificVersions', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final first = create.logEntry;

    final secondState = deepCopyState(first.state!)..['updated'] = 'true';
    final second = await buildUpdateEntry(
      first,
      create.did,
      signer,
      newState: secondState,
      versionTime: plusSeconds(first.versionTime!, 1),
    );
    final log = '${first.toJsonLine()}\n${second.toJsonLine()}';
    final justBeforeSecond = minusMicro(second.versionTime!);

    final latest = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions.defaults(),
    );
    final byVersionId = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions(versionId: first.versionId),
    );
    final byVersionNumber = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions(versionNumber: 1),
    );
    final byVersionTime = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions(versionTime: justBeforeSecond),
    );

    expect(latest.didDocument!.asJsonObject()['updated'], 'true');
    expect(byVersionId.metadata!.versionId, first.versionId);
    expect(byVersionNumber.metadata!.versionId, first.versionId);
    expect(byVersionTime.metadata!.versionId, first.versionId);
  });

  test('versionTimeSelectsLastEntryActiveAtRequestedTime', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final first = create.logEntry;

    final secondState = deepCopyState(first.state!)..['active'] = 'second';
    final second = await buildUpdateEntry(
      first,
      create.did,
      signer,
      newState: secondState,
      versionTime: plusSeconds(first.versionTime!, 1),
    );
    final thirdState = deepCopyState(secondState)..['active'] = 'third';
    final third = await buildUpdateEntry(
      second,
      create.did,
      signer,
      newState: thirdState,
      versionTime: plusSeconds(first.versionTime!, 2),
    );
    final log = '${first.toJsonLine()}\n${second.toJsonLine()}'
        '\n${third.toJsonLine()}';
    final beforeThird = minusMicro(third.versionTime!);

    final result = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions(versionTime: beforeThird),
    );

    expect(result.metadata!.versionId, second.versionId);
    expect(result.didDocument!.asJsonObject()['active'], 'second');
  });

  test('multipleVersionSelectorsThrowInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions(versionId: create.logEntry.versionId, versionNumber: 1),
      ),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('deactivatedDidReturnsMetadataWithoutDocument', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final deactivated = await buildUpdateEntry(
      create.logEntry,
      create.did,
      signer,
      changedParams: Parameters()..deactivated = true,
      versionTime: plusSeconds(create.logEntry.versionTime!, 1),
    );
    final log = '${create.logLine}\n${deactivated.toJsonLine()}';

    final result = await processor.process(
      log,
      null,
      create.did,
      ResolveOptions.defaults(),
    );

    expect(result.didDocument, isNull);
    expect(result.metadata!.deactivated, isTrue);
    expect(result.metadata!.versionId, deactivated.versionId);
  });

  test('tamperedLogThrowsInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final orig = create.logEntry;
    final tampered = LogEntry()
      ..versionId = orig.versionId
      ..versionTime = orig.versionTime
      ..parameters = orig.parameters
      ..state = deepCopyState(orig.state!)
      ..proof = orig.proof;
    tampered.state!['tampered'] = 'true';

    await expectLater(
      processor.process(
        tampered.toJsonLine(),
        null,
        create.did,
        ResolveOptions.defaults(),
      ),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('validatesWitnessProofsWhenConfigured', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final witnessConfig = WitnessConfig(1, [WitnessEntry(witnessDid)]);
    final create = await DidWebVh.create('example.com', author)
        .witness(witnessConfig)
        .execute();
    final proofs = await witnessProofs(create.logEntry.versionId!, witness);

    final result = await processor.process(
      create.logLine,
      proofsToJson(proofs),
      create.did,
      ResolveOptions.defaults(),
    );

    expect(result.didDocument!.id, create.did);
    expect(result.metadata!.witness, witnessConfig);
  });

  test('missingWitnessProofsThrowInvalidDid', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final create = await DidWebVh.create('example.com', author)
        .witness(WitnessConfig(1, [WitnessEntry(witnessDid)]))
        .execute();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions.defaults(),
      ),
      invalidDid('Witness proofs'),
    );
  });

  test('crossDidWitnessReplayRejected', () async {
    final authorA = await makeTestSigner();
    final authorB = await makeTestSigner();
    final sharedWitness = await makeTestSigner();
    final sharedWitnessDid =
        'did:key:${extractMultikey(sharedWitness.verificationMethod)}';
    final sharedConfig = WitnessConfig(1, [WitnessEntry(sharedWitnessDid)]);

    // DID-B's 3rd entry yields a real versionId the witness genuinely signed.
    final createB = await DidWebVh.create('other.example.com', authorB)
        .witness(sharedConfig)
        .execute();
    final b1 = createB.logEntry;
    final b2 = await buildUpdateEntry(
      b1,
      createB.did,
      authorB,
      versionTime: plusSeconds(b1.versionTime!, 1),
    );
    final b3 = await buildUpdateEntry(
      b2,
      createB.did,
      authorB,
      versionTime: plusSeconds(b1.versionTime!, 2),
    );
    final didBProofs = await witnessProofs(b3.versionId!, sharedWitness);

    // DID-A: entry 1 witnessing on, entry 2 disables it, entry 3 inherits off.
    final createA = await DidWebVh.create('example.com', authorA)
        .witness(sharedConfig)
        .execute();
    final a1 = createA.logEntry;
    final a2 = await buildUpdateEntry(
      a1,
      createA.did,
      authorA,
      changedParams: Parameters()..witness = WitnessConfig.empty(),
      versionTime: plusSeconds(a1.versionTime!, 1),
    );
    final a3 = await buildUpdateEntry(
      a2,
      createA.did,
      authorA,
      versionTime: plusSeconds(a1.versionTime!, 2),
    );
    final didALog =
        '${a1.toJsonLine()}\n${a2.toJsonLine()}\n${a3.toJsonLine()}\n';

    // DID-A's did-witness.json carries DID-B's proof verbatim (real signature,
    // but a versionId from DID-B's log, not DID-A's).
    await expectLater(
      processor.process(
        didALog,
        proofsToJson(didBProofs),
        createA.did,
        ResolveOptions.defaults(),
      ),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('emptyLogContentMapsToInvalidDid', () async {
    await expectLater(
      processor.process('', null, null, ResolveOptions.defaults()),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('DID log must not be empty'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('blankOnlyLogMapsToMustContainAtLeastOneEntry', () async {
    await expectLater(
      processor.process('   \n\n  \n', null, null, ResolveOptions.defaults()),
      invalidDid('DID log must not be empty'),
    );
  });

  test('malformedLogLineMapsToInvalidDid', () async {
    await expectLater(
      processor.process('{not-json', null, null, ResolveOptions.defaults()),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Unable to parse DID log entry'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('unknownVersionIdMapsToInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions(versionId: '999-Qmwrong'),
      ),
      invalidDid('No DID log entry found for versionId'),
    );
  });

  test('unknownVersionNumberMapsToInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions(versionNumber: 42),
      ),
      invalidDid('No DID log entry found for versionNumber'),
    );
  });

  test('invalidVersionTimeQueryMapsToInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions(versionTime: 'not-a-timestamp'),
      ),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Invalid versionTime'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('versionTimeBeforeFirstEntryMapsToInvalidDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final beforeAll = DateTime.parse(create.logEntry.versionTime!)
        .subtract(const Duration(seconds: 3600))
        .toUtc()
        .toIso8601String();

    await expectLater(
      processor.process(
        create.logLine,
        null,
        create.did,
        ResolveOptions(versionTime: beforeAll),
      ),
      invalidDid('No DID log entry found at or before versionTime'),
    );
  });

  test('malformedWitnessProofsMapToInvalidDid', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final create = await DidWebVh.create('example.com', author)
        .witness(WitnessConfig(1, [WitnessEntry(witnessDid)]))
        .execute();

    await expectLater(
      processor.process(
        create.logLine,
        '{not-json',
        create.did,
        ResolveOptions.defaults(),
      ),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Unable to parse witness proofs'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('problemDetailsUseDidwebvhProblemType', () {
    final exception = ResolutionException.withError('Bad log', 'invalidDid');
    expect(
      exception.problemDetails!['type'],
      'urn:didwebvh:error:invalidDid',
    );
    expect(exception.problemDetails!['title'], 'Invalid DID');
  });
}
