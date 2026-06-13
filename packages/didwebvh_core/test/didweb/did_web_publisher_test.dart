import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/didweb/did_web_publisher.dart';
import 'package:didwebvh_core/src/model/did_document.dart';
import 'package:test/test.dart';

void main() {
  const scid = 'QmfGEUAcMpzo25kF2Rhn8L2qMSAzMGeyq8kJEMabAxQzK3';
  const didWebVh = 'did:webvh:$scid:example.com';
  const didWebVhPath = 'did:webvh:$scid:example.com:dids:issuer';
  const didWeb = 'did:web:example.com';
  const didWebPath = 'did:web:example.com:dids:issuer';

  Map<String, Object?> baseDoc(String did) => <String, Object?>{
        '@context': 'https://www.w3.org/ns/did/v1',
        'id': did,
        'controller': did,
      };

  List<Object?> services(DidDocument result) =>
      result.asJsonObject()['service']! as List<Object?>;

  Map<String, Object?>? findServiceById(List<Object?> svcs, String id) {
    for (final el in svcs) {
      if (el is Map && el['id'] == id) {
        return el.cast<String, Object?>();
      }
    }
    return null;
  }

  test('convertsIdAndControllerFromWebvhToWeb', () {
    final result = DidWebPublisher.toDidWeb(DidDocument(baseDoc(didWebVh)));

    expect(result.id, didWeb);
    expect(result.asJsonObject()['controller'], didWeb);
  });

  test('rewritesVerificationMethodReferences', () {
    final doc = baseDoc(didWebVh);
    doc['verificationMethod'] = <Object?>[
      <String, Object?>{
        'id': '$didWebVh#key-1',
        'type': 'Multikey',
        'controller': didWebVh,
        'publicKeyMultibase': 'z6MkhaXgBZDvotDkL5257faiztiGi',
      },
    ];

    final result = DidWebPublisher.toDidWeb(DidDocument(doc));

    final outVm = (result.asJsonObject()['verificationMethod']! as List)[0]
        as Map<String, Object?>;
    expect(outVm['id'], '$didWeb#key-1');
    expect(outVm['controller'], didWeb);
  });

  test('addsImplicitFilesAndWhoisServicesWhenAbsent', () {
    final result = DidWebPublisher.toDidWeb(DidDocument(baseDoc(didWebVh)));

    final svcs = services(result);
    expect(svcs, hasLength(2));

    final files = findServiceById(svcs, '$didWeb#files')!;
    expect(files['type'], 'relativeRef');
    expect(files['serviceEndpoint'], 'https://example.com/');

    final whois = findServiceById(svcs, '$didWeb#whois')!;
    expect(whois['type'], 'LinkedVerifiablePresentation');
    expect(
      whois['@context'],
      'https://identity.foundation/linked-vp/contexts/v1',
    );
    expect(whois['serviceEndpoint'], 'https://example.com/whois.vp');
  });

  test('servicesEndpointsUsePathAndPortFromDomain', () {
    const did = 'did:webvh:$scid:example.com%3A3000:dids:issuer';
    final result = DidWebPublisher.toDidWeb(DidDocument(baseDoc(did)));

    final svcs = services(result);
    final files =
        findServiceById(svcs, 'did:web:example.com%3A3000:dids:issuer#files')!;
    expect(files['serviceEndpoint'], 'https://example.com:3000/dids/issuer/');
    final whois =
        findServiceById(svcs, 'did:web:example.com%3A3000:dids:issuer#whois')!;
    expect(
      whois['serviceEndpoint'],
      'https://example.com:3000/dids/issuer/whois.vp',
    );
  });

  test('doesNotOverrideExplicitFilesOrWhoisService', () {
    final doc = baseDoc(didWebVh);
    doc['service'] = <Object?>[
      <String, Object?>{
        'id': '#files',
        'type': 'relativeRef',
        'serviceEndpoint': 'https://files.example.com/custom/',
      },
      <String, Object?>{
        'id': '$didWebVh#whois',
        'type': 'LinkedVerifiablePresentation',
        'serviceEndpoint': 'https://whois.example.com/custom.vp',
      },
    ];

    final result = DidWebPublisher.toDidWeb(DidDocument(doc));

    final out = services(result);
    expect(out, hasLength(2));
    final files = findServiceById(out, '#files')!;
    expect(files['serviceEndpoint'], 'https://files.example.com/custom/');
    final whois = findServiceById(out, '$didWeb#whois')!;
    expect(whois['serviceEndpoint'], 'https://whois.example.com/custom.vp');
  });

  test('addsDidWebVhToAlsoKnownAs', () {
    final result = DidWebPublisher.toDidWeb(DidDocument(baseDoc(didWebVh)));

    final aka = result.asJsonObject()['alsoKnownAs']! as List;
    expect(aka, hasLength(1));
    expect(aka[0], didWebVh);
  });

  test('preservesExistingAlsoKnownAsEntriesAndAddsWebvh', () {
    final doc = baseDoc(didWebVh);
    doc['alsoKnownAs'] = <Object?>['did:example:alt'];

    final result = DidWebPublisher.toDidWeb(DidDocument(doc));

    final out = result.asJsonObject()['alsoKnownAs']! as List;
    expect(out, hasLength(2));
    expect(out[0], 'did:example:alt');
    expect(out[1], didWebVh);
  });

  test('deduplicatesAlsoKnownAsAndRemovesSelfDidWeb', () {
    final doc = baseDoc(didWebVh);
    doc['alsoKnownAs'] = <Object?>[
      didWebVh,
      didWeb,
      'did:example:alt',
      'did:example:alt',
    ];

    final result = DidWebPublisher.toDidWeb(DidDocument(doc));

    final out = result.asJsonObject()['alsoKnownAs']! as List;
    expect(out, hasLength(2));
    expect(out[0], 'did:example:alt');
    expect(out[1], didWebVh);
  });

  test('toDidWebUrlDelegatesToTransformer', () {
    expect(DidWebPublisher.toDidWebUrl(didWebVh), didWeb);
    expect(DidWebPublisher.toDidWebUrl(didWebVhPath), didWebPath);
  });

  test('throwsOnNullDocument', () {
    expect(
      () => DidWebPublisher.toDidWeb(null),
      throwsA(isA<ValidationException>()),
    );
  });

  test('throwsOnMissingId', () {
    final empty = DidDocument(<String, Object?>{});
    expect(
      () => DidWebPublisher.toDidWeb(empty),
      throwsA(isA<ValidationException>()),
    );
  });
}
