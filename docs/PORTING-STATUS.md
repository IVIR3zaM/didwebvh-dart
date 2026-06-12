# Porting Status — index

Small index of the porting plan. **This is the only plan file an agent reads on every run** to find the next
task; the full detail for one iteration lives in its own file under [`iterations/`](iterations/), read only
when that iteration is active. Workflow rules are in [`PORTING-GUIDE.md`](PORTING-GUIDE.md) (read once).

**Golden rule:** identical behaviour to the Java reference. Read the Java source for any behaviour question;
the shared test vectors are the cross-language contract. Status flow: `[ ]` not started → `[~]` in progress →
`[x]` done. Only **one** `[~]` at a time. Only a **human** sets `[x]` (after review + commit).

| St. | # | Iteration | Detail |
|-----|---|-----------|--------|
| [x] | 0 | Repository scaffolding (pub workspace, CI, lint, codecov) | [iterations/00-scaffolding.md](iterations/00-scaffolding.md) |
| [x] | 1 | Vendor shared test vectors & spec | [iterations/01-test-vectors.md](iterations/01-test-vectors.md) |
| [x] | 2 | Crypto primitives (JCS, multihash, base58btc, multikey) | [iterations/02-crypto-primitives.md](iterations/02-crypto-primitives.md) |
| [x] | 3 | Model classes + exceptions | [iterations/03-model.md](iterations/03-model.md) |
| [ ] | 4 | Signing — async `Signer`, proof gen/verify | [iterations/04-signing.md](iterations/04-signing.md) |
| [ ] | 5 | SCID, entry-hash & pre-rotation generators | [iterations/05-scid-entryhash-prerotation.md](iterations/05-scid-entryhash-prerotation.md) |
| [ ] | 6 | DID creation | [iterations/06-create.md](iterations/06-create.md) |
| [ ] | 7 | DID URL parsing & DID-to-HTTPS | [iterations/07-url.md](iterations/07-url.md) |
| [ ] | 8 | Log-chain validation & witness | [iterations/08-validation-witness.md](iterations/08-validation-witness.md) |
| [ ] | 9 | DID resolution | [iterations/09-resolve.md](iterations/09-resolve.md) |
| [ ] | 10 | Update, migration & deactivation | [iterations/10-update-migrate-deactivate.md](iterations/10-update-migrate-deactivate.md) |
| [ ] | 11 | Parallel did:web publishing | [iterations/11-didweb.md](iterations/11-didweb.md) |
| [ ] | 12 | `didwebvh_signing_local` package | [iterations/12-signing-local.md](iterations/12-signing-local.md) |
| [ ] | 13 | Wizard CLI | [iterations/13-wizard.md](iterations/13-wizard.md) |
| [ ] | 14 | Interop & quality finalization | [iterations/14-interop-quality.md](iterations/14-interop-quality.md) |

Iterations are dependency-ordered: an iteration may only start when every earlier one it builds on is `[x]`.

## Progress log

One line per finished iteration (human fills in after committing).

| Date | # | Commit | Java ref tag |
|------|---|--------|--------------|
|      |   |        |              |
