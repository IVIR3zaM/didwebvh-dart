# Porting Guide

How this repository is built: a **faithful, iterative Dart port** of the reference Java library
`didwebvh-java`, with a **human in the loop on every commit**. Read this once before your first iteration.

## What we are doing

We are reproducing `didwebvh-java` in Dart with **identical behaviour**. This is a *translation*, not a
redesign. The Java implementation is already correct, spec-aligned, and interop-tested; our job is to make
Dart do exactly the same thing — same bytes out of the cryptographic primitives, same validation outcomes,
same resolved documents — and to prove it with the **same shared test vectors**.

The only intentional departures from Java are the ones written down in
[`PORTING-DECISIONS.md`](PORTING-DECISIONS.md) (chiefly: the **async `Signer`**, `dart:convert` +
hand-written serialization, and the package substitutions). If you ever feel the urge to change something
that *isn't* in that document, stop and raise it instead.

## The three source-of-truth layers (in priority order)

1. **The shared test vectors** (`packages/didwebvh_core/test/vectors/`) — the cross-language contract. If the
   Dart output differs from a vector, the Dart code is wrong. Never edit a vector to make a test pass.
2. **The Java reference** (`reference/didwebvh-java/`) — for *how* something is implemented. When behaviour is
   unclear, read the Java source rather than guessing.
3. **The spec** (`docs/spec/Webvh v1.0.txt`) — the ultimate authority if Java and the spec ever disagree. If
   you find such a disagreement, **stop and report it** as a finding; don't silently pick a side.

## Setting up the Java reference

The Java source is used as a read-only reference and is **git-ignored** so it never lands in this repo's
history. Clone it once:

```bash
git clone https://github.com/decentralized-identity/didwebvh-java reference/didwebvh-java
```

See [`../reference/README.md`](../reference/README.md) for details and for pinning a specific Java version.
The agent prompt checks for this folder before doing any work.

## The verification gate

Every iteration — and **every change, however small** — must pass the one-shot gate, and you must report the
**real** result (including failures, with output):

```bash
tool/verify.sh          # the center of "nothing is broken" — run this after any change
```

This is the Dart analog of Java's `./mvnw clean verify`. It runs, in order:

- `dart pub get` (resolves the whole pub workspace),
- `dart analyze --fatal-infos` (zero issues; `very_good_analysis` is the rule set),
- `dart test` for **every** package that has a `test/` dir (all tests green, including the shared vectors).

It prints `VERIFY OK` on success or `VERIFY FAILED` (non-zero exit) on the first failing suite. Because
`dart test` is per-package in a pub workspace (running it from the root only prints help), always use the
script rather than hand-rolling the commands — that way any new `test/` folder is automatically included.

For `didwebvh_core`, collect coverage when the iteration touches covered code by adding `--coverage`; it writes
`packages/didwebvh_core/coverage/lcov.info`:

```bash
tool/verify.sh --coverage
```

The 80% Codecov gate applies to `didwebvh_core` only; `didwebvh_signing_local` and `didwebvh_wizard` are thin
adapters and are excluded, mirroring the Java project.

## Human review — required on every commit

**Nothing is committed without a human review.** This is a hard rule.

- The agent **ports, tests, and verifies**, then **stops**. In `PORTING-STATUS.md` it flips only the target
  iteration's box `[ ]` → `[~]`, and adds Implementation Notes to that iteration's `iterations/NN-*.md` file.
- The agent **proposes** a Conventional Commit message but **does not commit** and **does not** mark the
  iteration `[x]`.
- The **human** reviews the diff against the Java reference and the spec, then:
  - commits (using or adjusting the suggested message),
  - flips the iteration `[~]` → `[x]` in `PORTING-STATUS.md`,
  - and adds a line to the **Progress log** table at the bottom of
    [`PORTING-STATUS.md`](PORTING-STATUS.md) with the date and commit hash.

What a reviewer should check: does the Dart match the Java behaviour (not just "does it compile")? Do the
shared vectors pass? Are the only deltas the documented ones? Is the public surface (`lib/<pkg>.dart` barrel)
the intended one?

## Commit conventions

[Conventional Commits](https://www.conventionalcommits.org/), same as Java. Examples:

- `feat(core): port JCS canonicalization (RFC 8785)`
- `feat(core): port log-chain validation and witness verification`
- `test(core): vendor shared interop test vectors`
- `chore: scaffold pub workspace and CI`

Also update the `[Unreleased]` section of `CHANGELOG.md` as part of each iteration (Added / Changed / Fixed),
referencing the spec section or the ported Java class for non-obvious behaviour.

## Working discipline

- **One iteration in flight.** Only one `[~]` at a time; respect dependency order.
- **Small patches.** One Java class/concern per patch; prefer unified diffs.
- **Faithful naming.** PascalCase classes (unchanged from Java), `snake_case` files/packages, package-private
  under `lib/src/`, public surface only through the barrel.
- **No scope creep.** Stay inside the current iteration; note (don't fix) anything you spot elsewhere.
- **Keep dependencies minimal.** Don't add a package for a 20-line task — the same rule the Java project
  follows. The approved dependency set is in `PORTING-DECISIONS.md` §2.
