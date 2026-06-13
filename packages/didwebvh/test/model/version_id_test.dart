import 'package:didwebvh/src/core/exceptions.dart';
import 'package:didwebvh/src/model/version_id.dart';
import 'package:test/test.dart';

void main() {
  group('VersionId', () {
    test('parses number and hash', () {
      final v = VersionId.parse('1-QmHash');
      expect(v.versionNumber, 1);
      expect(v.entryHash, 'QmHash');
      expect(v.toString(), '1-QmHash');
      expect(v.isPreliminary, isFalse);
    });

    test('parses multi-digit number and hash with dashes', () {
      final v = VersionId.parse('42-abc-def');
      expect(v.versionNumber, 42);
      expect(v.entryHash, 'abc-def');
    });

    test('rejects invalid input', () {
      expect(() => VersionId.parse(null), throwsA(isA<ValidationException>()));
      expect(() => VersionId.parse(''), throwsA(isA<ValidationException>()));
      expect(
        () => VersionId.parse('nohash'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => VersionId.parse('-hash'),
        throwsA(isA<ValidationException>()),
      );
      expect(() => VersionId.parse('1-'), throwsA(isA<ValidationException>()));
      expect(
        () => VersionId.parse('x-hash'),
        throwsA(isA<ValidationException>()),
      );
      expect(() => VersionId.of(0, 'h'), throwsA(isA<ValidationException>()));
      expect(() => VersionId.of(1, ''), throwsA(isA<ValidationException>()));
    });

    test('preliminary uses scid as raw string', () {
      final v = VersionId.preliminary('QmSCID');
      expect(v.isPreliminary, isTrue);
      expect(v.toString(), 'QmSCID');
      expect(v.entryHash, 'QmSCID');
    });

    test('equals and hashCode', () {
      expect(VersionId.of(1, 'h'), VersionId.of(1, 'h'));
      expect(VersionId.of(1, 'h'), isNot(VersionId.of(2, 'h')));
      expect(VersionId.of(1, 'h').hashCode, VersionId.of(1, 'h').hashCode);
    });
  });
}
