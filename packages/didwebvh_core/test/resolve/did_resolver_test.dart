import 'dart:io';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_core/src/resolve/file_did_fetcher.dart';
import 'package:didwebvh_core/src/resolve/log_processor.dart';
import 'package:didwebvh_core/src/resolve/remote_did_fetcher.dart';
import 'package:test/test.dart';

import '../validate/validation_test_helpers.dart';
import 'resolve_test_support.dart';

/// A stub [RemoteDidFetcher] returning canned content (Java's nested
/// `StubRemoteDidFetcher`). A `null` witness content signals `notFound`.
class _StubRemoteDidFetcher implements RemoteDidFetcher {
  _StubRemoteDidFetcher(this._didLog, [this._witnessContent]);

  final String _didLog;
  final String? _witnessContent;
  int witnessFetchCount = 0;

  @override
  Future<String> fetchDidLog(String httpsUrl) async => _didLog;

  @override
  Future<String> fetchWitnessProofs(String witnessUrl) async {
    witnessFetchCount++;
    final content = _witnessContent;
    if (content != null) {
      return content;
    }
    throw ResolutionException.withError('No witness file', 'notFound');
  }
}

/// Port of Java `DidResolverTest`.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('did_resolver'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  String plusSeconds(String iso, int s) =>
      DateTime.parse(iso).add(Duration(seconds: s)).toUtc().toIso8601String();

  test('resolvesFromFile', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final didLog = File('${tempDir.path}/did.jsonl')
      ..writeAsStringSync(create.logLine);

    final result = await DidResolver().resolveFromFile(didLog.path);

    expect(result.didDocument!.id, create.did);
    expect(result.metadata!.versionId, create.logEntry.versionId);
  });

  test('resolveUsesQueryOptionsFromDid', () async {
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

    final resolver = DidResolver.withFetchers(
      _StubRemoteDidFetcher(log),
      FileDidFetcher(),
      LogProcessor(),
    );
    final result = await resolver.resolve('${create.did}?versionNumber=1');

    expect(result.metadata!.versionId, first.versionId);
    expect(result.didDocument!.asJsonObject().containsKey('updated'), isFalse);
  });

  test('queryMayUseOnlyOneVersionSelector', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final resolver = DidResolver.withFetchers(
      _StubRemoteDidFetcher(create.logLine),
      FileDidFetcher(),
      LogProcessor(),
    );

    await expectLater(
      resolver.resolve('${create.did}?versionId=${create.logEntry.versionId}'
          '&versionNumber=1'),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('whenRequiredWitnessModeDoesNotFetchWitnessForUnwitnessedLog', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final fetcher = _StubRemoteDidFetcher(create.logLine);
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    final result = await resolver.resolve(
      create.did,
      ResolveOptions(witnessFetchMode: WitnessFetchMode.whenRequired),
    );

    expect(result.didDocument!.id, create.did);
    expect(fetcher.witnessFetchCount, 0);
  });

  test('whenRequiredWitnessModeFetchesWitnessForWitnessedLog', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final witnessConfig = WitnessConfig(1, [WitnessEntry(witnessDid)]);
    final create = await DidWebVh.create('example.com', author)
        .witness(witnessConfig)
        .execute();
    final proofs = await witnessProofs(create.logEntry.versionId!, witness);
    final fetcher = _StubRemoteDidFetcher(create.logLine, proofsToJson(proofs));
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    final result = await resolver.resolve(
      create.did,
      ResolveOptions(witnessFetchMode: WitnessFetchMode.whenRequired),
    );

    expect(result.metadata!.witness, witnessConfig);
    expect(fetcher.witnessFetchCount, 1);
  });

  test('resolverCanBeConfiguredWithHttpTimeoutAndResponseLimit', () {
    final resolver = DidResolver(
      timeout: const Duration(milliseconds: 500),
      maxResponseSize: 4096,
    );
    expect(resolver, isNotNull);
  });

  test('invalidVersionNumberQueryThrows', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final resolver = DidResolver.withFetchers(
      _StubRemoteDidFetcher(create.logLine),
      FileDidFetcher(),
      LogProcessor(),
    );

    await expectLater(
      resolver.resolve('${create.did}?versionNumber=not-a-number'),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Invalid versionNumber'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('versionTimeQueryParamIsHonoured', () async {
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

    final resolver = DidResolver.withFetchers(
      _StubRemoteDidFetcher(log),
      FileDidFetcher(),
      LogProcessor(),
    );

    // versionTime equal to the first entry's time selects the first entry.
    final result = await resolver
        .resolve('${create.did}?versionTime=${first.versionTime}');

    expect(result.metadata!.versionId, first.versionId);
  });

  test('proactiveWitnessFetchPullsWitnessFile', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final witnessConfig = WitnessConfig(1, [WitnessEntry(witnessDid)]);
    final create = await DidWebVh.create('example.com', author)
        .witness(witnessConfig)
        .execute();
    final proofs = await witnessProofs(create.logEntry.versionId!, witness);
    final fetcher = _StubRemoteDidFetcher(create.logLine, proofsToJson(proofs));
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    final result = await resolver.resolve(
      create.did,
      ResolveOptions(),
    );

    expect(result.metadata!.witness, witnessConfig);
    expect(fetcher.witnessFetchCount, 1);
  });

  test('proactiveWitnessSwallowsNotFoundForUnwitnessedLog', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final fetcher = _StubRemoteDidFetcher(create.logLine);
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    final result = await resolver.resolve(create.did, ResolveOptions());

    // PROACTIVE attempted a witness fetch, but a 404 (notFound) must be
    // swallowed and the resolve must succeed when the log has no witnesses.
    expect(result.didDocument!.id, create.did);
    expect(fetcher.witnessFetchCount, 1);
  });

  test('proactiveWitnessRethrowsNonNotFoundErrors', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();
    final fetcher = _ThrowingWitnessFetcher(create.logLine);
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    await expectLater(
      resolver.resolve(create.did, ResolveOptions()),
      throwsA(
        isA<ResolutionException>().having((e) => e.error, 'error', 'httpError'),
      ),
    );
  });

  test('whenRequiredButWitnessMissingMapsToInvalidDid', () async {
    final author = await makeTestSigner();
    final witness = await makeTestSigner();
    final witnessDid = 'did:key:${extractMultikey(witness.verificationMethod)}';
    final witnessConfig = WitnessConfig(1, [WitnessEntry(witnessDid)]);
    final create = await DidWebVh.create('example.com', author)
        .witness(witnessConfig)
        .execute();
    // Fetcher signals notFound for witness proofs (the chain needs them).
    final fetcher = _StubRemoteDidFetcher(create.logLine);
    final resolver =
        DidResolver.withFetchers(fetcher, FileDidFetcher(), LogProcessor());

    await expectLater(
      resolver.resolve(
        create.did,
        ResolveOptions(witnessFetchMode: WitnessFetchMode.whenRequired),
      ),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Witness proofs are required'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('resolveFromLogValidatesAgainstDid', () async {
    final signer = await makeTestSigner();
    final create = await DidWebVh.create('example.com', signer).execute();

    final result =
        await DidResolver().resolveFromLog(create.logLine, create.did);

    expect(result.didDocument!.id, create.did);
    expect(result.metadata!.versionId, create.logEntry.versionId);
  });
}

/// A fetcher whose witness fetch fails with a non-notFound error (Java's inline
/// anonymous `RemoteDidFetcher` in the rethrow test).
class _ThrowingWitnessFetcher implements RemoteDidFetcher {
  _ThrowingWitnessFetcher(this._didLog);

  final String _didLog;

  @override
  Future<String> fetchDidLog(String httpsUrl) async => _didLog;

  @override
  Future<String> fetchWitnessProofs(String witnessUrl) async =>
      throw ResolutionException.withError('upstream down', 'httpError');
}
