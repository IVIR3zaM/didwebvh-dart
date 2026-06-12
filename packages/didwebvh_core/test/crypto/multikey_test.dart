import 'dart:typed_data';

import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:didwebvh_core/src/crypto/multikey.dart';
import 'package:test/test.dart';

void main() {
  group('MultikeyUtil', () {
    test('encode/decode Ed25519 round trip', () {
      final publicKey = Uint8List.fromList(
        List<int>.generate(32, (i) => i + 1),
      );
      final multikey = MultikeyUtil.encode('Ed25519', publicKey);
      expect(multikey, startsWith('z6Mk'));
      expect(MultikeyUtil.decode(multikey), publicKey);
    });

    test('keyTypeFromMultikey', () {
      final multikey = MultikeyUtil.encode('Ed25519', Uint8List(32));
      expect(MultikeyUtil.keyTypeFromMultikey(multikey), 'Ed25519');
    });

    test('encode unsupported key type throws', () {
      expect(
        () => MultikeyUtil.encode('P-256', Uint8List(32)),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported key type'),
          ),
        ),
      );
    });

    test('decode unknown prefix throws', () {
      final encoded = Base58Btc.encodeMultibase([0x00, 0x00, 0x01, 0x02]);
      expect(
        () => MultikeyUtil.decode(encoded),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Unknown multicodec prefix'),
          ),
        ),
      );
    });

    // Byte-exact cross-check against a real Ed25519 multikey taken from the
    // vendored interop vectors: decode then re-encode must reproduce it
    // verbatim, proving base58btc + multikey framing match the other impls.
    test('decode/encode of a real vector multikey is byte-exact', () {
      const multikey = 'z6MkguAjXJepG2BJQA9cz5QTkqbKjQafddhYmsJZu8KJ7Coz';
      final raw = MultikeyUtil.decode(multikey);
      expect(raw, hasLength(32));
      expect(MultikeyUtil.encode('Ed25519', raw), multikey);
    });

    test('decode too short throws', () {
      final encoded = Base58Btc.encodeMultibase([0x01]);
      expect(
        () => MultikeyUtil.decode(encoded),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('too short'),
          ),
        ),
      );
    });
  });
}
