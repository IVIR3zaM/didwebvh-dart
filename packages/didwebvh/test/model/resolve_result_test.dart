import 'dart:convert';

import 'package:didwebvh/src/model/did_document.dart';
import 'package:didwebvh/src/model/json_support.dart';
import 'package:didwebvh/src/model/resolution_metadata.dart';
import 'package:didwebvh/src/model/resolve_result.dart';
import 'package:didwebvh/src/witness/witness_config.dart';
import 'package:didwebvh/src/witness/witness_entry.dart';
import 'package:test/test.dart';

void main() {
  group('ResolveResult', () {
    test('metadata round-trip', () {
      final meta = ResolutionMetadata()
        ..versionId = '1-QmHash'
        ..versionTime = '2026-04-15T00:00:00Z'
        ..created = '2026-04-15T00:00:00Z'
        ..updated = '2026-04-15T00:00:00Z'
        ..scid = 'QmSCID'
        ..portable = true
        ..deactivated = false
        ..ttl = '3600'
        ..witness =
            WitnessConfig(1, [const WitnessEntry('did:key:z6Mk1')])
        ..watchers = ['https://watcher.example/'];

      final encoded = JsonSupport.compact(meta);
      final decoded = ResolutionMetadata.fromJson(
        (jsonDecode(encoded) as Map).cast<String, Object?>(),
      );
      expect(decoded, meta);
    });

    test('resolve result wraps document and metadata', () {
      final j = <String, Object?>{'id': 'did:webvh:QmSCID:example.com'};
      final r = ResolveResult()
        ..didDocument = DidDocument(j)
        ..metadata = (ResolutionMetadata()..versionId = '1-QmHash');

      expect(r.didDocument!.id, 'did:webvh:QmSCID:example.com');
      expect(r.metadata!.versionId, '1-QmHash');
      expect(r.error, isNull);
    });

    test('value equality including problem details', () {
      ResolveResult build() => ResolveResult()
        ..error = 'notFound'
        ..problemDetails = <String, Object?>{'type': 'urn:x', 'detail': 'd'}
        ..metadata = (ResolutionMetadata()..versionId = '1-QmHash');

      final a = build();
      final b = build();
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      b.error = 'invalidDid';
      expect(a, isNot(b));
    });
  });
}
