# didwebvh_wizard

[![pub package](https://img.shields.io/pub/v/didwebvh_wizard.svg)](https://pub.dev/packages/didwebvh_wizard)

Interactive command-line wizard for [did:webvh](https://didwebvh.info/) DIDs:
create, update (modify / migrate / deactivate), resolve (over HTTPS or from a
local file), and export the parallel `did:web` document.

A faithful port of the reference Java library
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java)
(`didwebvh-wizard` module).

## Install & run

### From pub.dev (latest stable)

```bash
dart pub global activate didwebvh_wizard
didwebvh_wizard            # interactive menu in the current directory
```

### From source (this repo)

```bash
cd packages/didwebvh_wizard
dart pub get              # first time only
dart run                  # interactive menu (≡ dart run bin/didwebvh_wizard.dart)
```

### Options

Both forms accept the same options (with `dart run`, pass them after the script
name, e.g. `dart run bin/didwebvh_wizard.dart --action create`):

```bash
didwebvh_wizard --dir ./my-did      # working directory for DID files
didwebvh_wizard --action create     # skip the menu: create | update | resolve | export
didwebvh_wizard --help
```

## License

Apache-2.0.
