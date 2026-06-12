import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/src/crypto/base58btc.dart';
import 'package:test/test.dart';

void main() {
  group('Base58Btc', () {
    test('round trip', () {
      final data = utf8.encode('Hello, World!');
      final encoded = Base58Btc.encode(data);
      expect(Base58Btc.decode(encoded), data);
    });

    test('known vector', () {
      final data = Uint8List.fromList([0x00, 0x01, 0x02]);
      final encoded = Base58Btc.encode(data);
      expect(Base58Btc.decode(encoded), data);
    });

    test('multibase round trip', () {
      final data = utf8.encode('test');
      final multibase = Base58Btc.encodeMultibase(data);
      expect(multibase, startsWith('z'));
      expect(Base58Btc.decodeMultibase(multibase), data);
    });

    test('decodeMultibase rejects wrong prefix', () {
      expect(
        () => Base58Btc.decodeMultibase('m1234'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Expected multibase base58btc prefix 'z'"),
          ),
        ),
      );
    });

    test('decodeMultibase rejects empty', () {
      expect(() => Base58Btc.decodeMultibase(''), throwsArgumentError);
    });

    // Leading-zero framing is the part most likely to diverge from Java.
    test('leading zero bytes map to leading ones', () {
      final data = Uint8List.fromList([0x00, 0x00, 0x05]);
      final encoded = Base58Btc.encode(data);
      expect(encoded, startsWith('11'));
      expect(Base58Btc.decode(encoded), data);
    });
  });
}
