import 'package:didwebvh_core/src/model/did_document.dart';
import 'package:test/test.dart';

void main() {
  group('DidDocument', () {
    test('reads single string or array controller', () {
      final j = <String, Object?>{
        'id': 'did:webvh:QmSCID:example.com',
        'controller': 'did:key:z6MkA',
      };
      final doc = DidDocument(j);
      expect(doc.id, 'did:webvh:QmSCID:example.com');
      expect(doc.controller, ['did:key:z6MkA']);

      j['controller'] = ['did:key:z6MkA', 'did:key:z6MkB'];
      expect(
        DidDocument(j).controller,
        ['did:key:z6MkA', 'did:key:z6MkB'],
      );
    });

    test('withId returns new instance and does not mutate original', () {
      final j = <String, Object?>{'id': 'did:webvh:a:example.com'};
      final original = DidDocument(j);
      final updated = original.withId('did:webvh:b:example.com');
      expect(updated.id, 'did:webvh:b:example.com');
      expect(original.id, 'did:webvh:a:example.com');
      expect(updated, isNot(original));
    });

    test('null json yields an empty document', () {
      final doc = DidDocument(null);
      expect(doc.asJsonObject(), isEmpty);
      expect(doc.id, isNull);
      expect(doc.controller, isNull);
      expect(doc.alsoKnownAs, isNull);
      expect(doc.verificationMethod, isNull);
      expect(doc.service, isNull);
    });

    test('reads alsoKnownAs, verificationMethod and service', () {
      final vm = [
        <String, Object?>{'id': '#k1'},
      ];
      final svc = [
        <String, Object?>{'id': '#svc', 'type': 'LinkedDomains'},
      ];
      final doc = DidDocument(<String, Object?>{
        'alsoKnownAs': ['did:web:example.com'],
        'verificationMethod': vm,
        'service': svc,
      });
      expect(doc.alsoKnownAs, ['did:web:example.com']);
      expect(doc.verificationMethod, vm);
      expect(doc.service, svc);
    });

    test('equal documents share a hashCode; deep equality holds', () {
      final a = DidDocument(<String, Object?>{
        'id': 'did:webvh:a:example.com',
        'controller': ['x', 'y'],
      });
      final b = DidDocument(<String, Object?>{
        'id': 'did:webvh:a:example.com',
        'controller': ['x', 'y'],
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
