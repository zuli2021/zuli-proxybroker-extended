<!-- Modified by Zuli2021 in 2026 for Zuli ProxyBroker Extended.
See NOTICE for attribution and the statement of changes. -->

# Installation

Zuli ProxyBroker Extended v1.0.0 is published as a public GitHub Release with Linux, macOS,
and Windows binaries plus SHA-256 checksums, and GHCR is the canonical container registry.
The next release, **v1.1.0 (distribution closure)**, is being prepared: it adds an Android
(`aarch64-linux-android`) release binary, prepares crates.io publication, and adds a
non-blocking Docker Hub mirror. None of the v1.1.0 artifacts or submissions exist yet —
v1.1.0 is not published to crates.io and no v1.1.0 release or image has been produced.

## Build from source

Local source builds require:

- Rust 1.85 or newer;
- Cargo; and
- Git.

In an existing checkout, build the release binary with the locked dependency set:

```sh
cargo build --release --locked
```

After the public Zuli repository is created, clone it with:

```sh
git clone https://github.com/zuli2021/zuli-proxybroker-extended.git
cd zuli-proxybroker-extended
cargo build --release --locked
```

The executable remains `proxybroker` at `target/release/proxybroker`. The Cargo package is
`zuli-proxybroker-extended`, while the Rust library crate remains `proxybroker`. The pinned
`rust-toolchain.toml` selects stable Rust and the package declares Rust 1.85 as its minimum.

## Rust dependency

The v1.1.0 crate package is prepared for crates.io publication as
`zuli-proxybroker-extended`, but publication has **not** occurred (owner-gated, preceded by a
collision check immediately before upload). Until it does, depend on the stable tag as a Git
dependency:

```toml
[dependencies]
proxybroker = { package = "zuli-proxybroker-extended", git = "https://github.com/zuli2021/zuli-proxybroker-extended.git", tag = "v1.0.0" }
```

Pin a tag or commit rather than relying on an unpinned branch.

## Prebuilt static binary (`install.sh`)

After the first tagged Zuli release, the installer will download the matching release archive for
Linux (musl) or macOS, **verify its SHA-256 checksum**, and install it without a build toolchain or
`sudo`:

```sh
curl -fsSL https://raw.githubusercontent.com/zuli2021/zuli-proxybroker-extended/main/install.sh | sh
```

SHA-256 verification is mandatory: the installer requires either `sha256sum` or `shasum` and
fails rather than installing an archive with a missing, malformed, or mismatched checksum. These
environment variables control the future installation:

| Variable | Default | Meaning |
|---|---|---|
| `PROXYBROKER_VERSION` | latest release tag after one exists | Which release to install. |
| `PROXYBROKER_BIN_DIR` | `$HOME/.local/bin` | Install directory. |
| `PROXYBROKER_DOC_DIR` | `$HOME/.local/share/doc/zuli-proxybroker-extended` | Directory for `LICENSE`, `NOTICE`, and `LICENSE-DATA`. |

The binary is installed under `PROXYBROKER_BIN_DIR`, while the three legal files are installed
under `PROXYBROKER_DOC_DIR`. Supported installer targets are `x86_64`/`aarch64` Linux musl and
`x86_64`/`aarch64` Apple Darwin. Windows is not supported by `install.sh`.

The Linux release binary is intended to be a fully static musl build, with the geo database and
provider list embedded.

## Android (`aarch64-linux-android`)

v1.1.0 adds a canonical Android release binary: `proxybroker-<tag>-aarch64-linux-android.tar.gz`
(executable `proxybroker`, plus `LICENSE`, `LICENSE-DATA`, `NOTICE`, `README.md`) and its
`.sha256` checksum, built with the **same default feature set** as desktop (`cli`, `server`,
`geo`, `geo-bundled`) in a dedicated Android CI workflow. Install by downloading the matching
asset from the release, verifying the SHA-256, and extracting it on an ARM64 Android device
(for example inside Termux). Android is not covered by `install.sh` (Linux/macOS only).

## Docker (`FROM scratch`)

The canonical image path is `ghcr.io/zuli2021/zuli-proxybroker-extended`. GHCR is the
authoritative registry; a Docker Hub mirror
(`docker.io/zuli2021/zuli-proxybroker-extended`) is planned for v1.1.0 as a non-blocking copy
and never gates the canonical release path.

After a verified tagged release publishes an image, replace `<tag>` with the release version:

```sh
docker run --rm ghcr.io/zuli2021/zuli-proxybroker-extended:<tag> find --types HTTP --limit 5
docker run --rm -p 8888:8888 ghcr.io/zuli2021/zuli-proxybroker-extended:<tag> \
  serve --host 0.0.0.0:8888
```

Publishing a port from the container requires `serve --host 0.0.0.0:8888`. A local checkout can
also build the repository Dockerfile, subject to the local Docker environment:

```sh
docker build -t zuli-proxybroker-extended .
docker run --rm zuli-proxybroker-extended find --types HTTP --limit 5
```

## Feature flags in one paragraph

The crate is split into Cargo features so library users can pull in only what they need. The
defaults — `cli`, `server`, `geo`, `geo-bundled` — give you the full binary with the local
server and the bundled country database. Optional features add a metrics endpoint, a progress
bar, SQLite/Redis persistence, a terminal dashboard (`tui`), an MCP server (`mcp`), a
filesystem watcher (`watch`), and a drop-in hyper connector (`connector`). See
[Feature Flags](../architecture/feature-flags.md) for the full table and what each one enables.

### A geo-free build

Building with `--no-default-features` gives you the **library only**, with no geo data, no
server, and no CLI dependencies — and therefore no data-attribution obligation:

```sh
cargo build --no-default-features
```

You can also keep geolocation code while dropping the bundled database (turn off
`geo-bundled` but keep `geo`) and supply your own database at runtime with `--geo-db`. See
[Geolocation & ASN](../architecture/geo-asn.md) and [Data & Licensing](../data-and-licensing.md)
for details.
