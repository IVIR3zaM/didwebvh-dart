# Java reference source

This directory holds the **read-only reference implementation** that the Dart port is translated from:
[`didwebvh-java`](https://github.com/decentralized-identity/didwebvh-java).

The cloned source is **git-ignored** (see the repo root `.gitignore`) so it never enters this repository's
history — it is reference material, not part of the Dart package. This `README.md` is the only committed file
in `reference/`.

## Set it up (once)

From the repository root:

```bash
git clone https://github.com/decentralized-identity/didwebvh-java reference/didwebvh-java
```

You should end up with `reference/didwebvh-java/` containing the Java sources, e.g.:

- `reference/didwebvh-java/didwebvh-core/src/main/java/...` — the code to port
- `reference/didwebvh-java/didwebvh-core/src/test/resources/test-vectors/` and `.../interop/` — the shared
  test vectors (copied verbatim into `packages/didwebvh_core/test/vectors/` during Iteration 1)
- `reference/didwebvh-java/docs/` — the Java AGENTS/ARCHITECTURE/spec docs

## Pin a version (recommended)

Port against a known Java release so the reference doesn't drift mid-port. Check out the tag the port targets,
for example:

```bash
cd reference/didwebvh-java
git checkout v0.3.1   # the Java release this port is based on
```

Record the pinned tag/commit in `CHANGELOG.md` (or the Progress log in `docs/PORTING-STATUS.md`) so it is
clear which Java revision the Dart code corresponds to.

## How agents use it

Agents read this folder to answer any "how does Java do X?" question while porting — but they **never** copy
Java files into the Dart packages (except the shared test vectors, which are deliberately vendored verbatim).
The agent prompt in `../PROMPT.md` checks that this folder exists before starting work.
