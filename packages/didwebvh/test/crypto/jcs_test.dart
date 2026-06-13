import 'dart:convert';

import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/crypto/jcs.dart';
import 'package:test/test.dart';

String canon(String json) => utf8.decode(Jcs.canonicalize(json));

void main() {
  group('Jcs', () {
    // Ports of the Java JcsTest cases.
    test('canonicalize sorts keys', () {
      expect(canon('{"b":2,"a":1}'), '{"a":1,"b":2}');
    });

    test('canonicalize nested objects', () {
      expect(
        canon('{"z":{"b":true,"a":false},"a":1}'),
        '{"a":1,"z":{"a":false,"b":true}}',
      );
    });

    test('canonicalize array preserves order', () {
      expect(canon('{"a":[3,1,2]}'), '{"a":[3,1,2]}');
    });

    test('canonicalize removes whitespace', () {
      expect(canon('{ "b" : 2 , "a" : 1 }'), '{"a":1,"b":2}');
    });

    test('canonicalize unicode', () {
      expect(canon('{"key":"€"}'), contains('€'));
    });

    test('canonicalize invalid json throws ValidationException', () {
      expect(
        () => Jcs.canonicalize('{not-json'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('JCS canonicalization failed'),
          ),
        ),
      );
    });

    // RFC 8785 §3.2.2.3 / ECMAScript Number::toString gating vectors.
    group('number serialization (RFC 8785)', () {
      const cases = <(num, String)>[
        (0, '0'),
        (1, '1'),
        (-1, '-1'),
        (100, '100'),
        // Trailing-zero integers stay in plain form up to 10^21.
        (1e19, '10000000000000000000'),
        // Fractions, including the small-exponent boundary.
        (0.1, '0.1'),
        (0.5, '0.5'),
        (1234.5, '1234.5'),
        // Exponential boundaries.
        (1e21, '1e+21'),
        (1e-7, '1e-7'),
        (1.5e22, '1.5e+22'),
      ];
      for (final (input, expected) in cases) {
        test('$input -> $expected', () {
          expect(canon('{"n":$input}'), '{"n":$expected}');
        });
      }

      test('negative zero normalizes to 0', () {
        expect(canon('{"n":-0.0}'), '{"n":0}');
      });
    });

    // Cases whose expected output was produced by running the real Java
    // `Jcs.canonicalize` (erdtman's JsonCanonicalizer, the same library Java
    // uses) and confirmed byte-for-byte. They pin behaviour the simpler cases
    // above don't exercise: UTF-16-code-unit key ordering, surrogate pairs,
    // >2^53 integer rounding, and control-character escaping.
    group('verified against erdtman/Java output', () {
      test('keys sort by code unit (digits, case, underscore)', () {
        expect(
          canon('{"B":1,"a":2,"10":3,"2":4,"Z":5,"_":6}'),
          '{"10":3,"2":4,"B":1,"Z":5,"_":6,"a":2}',
        );
      });

      test('keys sort by code unit (unicode beyond ASCII)', () {
        expect(
          canon('{"é":1,"e":2,"€":3,"z":4}'),
          '{"e":2,"z":4,"é":1,"€":3}',
        );
      });

      test('surrogate-pair (emoji) keys and values', () {
        expect(canon('{"😀":"😃","a":1}'), '{"a":1,"😀":"😃"}');
      });

      test('nested array of objects sorts inner keys', () {
        expect(
          canon('{"arr":[{"y":1,"x":2},{"b":[3,2,1]}],"k":null}'),
          '{"arr":[{"x":2,"y":1},{"b":[3,2,1]}],"k":null}',
        );
      });

      test('integers beyond 2^53 round as IEEE-754 doubles (as Java does)', () {
        expect(canon('{"n":9007199254740993}'), '{"n":9007199254740992}');
      });

      test('control characters use the minimal escaping', () {
        // \" \\ \n \t are the short escapes; the canonical output re-escapes
        // to exactly the same text as this input.
        const escaped = r'{"s":"a\"b\\c\n\t"}';
        expect(canon(escaped), escaped);
      });
    });

    test('canonicalizeValue canonicalizes a decoded map directly', () {
      // The idiomatic Dart entry point: callers hold a decoded structure and
      // canonicalize it without an encode/decode round-trip.
      final value = <String, Object?>{'b': 2, 'a': 1};
      expect(utf8.decode(Jcs.canonicalizeValue(value)), '{"a":1,"b":2}');
    });

    test('canonicalizeValue equals canonicalize(String) for the same JSON', () {
      // Skipping the round-trip must not change a single byte: the
      // decoded-value path and the string path produce identical output.
      final value = <String, Object?>{
        'versionId': 'v',
        'nested': [
          {'z': 1, 'a': true, 'n': null},
          'string',
          42,
        ],
      };
      expect(
        Jcs.canonicalizeValue(value),
        Jcs.canonicalize(jsonEncode(value)),
      );
    });
  });
}
