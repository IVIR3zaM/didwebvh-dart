# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/).

## Unreleased

## 0.1.2 - 2026-06-14

- `--version` now reports the package version from `pubspec.yaml` via a generated
  `lib/src/version.g.dart` (regenerate with `dart run tool/generate_version.dart`)
  instead of a hardcoded string, so it can no longer drift from the pubspec.

## 0.1.1 - 2026-06-13

- Packaging fixes (no API or behaviour change): restore the canonical
  Apache-2.0 `APPENDIX` block in `LICENSE` so pub.dev recognizes the license;
  require `didwebvh: ^0.1.1` and `didwebvh_signing_local: ^0.1.1`.

## 0.1.0 - 2026-06-13

- Initial release: a faithful Dart port of `didwebvh-java`'s `didwebvh-wizard`
  module. Interactive CLI (`didwebvh_wizard`) for create / update (modify,
  migrate, deactivate) / resolve / export-`did:web`, with `--dir` and
  `--action` options. Witness key store and proof collection included.
