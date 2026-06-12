import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/crypto/multihash.dart';
import 'package:test/test.dart';

void main() {
  group('MultihashUtil', () {
    test('hashAndEncode produces valid multihash', () {
      final multihash = MultihashUtil.hashAndEncode(utf8.encode('hello'));
      expect(multihash[0] & 0xFF, MultihashUtil.sha2256Code);
      expect(multihash[1] & 0xFF, MultihashUtil.sha2256Length);
      expect(multihash, hasLength(2 + 32));
    });

    test('extractAlgorithm', () {
      final multihash = MultihashUtil.hashAndEncode(utf8.encode('test'));
      expect(
        MultihashUtil.extractAlgorithm(multihash),
        MultihashUtil.sha2256Code,
      );
    });

    test('extractDigest matches sha256', () {
      final data = utf8.encode('test');
      final multihash = MultihashUtil.hashAndEncode(data);
      expect(
        MultihashUtil.extractDigest(multihash),
        MultihashUtil.sha256(data),
      );
    });

    test('encode and extract round trip', () {
      final digest = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final multihash = MultihashUtil.encode(MultihashUtil.sha2256Code, digest);
      expect(
        MultihashUtil.extractAlgorithm(multihash),
        MultihashUtil.sha2256Code,
      );
      expect(MultihashUtil.extractDigest(multihash), digest);
    });

    test('extract from too short throws', () {
      expect(
        () => MultihashUtil.extractAlgorithm([0x12]),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MultihashUtil.extractDigest([0x12]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('extractDigest length mismatch throws', () {
      expect(
        () => MultihashUtil.extractDigest([0x12, 0x20, 0x01]),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('mismatch'),
          ),
        ),
      );
    });
  });
}
