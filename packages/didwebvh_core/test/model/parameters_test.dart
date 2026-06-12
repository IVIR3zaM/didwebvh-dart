import 'dart:convert';

import 'package:didwebvh_core/src/model/json_support.dart';
import 'package:didwebvh_core/src/model/parameters.dart';
import 'package:didwebvh_core/src/witness/witness_config.dart';
import 'package:didwebvh_core/src/witness/witness_entry.dart';
import 'package:test/test.dart';

void main() {
  group('Parameters', () {
    Parameters parse(String json) =>
        Parameters.fromJson(_decode(json));

    test('empty parameters round-trip to empty object', () {
      final p = Parameters();
      final json = JsonSupport.compact(p);
      expect(json, '{}');
      expect(parse(json), p);
    });

    test('full parameters round-trip', () {
      final wc = WitnessConfig(2, [
        const WitnessEntry('did:key:z6Mk1'),
        const WitnessEntry('did:key:z6Mk2'),
      ]);

      final p = Parameters()
        ..method = 'did:webvh:1.0'
        ..scid = 'QmSCID'
        ..updateKeys = ['z6MkA', 'z6MkB']
        ..nextKeyHashes = ['Qm1']
        ..witness = wc
        ..watchers = ['https://watcher.example/']
        ..portable = true
        ..deactivated = false
        ..ttl = 3600;

      final json = JsonSupport.compact(p);
      expect(parse(json), p);
    });

    test('merge applies non-null fields from other', () {
      final base = Parameters()
        ..method = 'did:webvh:1.0'
        ..scid = 'QmSCID'
        ..updateKeys = ['z6MkA']
        ..portable = true;

      final delta = Parameters()
        ..updateKeys = ['z6MkZ']
        ..deactivated = true;

      final merged = base.merge(delta);

      expect(merged.method, 'did:webvh:1.0');
      expect(merged.scid, 'QmSCID');
      expect(merged.updateKeys, ['z6MkZ']);
      expect(merged.portable, isTrue);
      expect(merged.deactivated, isTrue);
      expect(base.deactivated, isNull);
      expect(base.updateKeys, ['z6MkA']);
    });

    test('merge with null returns copy of base', () {
      final base = Parameters()..method = 'did:webvh:1.0';
      final merged = base.merge(null);
      expect(merged, base);
      expect(identical(merged, base), isFalse);
    });

    test('defaults have expected values', () {
      final d = Parameters.defaults();
      expect(d.ttl, 3600);
      expect(d.portable, isFalse);
      expect(d.deactivated, isFalse);
      expect(d.witness, isNotNull);
      expect(d.witness!.isActive, isFalse);
      expect(d.watchers, isNotNull);
      expect(d.watchers, isEmpty);
    });

    test('defaults overridden by merge', () {
      final accumulated =
          Parameters.defaults().merge(Parameters()..ttl = 7200);
      expect(accumulated.ttl, 7200);
    });

    test('defaults preserved when entry omits ttl', () {
      final accumulated = Parameters.defaults()
          .merge(Parameters()..method = 'did:webvh:1.0');
      expect(accumulated.ttl, 3600);
    });

    test('zero ttl distinct from default', () {
      final accumulated = Parameters.defaults().merge(Parameters()..ttl = 0);
      expect(accumulated.ttl, 0);
    });

    test('witness can be cleared to empty', () {
      final active = WitnessConfig(1, [const WitnessEntry('did:key:z6Mk1')]);
      final withWitness =
          Parameters.defaults().merge(Parameters()..witness = active);
      expect(withWitness.witness!.isActive, isTrue);

      final cleared = withWitness
          .merge(Parameters()..witness = WitnessConfig.empty());
      expect(cleared.witness!.isActive, isFalse);
    });

    test('watchers can be cleared to empty', () {
      final withWatchers = Parameters.defaults()
          .merge(Parameters()..watchers = ['https://watcher.example.com']);
      expect(withWatchers.watchers, hasLength(1));

      final cleared =
          withWatchers.merge(Parameters()..watchers = const []);
      expect(cleared.watchers, isEmpty);
    });
  });
}

Map<String, Object?> _decode(String json) =>
    (jsonDecode(json) as Map).cast<String, Object?>();
