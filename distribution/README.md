# Distribution material (DIST-001 — v1.1.0)

This directory holds the repository-side preparation for distributing **Zuli ProxyBroker
Extended v1.1.0** through downstream package ecosystems. It is implementation material, not a
new architecture document: the closed DIST-001 decisions are authoritative, and this folder only
turns those decisions into manifests and the deterministic tooling that materializes them.

Canonical distribution surfaces (unchanged by this folder):

- **GitHub Releases** — the canonical binary assets (now including `aarch64-linux-android`).
- **GHCR** — the canonical container registry.
- **crates.io** — prepared for v1.1.0 (`zuli-proxybroker-extended`), publication owner-gated.
- **Docker Hub** — mirror only, non-blocking (`.github/workflows/docker-hub-mirror.yml`).

## Identities

Approved/closed identities:

| Field | Identity |
|---|---|
| crates.io package | `zuli-proxybroker-extended` |
| Rust library crate | `proxybroker` |
| Executable / CLI command | `proxybroker` |
| Source repository | `github.com/zuli2021/zuli-proxybroker-extended` |
| Canonical GHCR image | `ghcr.io/zuli2021/zuli-proxybroker-extended` |
| Docker Hub mirror | `zuli2021/zuli-proxybroker-extended` |

Every downstream identifier below is **derived** from that approved Zuli identity (never the
generic upstream `proxybroker`). The exact permanent registry identifiers for each ecosystem
remain **owner-verified immediately before the first real submission**; until then the templates
below are preparation, not frozen submissions.

| Ecosystem | Identifier used | Note |
|---|---|---|
| WinGet | `zuli2021.ZuliProxyBrokerExtended` | Publisher = GitHub owner, package name preserves the Zuli product identity |
| Scoop | app name `zuli-proxybroker-extended` | `bin` stays `proxybroker` |
| Homebrew | formula `zuli-proxybroker-extended` | source build via Cargo |
| Chocolatey | id `zuli-proxybroker-extended` | Windows zip, checksum enforced |
| AUR | pkgbase/pkgname `zuli-proxybroker-extended` | source build via Cargo |
| Nixpkgs | pname `zuli-proxybroker-extended` | `by-name/zu/…`, source build with committed `Cargo.lock` |
| Termux | package `zuli-proxybroker-extended` | source build via `termux_setup_rust` |

## What is a template vs. a final manifest

Everything under `distribution/` is a **template** (`*.template`) with placeholder tokens.
Nothing here is a publishable manifest, because the v1.1.0 canonical release artifacts and
their SHA-256 hashes do not exist yet. **No placeholder is ever presented as a final
checksum.**

| Token | Meaning |
|---|---|
| `@TAG@` | release tag, e.g. `v1.1.0` |
| `@VERSION@` | tag without the leading `v`, e.g. `1.1.0` |
| `@RELEASE_BASE_URL@` | `https://github.com/zuli2021/zuli-proxybroker-extended/releases/download/@TAG@` |
| `@SOURCE_TARBALL_SHA256@` | SHA-256 of GitHub's auto-generated `archive/refs/tags/@TAG@.tar.gz` |
| `@SOURCE_TARBALL_SRI@` | same hash in Nix SRI form (`sha256-…`) |
| `@WINDOWS_ZIP_SHA256@` | SHA-256 of `proxybroker-@TAG@-x86_64-pc-windows-msvc.zip` |

## Materializing final manifests

`materialize.sh` renders the templates deterministically from canonical v1.1.0 artifacts. It
must be run after the canonical release artifacts exist, and is an owner action (the final
pre-submission hashes cannot legitimately exist before the canonical assets are produced):

```sh
# With the canonical release assets present locally (or downloadable):
./distribution/materialize.sh v1.1.0 --asset-dir /path/to/canonical-release-assets

# Provide the Nixpkgs git-export SRI hash (requires nix):
./distribution/materialize.sh v1.1.0 --nix-git-sri 'sha256-…'
```

Notes:

- GitHub's auto-generated source tarball (`archive/refs/tags/<tag>.tar.gz`) is **not**
  byte-reproducible from `git archive` locally (gzip determinism), so its SHA-256 is always
  taken from the real archive the materializer downloads.
- Binary-asset hashes come from the canonical release assets (the same files whose `.sha256`
  sidecars the release workflow verifies).
- `materialize.sh` refuses to run when any required hash is missing.

## Validation performed pre-release

The parts that can be validated before v1.1.0 exists are validated in this repository's CI and
locally:

- Workflow files pass `actionlint` and YAML parsing.
- `scripts/build-android.sh` passes `shellcheck` and is exercised end-to-end for
  `aarch64-linux-android` (build + ELF check + packaging + checksum).
- Template syntax is validated: WinGet YAML structure, Scoop JSON, Homebrew formula
  (`ruby -c`), Chocolatey XML (nuspec) + PowerShell parse, AUR PKGBUILD (`bash -n`),
  Termux build.sh (`bash -n`).
- `materialize.sh` renders a full set of manifests from sample hashes and re-validates the
  rendered output structure.

## Owner-gated actions (not performed here)

- Authorizing the implementation and pushing it to `main`.
- Creating the `v1.1.0` tag and running the reviewed release workflow.
- crates.io publication (preceded by a fresh read-only collision check immediately before).
- Configuring Docker Hub secrets/variables and enabling the mirror.
- Submitting WinGet/Scoop/Homebrew/Chocolatey/AUR/Nixpkgs/Termux packages.
- Confirming each ecosystem's final exact registry identifier at submission time.

## Required notices in every distributed artifact

Every distribution surface preserves:

- Apache-2.0 code license (`LICENSE`).
- DB-IP Country Lite CC BY 4.0 attribution (`LICENSE-DATA` + `NOTICE`) wherever bundled geo
  data is shipped (i.e. whenever the default `geo-bundled` feature is built).
- `NOTICE` provenance/statement-of-changes.
- The `proxybroker` executable name (never renamed for package-manager convenience).
