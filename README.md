# Zuli ProxyBroker Extended

[![Release](https://img.shields.io/github/v/release/zuli2021/zuli-proxybroker-extended?display_name=tag&sort=semver)](https://github.com/zuli2021/zuli-proxybroker-extended/releases/latest)
[![CI](https://github.com/zuli2021/zuli-proxybroker-extended/actions/workflows/ci.yml/badge.svg)](https://github.com/zuli2021/zuli-proxybroker-extended/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/zuli2021/zuli-proxybroker-extended)](https://github.com/zuli2021/zuli-proxybroker-extended/blob/main/LICENSE)

**Fast Rust proxy scraper and proxy checker with live proxy validation and a rotating proxy pool for HTTP/HTTPS, SOCKS4, and SOCKS5.**

`proxybroker` is a Rust CLI and library that discovers public proxies, validates
and classifies them by anonymity, and serves a rotating proxy endpoint. It
includes offline DB-IP country lookup and optional Redis-backed storage.

> ⭐ If Zuli ProxyBroker Extended saves you time, consider starring the repository — it helps other developers discover the project.

[Download v1.1.0](https://github.com/zuli2021/zuli-proxybroker-extended/releases/tag/v1.1.0) · [Documentation](https://zuli2021.github.io/zuli-proxybroker-extended/) · [Installation](#installation)

## Highlights

- Discover and validate public HTTP/HTTPS, SOCKS4, and SOCKS5 proxies.
- Check, classify, and select proxies with offline country lookup.
- Serve a rotating proxy endpoint or embed the Rust library directly.
- v1.1.0 is the current distribution-closure release: SHA-256-verified binaries for Linux,
  macOS, Windows, and ARM64 Android (`aarch64-linux-android`), plus the canonical GHCR image.
- Every release target ships paired with a SHA-256 checksum; the `LICENSE`, `LICENSE-DATA`,
  and `NOTICE` notices travel with every archive.

## Distribution state

- **GitHub Releases** and **GHCR** are the canonical v1.1.0 distribution surfaces.
  v1.1.0 ships Linux, macOS, Windows, and Android binaries with SHA-256 checksums and the
  `LICENSE`, `LICENSE-DATA`, and `NOTICE` notices.
- **Android**: the `aarch64-linux-android` binary is built with the same default feature set as
  desktop (`cli`, `server`, `geo`, `geo-bundled`). It is a canonical release asset, built and
  validated in a dedicated Android CI workflow.
- **crates.io**: `zuli-proxybroker-extended` 1.1.0 is published on crates.io. The package
  provides the `proxybroker` Rust library and CLI and carries the same Apache-2.0 code license,
  required NOTICE provenance, and separately licensed bundled DB-IP data as the canonical release.
- **Docker Hub**: a **public mirror** exists at `docker.io/zuli2021/zuli-proxybroker-extended`,
  with v1.1.0 mirrored as both `1.1.0` and `latest`. GHCR remains canonical/authoritative; the
  Docker Hub mirror is non-blocking and not independently built. Future automatic mirroring
  (`.github/workflows/docker-hub-mirror.yml`) remains credential/configuration dependent.
- **Package managers**:
  - **WinGet**: submitted as PR [#414112](https://github.com/microsoft/winget-pkgs/pull/414112)
    (`zuli2021.ZuliProxyBrokerExtended` 1.1.0); CLA and validation completed; awaiting upstream
    community moderator review.
  - **Chocolatey**: `zuli-proxybroker-extended` 1.1.0 submitted; pending community
    moderation/approval.
  - **AUR**: technically validated but not submitted; a public maintainer identity is required.
  - **Scoop Main**: not submitted; blocked by the current external inclusion/notability policy.
  - **Homebrew Core**: not submitted; blocked by the current external notability/repository-age
    policy.
  - **Nixpkgs**: not submitted; Nix tooling/SRI and maintainer-entry work remains.
  - **Termux**: not submitted; the current main-repository policy blocks packages installable
    through `cargo`.

  None of the blocked package-manager surfaces are published.

## Quick Start

### Release download / install

Install the latest supported Linux or macOS binary (SHA-256 verified, fail-closed;
`LICENSE`, `NOTICE`, and `LICENSE-DATA` are retained):

```sh
curl -fsSL https://raw.githubusercontent.com/zuli2021/zuli-proxybroker-extended/main/install.sh | sh
PROXYBROKER_VERSION=v1.1.0   # optional: select this release explicitly
```

### Install from crates.io

The published crates.io package is also installable with Cargo (package name
`zuli-proxybroker-extended`; the installed executable is `proxybroker`):

```sh
cargo install zuli-proxybroker-extended --version 1.1.0 --locked
proxybroker --version
```

### Android release

v1.1.0 ships a canonical `proxybroker-<tag>-aarch64-linux-android.tar.gz` release asset
(executable `proxybroker`, plus `LICENSE`, `LICENSE-DATA`, `NOTICE`, and `README.md`, and its
`.sha256` checksum). Install it by downloading the matching asset from the release, verifying
the checksum, and extracting it onto an ARM64 Android device (for example inside Termux).
The Android build uses the same default features as desktop; there is no Android-reduced
feature profile.

### Windows release

Download the matching `x86_64-pc-windows-msvc` asset from the
[v1.1.0 release](https://github.com/zuli2021/zuli-proxybroker-extended/releases/tag/v1.1.0),
verify its `.sha256`, and extract it. The v1.0.0 x86_64 Windows release was manually
validated (2026-08-08) on a supervised Windows host, including checksum
verification, CLI execution, bounded live proxy discovery/validation, and a local
rotating-proxy request. This does not claim every Windows version, architecture,
network, or long-running workload.

### Build from source

Requires Rust 1.85 or newer, Cargo, and Git:

```sh
git clone https://github.com/zuli2021/zuli-proxybroker-extended.git
cd zuli-proxybroker-extended
cargo build --release --locked
./target/release/proxybroker --version
cargo install --path . --locked   # optional, installed name stays "proxybroker"
```

### Docker

```sh
docker run --rm -p 8888:8888 ghcr.io/zuli2021/zuli-proxybroker-extended:1.1.0 serve --host 0.0.0.0:8888
```

The image targets Linux amd64 (Linux aarch64 users should use the release binary);
it is published only after the release and all binary assets succeed. A container
must bind `0.0.0.0` to be reachable through a published port.

**GHCR is canonical.** A public **Docker Hub mirror** is also available at
`docker.io/zuli2021/zuli-proxybroker-extended` (both `1.1.0` and `latest` exist), copied from
the canonical GHCR image without independent builds:

```sh
docker run --rm -p 8888:8888 \
  docker.io/zuli2021/zuli-proxybroker-extended:1.1.0 \
  serve --host 0.0.0.0:8888
```

The Docker Hub mirror never gates the canonical release path.

## Usage

```sh
proxybroker grab --limit 10                      # scrape providers, no checking
proxybroker find --types HTTP HTTPS --limit 10   # scrape + check + classify anonymity
proxybroker find --types SOCKS5 --format json    # machine-readable output
proxybroker serve --types HTTP --host 127.0.0.1:8888     # local rotating proxy server
proxybroker --provider-dir ./my-providers find --types HTTP   # bring your own providers
```

## Rust Library

Library-first: the CLI is a thin shell over a reusable API. The stable Rust package is published
on crates.io as `zuli-proxybroker-extended` 1.1.0. The library crate name remains `proxybroker`.

```toml
[dependencies]
proxybroker = { package = "zuli-proxybroker-extended", version = "1.1.0" }
```

To pin directly to the canonical GitHub release tag instead:

```toml
[dependencies]
proxybroker = { package = "zuli-proxybroker-extended", git = "https://github.com/zuli2021/zuli-proxybroker-extended.git", tag = "v1.1.0" }
```

```rust
use proxybroker::{Broker, FindQuery, Proto, TypeSpec};
use futures_util::StreamExt;

let mut stream = Broker::builder()
    .build()
    .find(FindQuery {
        types: vec![TypeSpec::any(Proto::Http)],
        limit: Some(10),
        ..Default::default()
    })
    .await?;
while let Some(proxy) = stream.next().await {
    println!("{}", proxy.addr());
}
```

For unreleased development work, use an exact commit rather than an unpinned branch.

## Features

| feature | default | what it does |
|---|---|---|
| `cli` | yes | the `proxybroker` binary (clap, logging, output formats) |
| `server` | yes | the local rotating proxy server |
| `geo` | yes | country lookup code |
| `geo-bundled` | yes | bundles the DB-IP database (~3.9 MB). Turn off to supply your own. |

`--no-default-features` yields a library with no geo data, server, or CLI
dependencies. Optional features include metrics, persistence (SQLite/Redis),
TUI, MCP, and a rotating connector.

## Safety

> **Public-proxy warning:** Public proxies are untrusted third-party
> infrastructure. They must not be used for credentials, account logins,
> payment information, private API tokens, or other sensitive traffic.

v1.0.0 is the first stable release; v1.1.0 is the current release (distribution closure).
The documented library API and CLI interface are compatibility contracts governed by Semantic
Versioning. This stability declaration does not guarantee the availability, trustworthiness,
or safety of third-party public proxies.

## Project & Provenance

Zuli ProxyBroker Extended is an independently maintained derivative of
[proxybroker-rs](https://github.com/TurtIeSocks/proxybroker-rs), whose lineage
includes [proxybroker2](https://github.com/bluet/proxybroker2) and
[ProxyBroker](https://github.com/constverum/ProxyBroker).

Zuli-specific engineering: configurable pool-fill concurrency/retry limits;
corrected relay-protocol selection for HTTPS-capable upstream proxies (designed
to preserve client-owned end-to-end TLS); and focused automated tests covering
pool-fill, CLI parsing, defaults, and relay negotiation.

In the 2026-07-29 landscape review, no third Rust project combined a reusable
library API, CLI, public-proxy discovery/validation, and rotating proxy-server
operation. That comparison (including the closest analogue, `proxy-rs`) is a dated
snapshot documented in [`docs/systematic-refactor/research.md`](docs/systematic-refactor/research.md).

## Data & Licensing

Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE). Bundled geo data is
DB-IP Country Lite under CC BY 4.0 (no update-or-destroy clause) — see
[LICENSE-DATA](LICENSE-DATA). The code licence does not cover the data, and the
data licence does not cover the code. This is why the bundled DB-IP data ships
separately from any user-supplied MaxMind databases (e.g. `--geo-db`), and why
City/ASN data is opt-in and unbundled. For the licensing rationale and detailed
analysis, see [`docs/systematic-refactor/research.md`](docs/systematic-refactor/research.md).

## Documentation

Full CLI reference, feature guide, and architecture notes are on
[GitHub Pages](https://zuli2021.github.io/zuli-proxybroker-extended/).
