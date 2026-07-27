# Zuli ProxyBroker Extended — project guide for Claude

Find, check, and serve public HTTP(S)/SOCKS4/5 proxies. **Zuli ProxyBroker Extended** is a
library-first Rust distribution: its Cargo package is `zuli-proxybroker-extended`, while its Rust
library crate and CLI executable remain `proxybroker`. It is an independently maintained derivative
of [`proxybroker-rs`](https://github.com/TurtIeSocks/proxybroker-rs), itself a Rust/tokio port of
[proxybroker2](https://github.com/bluet/proxybroker2). The design record lives in
`docs/systematic-refactor/` (trace → goals → map → decisions) and `docs/roadmap/`. Upstream
attribution remains in `NOTICE` and repository history.

## Build, test, lint

The toolchain is **pinned to stable** via `rust-toolchain.toml`, so plain `cargo` uses stable inside
the repo (the machine's `rustup default` may be nightly — the pin overrides it). Keep local stable
current: a clippy lint new in a fresh stable can fail CI's `-D warnings` while passing an older local.

```sh
cargo test --all-features --locked          # full suite (fully offline; see Testing)
cargo clippy --all-targets --all-features --locked -- -D warnings
cargo fmt --all --check
```

CI mirrors exactly these, plus two combos that catch feature-gating bugs — run them before pushing:

```sh
cargo test --no-default-features --locked                                 # geo-free path (divergent runtime code)
cargo build --bin proxybroker --no-default-features --features cli --locked   # cli WITHOUT server — a real gate
```

## Gotchas (read before touching the checker, broker, or Proxy)

- **TLS is ring-only rustls, no aws-lc-rs** (the musl/scratch-Docker invariant). A **bare
  `reqwest::Client::new()` panics** — reqwest uses `rustls-no-provider`, so a process crypto provider
  must be installed first. Call `proxybroker::install_default_crypto_provider()` before building any
  reqwest client (it's a `Once`; `Broker::build`/`Resolver::new` already do it; tests must call it).
- **The `--format json` Proxy shape is a FROZEN v1** (`src/proxy.rs`, guarded by
  `serializes_to_python_as_json_shape`). *Additive, always-present, null-when-absent* fields are fine;
  removing/retyping a field needs a new `--format` variant, not an in-band change. Non-parity data goes
  on **unserialized** fields (the `caps`/`trust`/`auth`/`asn`/`probe_runtimes` pattern) so the golden
  shape and the save/load round-trip stay intact.
- **CC BY 4.0 data hygiene.** Bundle **only** DB-IP Country-Lite geo data. City (region/city) and ASN
  read **only** from a user-supplied `--geo-db`/`--asn-db` mmdb — bundle no non-Country data. Keep
  `LICENSE-DATA` + `NOTICE` shipping with every binary. `Cargo.toml`'s `include` list is anchored with
  leading `/` so `tests/**` never lands in the published crate (verify: `cargo package --list`).
- **Everything is feature-gated** (`cli`, `server`, `metrics`, `progress`, `persist`, `store-sqlite`,
  `store-redis`, `tui`, `watch`, `mcp`, `connector`, `geo`, `geo-bundled`). A misplaced `#[cfg]` easily
  breaks the cli-without-server build without failing all-features — hence that CI combo above.

## Architecture

`src/lib.rs` is the module map. Data flows provider → checker → pool:
`broker` (find/grab/serve orchestration, `ProxyStream`) · `provider` (scraping) + `parse`
(`find_addrs_global` ip:port scanner) · `resolver` → `negotiator` (HTTP/HTTPS/SOCKS4/5/CONNECT) →
`judge` → `checker` (anonymity + honeypot/trust) · `server` (`Pool` + `serve` + Prometheus) ·
`persist` (`Store`: SqliteStore/RedisStore/MemoryStore) · `scheduler` (adaptive re-check) · `geo` ·
`tui` · `mcp` · `connector` (`RotatingProxyConnector` + `Broker::rotating`). `Proxy` is **plain data**
— the socket lives in the checker, never on `Proxy`.

## Providers

Data-driven: `data/providers.yaml` (embedded via `include_str!`). A provider is **one plain GET** URL;
the generic scanner extracts `ip:port` from plaintext/HTML (no per-format parsers; a `pattern` regex
handles the rare bespoke source). Only `type: simple` is supported. Liveness is a **scheduled audit**
(`.github/workflows/provider-audit.yml`, weekly), never a blocking unit test — add a provider with a
format-archetype fixture test in `tests/provider_registry.rs`, not a live fetch.

## Testing

The suite is **fully offline** — mock servers on `127.0.0.1` + recorded fixtures (`tests/data/`). The
one exception is `store-redis`, which needs a live Redis (`REDIS_URL`, e.g.
`docker run --rm -d -p 6379:6379 redis:7`); those tests are skipped without it, and CI runs them in a
dedicated `store-redis` job.

## CI & release

`.github/workflows/ci.yml` has three jobs: **test** (fmt/clippy/all-features/no-default/cli-only),
**dist** (static musl build + FROM-scratch Docker + shellcheck `install.sh`), **store-redis**.

Release policy: crates.io publication is intentionally disabled pending separate approval. After the
public Zuli repository exists, a valid version tag must still equal the `Cargo.toml` version. The
reviewed release workflow first runs `cargo test --all-features --locked` and
`cargo package --locked`, then creates the GitHub Release, uploads the binary matrix, and publishes
the GHCR image. Only a canonical stable tag (`vMAJOR.MINOR.PATCH`) may move `latest`; accepted
prerelease tags receive only their version-specific image tag. GitHub Release and GHCR publication
occur only through that reviewed workflow after valid-tag verification; this guide does not claim
that any public Zuli release or image already exists. Binary-matrix quirk:
`aarch64-linux-musl` cross-builds on x86 `ubuntu-latest`, `x86_64-macos` on Apple-Silicon
`macos-14` (their "native" runners do not build cleanly on GitHub's fleet).

## Docs

mdBook lives in `book/`. The configured `.github/workflows/docs.yml` is intended to build and deploy
it to GitHub Pages on qualifying `main` pushes after Pages is enabled; no public Zuli Pages deployment
is verified yet. **When you change CLI flags, features, metrics, or public API, update the matching
`book/src/**` page** (build/preview with `mdbook build book` / `mdbook serve book`).
