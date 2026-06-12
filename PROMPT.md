# Run the Next Porting Iteration

This repository is a **faithful Dart port** of the reference Java library `didwebvh-java`. Work proceeds one
iteration at a time. Copy the prompt below into an AI agent (Claude Code, Cursor, etc.) to execute the next
iteration. The agent finds the next iteration from a small index, reads only that iteration's detail file,
ports it from the Java reference, runs the gate, and **stops for human review** — it never commits.

> **Token discipline:** the plan is split so you never read it all. `docs/PORTING-STATUS.md` is a tiny index
> (the only plan file read every run); each iteration's full detail lives in its own `docs/iterations/NN-*.md`
> file, read only when that iteration is active.

> **Before you start, make sure the Java reference is present** at `reference/didwebvh-java/`. If it is
> missing, follow [`reference/README.md`](reference/README.md) first.

---

## Prompt

```
You are porting the Java library `didwebvh-java` to Dart in this repository (`didwebvh-dart`).
Goal: IDENTICAL BEHAVIOUR to the Java reference. Work the next unfinished iteration only.

Read as little as possible. Do NOT read the whole docs tree.

1. Confirm reference/didwebvh-java/ exists; if not, stop and point to reference/README.md.
   If you have not read them THIS SESSION, skim docs/PORTING-GUIDE.md and docs/PORTING-DECISIONS.md
   once (they hold the workflow + the allowed deltas). Otherwise skip them.

2. Open ONLY docs/PORTING-STATUS.md (it is small). Find the first iteration marked [ ].
   - If one is already [~], stop and report it (one in flight at a time).
   - If all are [x], report no work remains.

3. Open ONLY that iteration's detail file: docs/iterations/NN-*.md (linked from the table).
   Do not open the other iterations' files.

4. In docs/PORTING-STATUS.md, change ONLY that iteration's box [ ] -> [~] (one-line edit).

5. Read ONLY what this iteration's detail file names:
   - the listed Java source/test files under reference/didwebvh-java/,
   - Dart files from iterations already [x] that this one builds on,
   - the spec TXT (docs/spec/Webvh v1.0.txt) ONLY for the exact requirement in question
     (summarize it briefly; do not quote at length).

6. Port faithfully, small patches, one Java class/concern at a time:
   - When behaviour is unclear, READ THE JAVA SOURCE. Don't guess, redesign, or "improve".
   - Preserve names (PascalCase classes), file naming (snake_case .dart), and visibility
     (package-private under lib/src/; only the barrel re-exports public API).
   - Apply ONLY deltas in PORTING-DECISIONS.md (async Signer; dart:convert + hand-written
     toJson/fromJson; the listed package substitutions). NEVER use the pub.dev `canonical_json`
     package — it is not RFC 8785.
   - Byte-exact primitives (JCS, multihash, base58btc-multibase, entry hash, SCID,
     eddsa-jcs-2022 proof) MUST produce the same bytes as Java.
   - Prefer unified diffs; new files only when unavoidable.

7. Stay strictly within this iteration. Implement a tiny missing dependency minimally and note it.
   If Java seems to contradict the spec, or there's a real tradeoff, STOP and present options.

8. Add/port tests for all new behaviour. The shared vectors in test/vectors/ are the contract —
   never edit them; make the Dart code match them.

9. Run the gate and report the REAL result (pass or fail, with output):
       dart pub get && dart analyze && dart test
   Gather coverage for didwebvh_core when the iteration touches covered code.

10. Update CHANGELOG.md [Unreleased]. Add brief Implementation Notes to the iteration's
    detail file. Leave the box at [~]; the HUMAN flips [~] -> [x], commits, and adds a
    Progress-log line in PORTING-STATUS.md. Do NOT commit.

11. Final output:
    - 3-5 bullet summary; list of changed/added files; minimal diffs (not whole files);
      the gate result; a SUGGESTED Conventional Commit message; review notes / warnings.

Never commit. Never set [x] yourself. Never edit the shared test vectors.
Never restate large portions of repository files or the specification.
```
