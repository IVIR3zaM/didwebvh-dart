import 'dart:convert';

import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

import '../signing/test_signer.dart';

/// Exercises the full `DidWebVhState` surface — every field and method ported
/// from Java `DidWebVhState`. The shared `UpdateDidOperationTest` port already
/// covers the create→update→validate flow; this suite pins the remaining paths
/// (witness-proof serialization, accessors, the appendEntry DID-tracking
/// branch) so the holder is provably complete.
void main() {
  late TestSigner signer;

  setUpAll(() async {
    signer = await TestSigner.generate();
  });

  Future<DidWebVhState> freshState() async {
    final created = await DidWebVh.create('example.com', signer).execute();
    return DidWebVhState.from(created.did, created.logEntry);
  }

  test('from creates single-entry state with no witness proofs', () async {
    final state = await freshState();
    expect(state.logEntries, hasLength(1));
    expect(state.witnessProofs, isNull);
    expect(state.isValidated, isFalse);
    expect(state.activeParameters, isNull);
    expect(state.lastEntry, same(state.logEntries.single));
  });

  test('logEntries view is unmodifiable', () async {
    final state = await freshState();
    expect(
      () => state.logEntries.add(state.lastEntry!),
      throwsUnsupportedError,
    );
  });

  test('toJson/fromJson round-trips witness proofs', () async {
    final state = await freshState();

    final proof = DataIntegrityProof.defaults()
      ..verificationMethod = signer.verificationMethod
      ..created = '2024-01-01T00:00:00Z'
      ..proofValue = 'z3FXmpDSample';
    state.witnessProofs = WitnessProofCollection([
      WitnessProofEntry.of(state.lastEntry!.versionId, [proof]),
    ]);

    final json = state.toJson();
    // Witness proofs serialize under the "witnessProofs" object (Gson shape).
    final decoded = (jsonDecode(json) as Map).cast<String, Object?>();
    expect(decoded['witnessProofs'], isA<Map<String, Object?>>());

    final reloaded = DidWebVhState.fromJson(json);
    expect(reloaded.did, state.did);
    expect(reloaded.witnessProofs, isNotNull);
    expect(reloaded.witnessProofs, state.witnessProofs);
  });

  test('toJson omits witnessProofs when none are set', () async {
    final state = await freshState();
    final decoded =
        (jsonDecode(state.toJson()) as Map).cast<String, Object?>();
    expect(decoded.containsKey('witnessProofs'), isFalse);
  });

  test('fromDidLog skips blank lines', () async {
    final state = await freshState();
    final padded = '\n${state.toDidLog()}\n\n';
    final reloaded = DidWebVhState.fromDidLog(state.did, padded);
    expect(reloaded.logEntries, hasLength(1));
    expect(reloaded.did, state.did);
  });

  test('appendEntry adopts the DID from the new entry id', () async {
    final state = await freshState();
    final original = state.did;

    // Simulate a migrated entry whose document id is a new DID.
    const newDid = 'did:webvh:scid:new.example';
    final migrated = LogEntry.fromJsonLine(state.lastEntry!.toJsonLine())
      ..state = {...state.lastEntry!.state!, 'id': newDid};
    state.appendEntry(migrated);

    expect(original, isNot(newDid));
    expect(state.did, newDid);
    expect(state.isValidated, isFalse);
    expect(state.activeParameters, isNull);
  });

  test('validate marks the state validated and sets active parameters',
      () async {
    final state = await freshState();
    final result = await state.validate();
    expect(result.valid, isTrue);
    expect(state.isValidated, isTrue);
    expect(state.activeParameters, isNotNull);
    // accumulateParameters reflects the create defaults (not deactivated).
    expect(state.isDeactivated, isFalse);
    expect(state.accumulateParameters().method, 'did:webvh:1.0');
  });
}
