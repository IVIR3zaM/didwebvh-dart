import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('exception hierarchy', () {
    test('subclasses extend DidWebVhException and carry message/cause', () {
      final cause = StateError('boom');
      expect(ValidationException('v'), isA<DidWebVhException>());
      expect(SigningException('s'), isA<DidWebVhException>());
      expect(UrlParseException('u'), isA<DidWebVhException>());
      expect(ResolutionException('r'), isA<DidWebVhException>());

      final e = DidWebVhException('msg', cause);
      expect(e.message, 'msg');
      expect(e.cause, same(cause));
      expect(e.toString(), 'DidWebVhException: msg');
      expect(SigningException('s').toString(), 'SigningException: s');
      expect(UrlParseException('u').toString(), 'UrlParseException: u');
      expect(ValidationException('v').toString(), 'ValidationException: v');
    });
  });

  group('ResolutionException', () {
    test('plain message has no error or problem details', () {
      final e = ResolutionException('nope');
      expect(e.error, isNull);
      expect(e.problemDetails, isNull);
      expect(e.toString(), 'ResolutionException: nope');
    });

    test('withError derives RFC 9457 problem details', () {
      final e = ResolutionException.withError('bad did', 'invalidDid');
      expect(e.error, 'invalidDid');
      expect(e.problemDetails, {
        'type': 'urn:didwebvh:error:invalidDid',
        'title': 'Invalid DID',
        'detail': 'bad did',
      });
    });

    test('problemDetails returns a defensive copy', () {
      final e = ResolutionException.withError('x', 'notFound');
      final first = e.problemDetails!..['title'] = 'mutated';
      expect(first['title'], 'mutated');
      expect(e.problemDetails!['title'], 'Not Found');
    });

    test('known error codes map to titles', () {
      String title(String code) =>
          ResolutionException.withError('m', code).problemDetails!['title']!
              as String;
      expect(title('notFound'), 'Not Found');
      expect(title('httpError'), 'HTTP Error');
      expect(title('custom'), 'custom');
    });

    test('empty error code falls back to unknown/Resolution Error', () {
      final e = ResolutionException.withError('m', '');
      expect(e.problemDetails!['type'], 'urn:didwebvh:error:unknown');
      expect(e.problemDetails!['title'], 'Resolution Error');
    });

    test('problem type sanitizes unsafe characters', () {
      final e = ResolutionException.withError('m', 'weird code/with:chars');
      expect(
        e.problemDetails!['type'],
        'urn:didwebvh:error:weird-code-with-chars',
      );
    });

    test('carries a cause', () {
      final cause = StateError('io');
      final e = ResolutionException.withError('m', 'httpError', cause);
      expect(e.cause, same(cause));
    });
  });
}
