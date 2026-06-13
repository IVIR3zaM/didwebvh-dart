import 'dart:typed_data';

import 'package:didwebvh_core/src/crypto/multikey.dart';
import 'package:didwebvh_core/src/crypto/pre_rotation_hash_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PreRotationHashGenerator', () {
    test('generateHash produces base58btc result', () {
      final publicKey = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        publicKey[i] = i + 1;
      }
      final multikey = MultikeyUtil.encode('Ed25519', publicKey);
      final hash = PreRotationHashGenerator.generateHash(multikey);
      // Spec 3.7.7: base58btc(multihash(multikey)) — no multibase prefix.
      // A SHA-256 multihash encoded in base58btc starts with "Qm", 46 chars.
      expect(hash.length, 46);
      expect(hash.startsWith('Qm'), isTrue);
    });

    test('generateHash is deterministic', () {
      const multikey = 'z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      expect(
        PreRotationHashGenerator.generateHash(multikey),
        PreRotationHashGenerator.generateHash(multikey),
      );
    });

    test('different keys produce different hashes', () {
      final key1 = Uint8List(32);
      final key2 = Uint8List(32)..[0] = 1;
      final multikey1 = MultikeyUtil.encode('Ed25519', key1);
      final multikey2 = MultikeyUtil.encode('Ed25519', key2);
      expect(
        PreRotationHashGenerator.generateHash(multikey1),
        isNot(PreRotationHashGenerator.generateHash(multikey2)),
      );
    });
  });
}
