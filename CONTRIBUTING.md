# Contributing to didwebvh-dart

Thanks for helping build the Dart port of `did:webvh`. This project is a **faithful translation** of the Java
reference [`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java) — the goal is identical
behaviour, proven by the same shared test vectors.

## Before you start

- Read [`docs/PORTING-GUIDE.md`](docs/PORTING-GUIDE.md) (how the port works, the human-review rule),
  [`docs/AGENTS.md`](docs/AGENTS.md), and [`docs/PORTING-DECISIONS.md`](docs/PORTING-DECISIONS.md).
- Set up the git-ignored Java reference: [`reference/README.md`](reference/README.md).
- Pick the next `[ ]` iteration in [`docs/PORTING-STATUS.md`](docs/PORTING-STATUS.md) (detail in
  [`docs/iterations/`](docs/iterations/)). Only one iteration is in flight at a time.

## Working agreement

- **Port faithfully.** When behaviour is unclear, read the Java source — don't redesign. The only allowed
  departures from Java are documented in `PORTING-DECISIONS.md` (notably the async `Signer`).
- **Never edit the shared test vectors** (`packages/didwebvh_core/test/vectors/`). They are the cross-language
  contract; make the code match them.
- **Never use the pub.dev `canonical_json` package** — it is not RFC 8785 and silently breaks interop.
- **Keep dependencies minimal** — don't add a package for a 20-line task.
- **Small patches**, one concern at a time; `snake_case` files, PascalCase classes, package-private under
  `lib/src/`.

## Verification gate

Every change must pass, and you must report the real result:

```bash
tool/verify.sh            # pub get + analyze (--fatal-infos) + every package's tests
tool/verify.sh --coverage # also emit packages/didwebvh_core/coverage/lcov.info
```

This is the Dart analog of Java's `./mvnw clean verify`. Coverage ≥ 80% on `didwebvh_core`
(`signing_local` and `wizard` are excluded).

The gate also runs automatically on every commit via the tracked pre-commit hook in
[`.githooks/`](.githooks/). Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

A commit is blocked unless `tool/verify.sh` reports `VERIFY OK`. Use `git commit --no-verify`
only to bypass it deliberately.

## Commits and review

- Use [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat(core): port JCS`).
- Update the `[Unreleased]` section of `CHANGELOG.md` with your change.
- **Every commit requires a human review.** AI agents must stop after proposing a commit message and must not
  commit or mark an iteration `[x]`. A human reviews the diff against the Java reference and the spec,
  commits, flips the iteration to `[x]`, and records the commit in the Progress log.

## Reporting a Java/spec disagreement

If you believe the Java reference contradicts `docs/spec/Webvh v1.0.txt`, **stop and open an issue / note it
in your hand-off** rather than silently choosing. The spec is the ultimate authority, but such cases deserve
explicit human review.
