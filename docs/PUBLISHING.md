# Publishing to pub.dev

How to publish the three packages (`didwebvh`, `didwebvh_signing_local`, `didwebvh_wizard`) for the first
time and on every release after that. Start here if you have **no pub.dev account yet**.

There are two phases: a **one-time setup + first manual publish** (because automated publishing can only be
configured on a package that already exists), and then **automated releases** via the tag-triggered GitHub
Actions workflow ([`.github/workflows/publish.yml`](../.github/workflows/publish.yml)).

---

## Phase 0 — Create your pub.dev account (one time)

1. pub.dev uses a **Google account** to sign in — there is no separate password. Go to
   <https://pub.dev>, click **Sign in** (top right), and authenticate with the Google account you want to own
   the packages. Signing in the first time creates your pub.dev publisher identity.
2. Make sure that Google account's email is one you control — pub.dev shows it as the uploader and sends
   publishing notifications there.
3. **(Optional, recommended for a project that will be donated to DIF.)** Create a **verified publisher** tied to
   a domain you control, so the packages display a "verified publisher" badge instead of a personal email:
   - pub.dev → your avatar → **Create publisher** → enter a domain (e.g. `didwebvh.info` or your org domain).
   - Verify domain ownership when prompted (pub.dev walks you through a Google Search Console verification).
   - You can publish under a personal account now and **transfer** packages to the verified publisher later
     (package Admin → *Transfer to a publisher*) — so the lack of a verified publisher is not a blocker for
     v0.1.0. Decide based on the donation timeline.

> If you do not yet control the final publisher (e.g. you are waiting on the DIF donation), it is fine to publish
> v0.1.0 under your personal account and transfer ownership afterwards. Package names are first-come, so
> publishing now also **reserves the three names**.

## Phase 1 — Authenticate the CLI (one time per machine)

```bash
dart pub login
```

This opens a browser to authorize the same Google account. Credentials are cached locally
(`~/.config/dart/pub-credentials.json`), so you only do this once per machine.

## Phase 2 — First manual publish (v0.1.0)

The packages depend on each other, and the pub.dev server validates that every dependency already exists when
you publish. **Publish in this exact order**, waiting for each to go live (usually within a minute) before the
next:

```
1. didwebvh
2. didwebvh_signing_local   # depends on didwebvh: ^0.1.0
3. didwebvh_wizard          # depends on both of the above
```

For each package, from the repo root:

```bash
# 1. core
(cd packages/didwebvh && dart pub publish)
# …confirm it appears at https://pub.dev/packages/didwebvh, then:

# 2. signing_local
(cd packages/didwebvh_signing_local && dart pub publish)

# 3. wizard
(cd packages/didwebvh_wizard && dart pub publish)
```

Notes:
- `dart pub publish` runs the same validation as `--dry-run` and then uploads. Review the file list it prints;
  type `y` to confirm.
- Publish from a **clean git state** (commit first) — otherwise you get a "modified files" warning.
- Publishing is **irreversible**: a version number can never be re-used, and a published version can only be
  *retracted* (hidden from new resolutions), not deleted. Double-check the version (`0.1.0`) before confirming.
- If a dependency isn't live yet when you publish the next package, the server rejects it — just wait and retry.

## Phase 3 — Enable automated publishing (one time per package)

