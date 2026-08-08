# Distribution material (DIST-001 — v1.1.0)

This directory holds the repository-side preparation for distributing **Zuli ProxyBroker
Extended v1.1.0** through downstream package ecosystems. It is implementation material, not a
new architecture document: the closed DIST-001 decisions are authoritative, and this folder only
turns those decisions into manifests and the deterministic tooling that materializes them.

Canonical distribution surfaces (unchanged by this folder):

- **GitHub Releases** — the canonical binary assets; the **v1.1.0 Release is published** with
  16 SHA-256-verified assets (Linux, macOS, Windows, and `aarch64-linux-android`).
- **GHCR** — the canonical container registry; `1.1.0` and `latest` images are published.
- **crates.io** — prepared for v1.1.0 (`zuli-proxybroker-extended`); publication has **not**
  occurred and remains owner-gated.
- **Docker Hub** — mirror only, non-blocking (`.github/workflows/docker-hub-mirror.yml`);
  **not yet published/configured**.

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

Everything under `distribution/` is a **template** (`*.template`) with placeholder tokens; the
rendered, real-hash manifests live in the generated, git-ignored `distribution/out` directory
and are **never committed**. The canonical v1.1.0 release artifacts now exist, so the templates
can be materialized into publishable manifests with **real** SHA-256 hashes. `distribution/out`
remains generated/ignored output material only. **No placeholder is ever presented as a final
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

`materialize.sh` renders the templates deterministically from the real canonical v1.1.0
artifacts. It has been run successfully against the published v1.1.0 release; rendered output
(no placeholders) is written to the git-ignored `distribution/out`:

```sh
# Download and render from the real public v1.1.0 artifacts:
./distribution/materialize.sh v1.1.0

# Provide the Nixpkgs git-export SRI hash (requires nix tooling):
./distribution/materialize.sh v1.1.0 --nix-git-sri 'sha256-…'
```

Notes:

- GitHub's auto-generated source tarball (`archive/refs/tags/<tag>.tar.gz`) is **not**
  byte-reproducible from `git archive` locally (gzip determinism), so its SHA-256 is always
  taken from the real archive the materializer downloads.
- Binary-asset hashes come from the canonical release assets (the same files whose `.sha256`
  sidecars the release workflow verifies).
- `materialize.sh` refuses to run when any required hash is missing.

## Validation performed

- Workflow files pass `actionlint` and YAML parsing.
- `scripts/build-android.sh` passes `shellcheck` and is exercised end-to-end for
  `aarch64-linux-android` (build + ELF check + packaging + checksum).
- Template syntax is validated: WinGet YAML structure, Scoop JSON, Homebrew formula
  (`ruby -c`), Chocolatey XML (nuspec) + PowerShell parse, AUR PKGBUILD (`bash -n`),
  Termux build.sh (`bash -n`).
- `materialize.sh` has rendered the real v1.1.0 manifests and re-validates the rendered
  output structure (YAML/JSON/XML parse, `bash -n`). The source-tarball and Windows-zip
  SHA-256 hashes are cross-checked against independently downloaded canonical artifacts.
- **Nixpkgs**: materialization of the `package.nix` requires `nix-prefetch-git` to compute the
  `fetchFromGitHub` git-export SRI hash; if that tooling is unavailable on the host,
  `NIX_GIT_SRI_TOOLING_UNAVAILABLE` is reported and the Nix template is not rendered (no
  placeholder is fabricated).

## Owner-gated actions (not performed here)

- crates.io publication of `zuli-proxybroker-extended` 1.1.0 (preceded by a fresh read-only
  collision check immediately before the actual upload; not yet performed).
- Configuring Docker Hub secrets/variables and enabling the mirror (not yet configured).
- Submitting WinGet/Scoop/Homebrew/Chocolatey/AUR/Nixpkgs/Termux packages (nothing submitted).
- Final per-ecosystem collision/identity checks immediately before the first submission of each.

## Required notices in every distributed artifact

Every distribution surface preserves:

- Apache-2.0 code license (`LICENSE`).
- DB-IP Country Lite CC BY 4.0 attribution (`LICENSE-DATA` + `NOTICE`) wherever bundled geo
  data is shipped (i.e. whenever the default `geo-bundled` feature is built).
- `NOTICE` provenance/statement-of-changes.
- The `proxybroker` executable name (never renamed for package-manager convenience).
