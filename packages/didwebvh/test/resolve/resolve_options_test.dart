import 'package:didwebvh/didwebvh.dart';
import 'package:test/test.dart';

/// Tests the `ResolveOptions` public surface: the three interchangeable call
/// styles (fluent / cascade / named parameters), defaults, and the helpers
/// `withFallbacks` / `hasMultipleVersionSelectors`.
void main() {
  test('fluent, cascade, and named-parameter styles are equivalent', () {
    final fluent = ResolveOptions()
        .versionNumber(2)
        .witnessFetchMode(WitnessFetchMode.whenRequired);

    final cascade = ResolveOptions()
      ..versionNumber(2)
      ..witnessFetchMode(WitnessFetchMode.whenRequired);

    final named = ResolveOptions(
      versionNumber: 2,
      witnessFetchMode: WitnessFetchMode.whenRequired,
    );

    for (final o in [fluent, cascade, named]) {
      expect(o.versionNumberValue, 2);
      expect(o.versionIdValue, isNull);
      expect(o.versionTimeValue, isNull);
      expect(o.witnessFetchModeValue, WitnessFetchMode.whenRequired);
      expect(o.hasMultipleVersionSelectors, isFalse);
    }
  });

  test('defaults have no selector and proactive witness fetch', () {
    final o = ResolveOptions.defaults();
    expect(o.versionIdValue, isNull);
    expect(o.versionTimeValue, isNull);
    expect(o.versionNumberValue, isNull);
    expect(o.witnessFetchModeValue, WitnessFetchMode.proactive);
    expect(o.hasMultipleVersionSelectors, isFalse);
  });

  test('null witnessFetchMode resets to proactive', () {
    final o = ResolveOptions()
      ..witnessFetchMode(WitnessFetchMode.whenRequired)
      ..witnessFetchMode(null);
    expect(o.witnessFetchModeValue, WitnessFetchMode.proactive);
  });

  test('hasMultipleVersionSelectors detects more than one selector', () {
    expect(
      ResolveOptions(versionId: 'a', versionNumber: 1)
          .hasMultipleVersionSelectors,
      isTrue,
    );
    expect(
      ResolveOptions(versionId: 'a').hasMultipleVersionSelectors,
      isFalse,
    );
  });

  test('withFallbacks fills unset selectors but keeps this witness mode', () {
    final primary = ResolveOptions(versionId: 'primary'); // proactive (default)
    final fallback = ResolveOptions(
      versionTime: '2020-01-01T00:00:00Z',
      witnessFetchMode: WitnessFetchMode.whenRequired,
    );

    final merged = primary.withFallbacks(fallback);

    expect(merged.versionIdValue, 'primary');
    expect(merged.versionTimeValue, '2020-01-01T00:00:00Z');
    // The merged options keep `primary`'s fetch mode, not the fallback's.
    expect(merged.witnessFetchModeValue, WitnessFetchMode.proactive);
  });

  test('withFallbacks returns this when fallback is null', () {
    final o = ResolveOptions(versionId: 'x');
    expect(identical(o.withFallbacks(null), o), isTrue);
  });
}