Once each package exists on pub.dev, wire it to this repo so future releases publish themselves from a single
git tag — no credentials or secrets stored anywhere (pub.dev trusts GitHub's OIDC token; see
[*How OIDC publishing works*](#how-oidc-publishing-works-no-secrets) below).

The three packages are versioned **in lockstep** (one shared version number) and released by **one master tag**
`vX.Y.Z`. So all three use the *same* tag pattern. For **each** of the three packages:

1. Open `https://pub.dev/packages/<package>/admin` (you must be an uploader/admin).
2. Under **Automated publishing → Enable publishing from GitHub Actions**:
   - **Repository:** `IVIR3zaM/didwebvh-dart`
   - **Tag pattern:** `v{{version}}` (the same value for all three packages). `{{version}}` expands to each
     package's own `pubspec.yaml` version — and since the three share a version, the master tag `vX.Y.Z` matches
     all of them.
3. Save. No GitHub secret is required — [`publish.yml`](../.github/workflows/publish.yml) already requests the
   `id-token: write` permission that OIDC needs.

## Phase 4 — Release a new version (every time after setup)

Releases are coordinated: bump **all three** `pubspec.yaml` versions to the same number, update the changelogs,
commit, then push **one** master tag:

```bash
# 1. set version: 0.1.1 in all three packages/*/pubspec.yaml, update CHANGELOGs, commit. then:
git tag v0.1.1
git push origin v0.1.1
```

The tag push triggers [`publish.yml`](../.github/workflows/publish.yml), which publishes all three packages **in
dependency order** (core → signing_local → wizard) as separate jobs. Each dependent job first waits for its
dependency's new version to be live on pub.dev (via [`tool/wait-for-pub.sh`](../tool/wait-for-pub.sh)) so the
server-side `^x.y.z` resolution check passes.

> **Lockstep versioning is required for the master tag.** The pub.dev tag pattern `v{{version}}` only matches a
> package whose `pubspec.yaml` version equals the tag's version. If you ever need to release packages at
> *different* versions, give them separate tag patterns (`<package>-v{{version}}`) and split the workflow into
> per-package triggers instead.

> **Prerelease deps.** While the packages are at `0.1.0-rc1`, the inter-package constraints are `^0.1.0-rc1`
> (which admits the prerelease). When you cut the stable `0.1.0`, tighten them back to `^0.1.0` so stable
> consumers never resolve to a prerelease.

> The very first version is published manually (Phase 2) because automated publishing can only be configured
> *after* a package exists. From then on, Phase 4 (one tag) is all you need.

## How OIDC publishing works (no secrets)

There is no stored token in GitHub because the trust is established **once** in the pub.dev Admin page (Phase 3)
and **proven per run** by a signed token — not a shared password:

1. **You link package → repo (once).** The trusted-publisher config on `pub.dev/packages/<pkg>/admin` records
   "this GitHub repo + tag pattern may publish this package." Your pub.dev account owns the package; this config
   is the binding.
2. **Each workflow run mints a short-lived OIDC token.** Because the job declares `permissions: id-token: write`,
   GitHub Actions issues a JWT — signed by GitHub — asserting verifiable claims about *this* run: the repository,
   the exact tag that triggered it, the workflow, etc.
3. **`dart pub publish` exchanges that token with pub.dev**, which verifies the signature against GitHub's public
   OIDC keys and checks the claims against your Phase-3 config (repo matches? tag matches `v{{version}}`?).
4. **On a match, pub.dev issues a temporary, package-scoped credential** (valid minutes) and accepts the upload.

So GitHub only proves *"this is run of repo X triggered by tag Y"* cryptographically; pub.dev independently knows
*"repo X is trusted to publish package Z, which you own."* The tag pattern is also a security boundary — a push
to a random branch can't publish, because its token claims won't match.

## Package-name ownership and transferring to DIF

This matters because `didwebvh-dart` is intended to be **donated to the Decentralized Identity Foundation
(DIF)**. Read this before the first publish.

- **First publish claims the name globally.** Once `didwebvh` (and the others) are published from your
  account, the names are yours — no other account or publisher, **including DIF**, can independently publish a
  version of them. Names cannot be renamed or deleted to free them, and published versions are permanent (only
  *retractable*).
- **This is a feature for the donation: it reserves the names** so nobody can squat them before the handover.
- **Ownership is transferable without losing the name or history.** When the donation happens, the packages move
  to DIF's pub.dev **verified publisher** — every existing version stays intact and DIF publishes future versions
  under the same names.

### Handover checklist (for the donor and DIF)

1. **DIF sets up a verified publisher** on pub.dev (a domain-verified publisher, e.g. tied to a DIF domain), if
   it doesn't already have one.
2. **DIF adds the current owner as a member** of that publisher (transferring a package *into* a publisher
   requires you to be a member of the target publisher).
3. For **each** package, the current owner opens `pub.dev/packages/<pkg>/admin` → **Transfer to publisher** and
   transfers it to DIF's publisher. (Alternatively, as a lighter interim step, add DIF's account as an
   **uploader** so they can publish without a full transfer.)
4. **Update the repo trusted-publisher config and links** to DIF's org once the GitHub repository itself is
   transferred to `decentralized-identity/didwebvh-dart`: re-point each package's Phase-3 *Repository* field to
   the new repo, and switch the README/CI/Codecov badge URLs (already flagged in the root `README.md`).

> If the donation is imminent and you don't need the packages on pub.dev yet, the zero-transfer alternative is to
> wait and let DIF do the first publish under its publisher. Reserving now (then transferring) is the right call
> only if you want the names locked or want to use the published packages before the handover.
