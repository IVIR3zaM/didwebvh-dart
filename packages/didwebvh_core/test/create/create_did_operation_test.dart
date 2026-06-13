import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:didwebvh_core/src/crypto/entry_hash_generator.dart';
import 'package:didwebvh_core/src/crypto/scid_generator.dart';
import 'package:test/test.dart';

import '../signing/test_signer.dart';
import '../support/test_vectors.dart';

/// Faithful port of Java `CreateDidOperationTest`. The async signer makes
/// `execute()` and the proof checks `Future`-returning; everything else mirrors
/// the reference assertions one-for-one.
void main() {
  late TestSigner testSigner;
  late String testMultikey;

  setUpAll(() async {
    testSigner = await TestSigner.generate();
    // verificationMethod is "did:key:<mk>#<mk>".
    testMultikey = testSigner.verificationMethod.split('#').last;
  });

  test('minimalCreation', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();

    expect(result.did, startsWith('did:webvh:'));
    expect(result.did, endsWith(':example.com'));
    expect(result.did, isNot(contains('{SCID}')));

    final entry = result.logEntry;
    expect(entry.versionId, startsWith('1-'));
    expect(entry.versionTime, isNotNull);

    final params = entry.parameters!;
    expect(params.method, 'did:webvh:1.0');
    expect(params.scid, isNotNull);
    expect(params.scid, isNot(contains('{SCID}')));
    expect(params.updateKeys, [testMultikey]);

    final doc = DidDocument(entry.state);
    expect(doc.id, result.did);
    expect(doc.controller, [result.did]);

    expect(entry.proof, hasLength(1));
    final proof = entry.proof!.first;
    expect(proof.type, 'DataIntegrityProof');
    expect(proof.cryptosuite, 'eddsa-jcs-2022');
  });

  test('scidIsValid', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final entry = result.logEntry;
    final scid = entry.parameters!.scid!;
    expect(ScidGenerator.verify(scid, entry), isTrue);
  });

  test('entryHashIsValid', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final entry = result.logEntry;
    final scid = entry.parameters!.scid!;
    expect(EntryHashGenerator.verify(entry, scid), isTrue);
  });

  test('proofIsValid', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final entry = result.logEntry;
    final proof = entry.proof!.first;
    expect(await ProofVerifier.verify(proof, entry), isTrue);
  });

  test('proofIsAuthorized', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final entry = result.logEntry;
    final proof = entry.proof!.first;
    expect(
      ProofVerifier.isAuthorized(proof, entry.parameters!.updateKeys!),
      isTrue,
    );
  });

  test('logLineIsCompactJson', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final logLine = result.logLine;
    expect(logLine, isNot(contains('\n')));
    expect(logLine, isNot(contains('  ')));
  });

  test('jsonlRoundTrip', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final parsed = LogEntry.fromJsonLine(result.logLine);
    expect(parsed.versionId, result.logEntry.versionId);
    expect(parsed.versionTime, result.logEntry.versionTime);
    expect(parsed.parameters!.scid, result.logEntry.parameters!.scid);
  });

  test('createWithPath', () async {
    final result = await DidWebVh.create('example.com', testSigner)
        .path('dids:issuer')
        .execute();
    expect(result.did, endsWith(':example.com:dids:issuer'));
    final doc = DidDocument(result.logEntry.state);
    expect(doc.id, result.did);
  });

  test('createWithPort', () async {
    final result = await DidWebVh.create('example.com%3A3000', testSigner)
        .path('dids:issuer')
        .execute();
    expect(result.did, contains('example.com%3A3000:dids:issuer'));
  });

  test('createWithPortable', () async {
    final result = await DidWebVh.create('example.com', testSigner)
        .portable(true)
        .execute();
    expect(result.logEntry.parameters!.portable, isTrue);
  });

  test('createWithTtl', () async {
    final result =
        await DidWebVh.create('example.com', testSigner).ttl(3600).execute();
    expect(result.logEntry.parameters!.ttl, 3600);
  });

  test('fluent, cascade, and named-parameter styles are equivalent', () async {
    // Fluent (return-this chaining).
    final fluent = await DidWebVh.create('example.com', testSigner)
        .portable(true)
        .ttl(3600)
        .execute();

    // Cascade (`..` ignores the return value).
    final cascade = await (DidWebVh.create('example.com', testSigner)
          ..portable(true)
          ..ttl(3600))
        .execute();

    // Named parameters (applied at construction via the same setters).
    final named = await DidWebVh.create(
      'example.com',
      testSigner,
      portable: true,
      ttl: 3600,
    ).execute();

    for (final result in [fluent, cascade, named]) {
      expect(result.logEntry.parameters!.portable, isTrue);
      expect(result.logEntry.parameters!.ttl, 3600);
    }
  });

  test('createWithAlsoKnownAs', () async {
    final result = await DidWebVh.create('example.com', testSigner).alsoKnownAs(
      ['https://example.com/user', 'mailto:user@example.com'],
    ).execute();
    final doc = DidDocument(result.logEntry.state);
    expect(
      doc.alsoKnownAs,
      ['https://example.com/user', 'mailto:user@example.com'],
    );
  });

  test('createWithWitness', () async {
    final witness =
        WitnessConfig(1, [const WitnessEntry('did:key:z6MkWitness')]);
    final result = await DidWebVh.create('example.com', testSigner)
        .witness(witness)
        .execute();
    final resultWitness = result.logEntry.parameters!.witness!;
    expect(resultWitness.threshold, 1);
    expect(resultWitness.witnesses, hasLength(1));
  });

  test('createWithWatchers', () async {
    final result = await DidWebVh.create('example.com', testSigner)
        .watchers(['https://watcher.example.com']).execute();
    expect(
      result.logEntry.parameters!.watchers,
      ['https://watcher.example.com'],
    );
  });

  test('createWithPreRotation', () async {
    final nextKeyHash = PreRotationHashGenerator.generateHash(testMultikey);
    final result = await DidWebVh.create('example.com', testSigner)
        .nextKeyHashes([nextKeyHash]).execute();
    expect(result.logEntry.parameters!.nextKeyHashes, [nextKeyHash]);
  });

  test('createWithAdditionalContent', () async {
    final additional = <String, Object?>{
      'service': [
        <String, Object?>{
          'id': '#linked-domain',
          'type': 'LinkedDomains',
          'serviceEndpoint': 'https://example.com',
        },
      ],
    };
    final result = await DidWebVh.create('example.com', testSigner)
        .additionalDocumentContent(additional)
        .execute();
    final doc = DidDocument(result.logEntry.state);
    expect(doc.service, isNotNull);
    expect(doc.service, hasLength(1));
  });

  test('createWithAllOptions', () async {
    final nextKeyHash = PreRotationHashGenerator.generateHash(testMultikey);
    final witness =
        WitnessConfig(1, [const WitnessEntry('did:key:z6MkWitness')]);
    final result = await DidWebVh.create('example.com', testSigner)
        .path('dids:issuer')
        .portable(true)
        .ttl(3600)
        .alsoKnownAs(['https://example.com/user'])
        .witness(witness)
        .watchers(['https://watcher.example.com'])
        .nextKeyHashes([nextKeyHash])
        .execute();

    final entry = result.logEntry;
    final params = entry.parameters!;
    expect(result.did, contains(':example.com:dids:issuer'));
    expect(params.portable, isTrue);
    expect(params.ttl, 3600);
    expect(params.witness!.threshold, 1);
    expect(params.watchers, hasLength(1));
    expect(params.nextKeyHashes, hasLength(1));

    expect(ScidGenerator.verify(params.scid!, entry), isTrue);
    expect(EntryHashGenerator.verify(entry, params.scid!), isTrue);
    expect(await ProofVerifier.verify(entry.proof!.first, entry), isTrue);
  });

  test('versionTimeIsValidIso8601', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final versionTime = result.logEntry.versionTime!;
    final parsed = DateTime.parse(versionTime);
    expect(
      parsed.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 5))),
      isTrue,
    );
  });

  test('noScidPlaceholderInOutput', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    expect(result.logLine, isNot(contains('{SCID}')));
    expect(result.did, isNot(contains('{SCID}')));
  });

  test('nullDomainThrows', () {
    expect(
      () => DidWebVh.create(null, testSigner).execute(),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.message, 'message', contains('domain')),
      ),
    );
  });

  test('emptyDomainThrows', () {
    expect(
      () => DidWebVh.create('', testSigner).execute(),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.message, 'message', contains('domain')),
      ),
    );
  });

  test('nullSignerThrows', () {
    expect(
      () => DidWebVh.create('example.com', null).execute(),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.message, 'message', contains('signer')),
      ),
    );
  });

  test('negativeTtlThrows', () {
    expect(
      () => DidWebVh.create('example.com', testSigner).ttl(-1).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('ttl must be non-negative'),
        ),
      ),
    );
  });

  test('zeroTtlMeansDoNotCache', () async {
    final result =
        await DidWebVh.create('example.com', testSigner).ttl(0).execute();
    expect(result.logEntry.parameters!.ttl, 0);
  });

  test('nextKeyHashEmptyEntryThrows', () {
    expect(
      () => DidWebVh.create('example.com', testSigner)
          .nextKeyHashes(['']).execute(),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.message, 'message', contains('non-empty')),
      ),
    );
  });

  test('controllersEmptyListOmitsControllerProperty', () async {
    final result = await DidWebVh.create('example.com', testSigner)
        .controllers(const []).execute();
    expect(result.logEntry.state!.containsKey('controller'), isFalse);
  });

  test('controllersSingleElementUsesStringForm', () async {
    final result = await DidWebVh.create('example.com', testSigner)
        .controllers(['did:web:other.example.com']).execute();
    final controller = result.logEntry.state!['controller'];
    expect(controller, isA<String>());
    expect(controller, 'did:web:other.example.com');
  });

  test('controllersMultipleElementsUsesArrayForm', () async {
    final result = await DidWebVh.create('example.com', testSigner).controllers(
      ['did:web:a.example.com', 'did:web:b.example.com'],
    ).execute();
    final controller = result.logEntry.state!['controller'];
    expect(controller, isA<List<Object?>>());
    expect(controller! as List, hasLength(2));
  });

  test('extractMultikeyAcceptsBareDidKeyVerificationMethod', () async {
    final bareSigner = _BareSigner(testSigner, 'did:key:$testMultikey');
    final result = await DidWebVh.create('example.com', bareSigner).execute();
    expect(result.logEntry.parameters!.updateKeys, [testMultikey]);
  });

  test('extractMultikeyRejectsForeignVerificationMethod', () {
    final foreignSigner = _BareSigner(testSigner, 'https://example.com/keys/1');
    expect(
      () => DidWebVh.create('example.com', foreignSigner).execute(),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Cannot extract multikey'),
        ),
      ),
    );
  });

  test('didDocumentHasVerificationMethod', () async {
    final result = await DidWebVh.create('example.com', testSigner).execute();
    final doc = DidDocument(result.logEntry.state);
    final vms = doc.verificationMethod;
    expect(vms, isNotNull);
    expect(vms, hasLength(1));

    final vm = (vms!.first! as Map).cast<String, Object?>();
    expect(vm['type'], 'Multikey');
    expect(vm['publicKeyMultibase'], testMultikey);
    expect(vm['controller'], result.did);
  });

  test('first-log-entry-good vector verifies (scid, entryHash, proof)',
      () async {
    final line = TestVectors.readVector(
      '${TestVectors.specRoot}/first-log-entry-good.jsonl',
    ).trim();
    final entry = LogEntry.fromJsonLine(line);
    final scid = entry.parameters!.scid!;

    expect(ScidGenerator.verify(scid, entry), isTrue);
    expect(EntryHashGenerator.verify(entry, scid), isTrue);
    expect(await ProofVerifier.verify(entry.proof!.first, entry), isTrue);

    // The created shape matches the vector: a creation built for the same
    // domain and update key reproduces the vector's state byte-for-byte.
    final vectorState = (jsonDecode(line) as Map)['state'];
    final result = await DidWebVh.create('example.com', testSigner).execute();
    expect(
      result.logEntry.state!.keys.toList(),
      (vectorState as Map).keys.toList(),
    );
  });
}

/// Signer wrapper that overrides only the verification method, mirroring the
/// anonymous bare/foreign signers in the Java test.
class _BareSigner implements Signer {
  _BareSigner(this._delegate, this._verificationMethod);

  final Signer _delegate;
  final String _verificationMethod;

  @override
  String get keyType => _delegate.keyType;

  @override
  String get verificationMethod => _verificationMethod;

  @override
  Future<Uint8List> sign(Uint8List data) => _delegate.sign(data);
}
