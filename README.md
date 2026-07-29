# Zuli ProxyBroker Extended

[![Release](https://img.shields.io/github/v/release/zuli2021/zuli-proxybroker-extended?display_name=tag&sort=semver)](https://github.com/zuli2021/zuli-proxybroker-extended/releases/latest)

Zuli ProxyBroker Extended is a Rust library and CLI for finding, validating, and
serving rotating public HTTP(S), SOCKS4, and SOCKS5 proxies.

It is an independently maintained derivative of
[proxybroker-rs](https://github.com/TurtIeSocks/proxybroker-rs). The upstream
project derives from [proxybroker2](https://github.com/bluet/proxybroker2),
itself the maintained successor to
[ProxyBroker](https://github.com/constverum/ProxyBroker).

## Zuli-specific engineering

- Configurable initial proxy-pool fill concurrency and retry limits.
- Corrected relay-protocol selection for HTTPS-capable upstream proxies used by
  HTTP CONNECT and SOCKS5 tunnel frontends.
- Relay selection is designed to preserve client-owned end-to-end TLS.
- Focused automated tests cover pool-fill controls, CLI parsing, defaults, and
  relay-negotiation selection.

> **Public-proxy warning:** Public proxies are untrusted third-party
> infrastructure. They must not be used for credentials, account logins,
> payment information, private API tokens, or other sensitive traffic.

Original notices are retained in [LICENSE](LICENSE) and [NOTICE](NOTICE).
Bundled DB-IP data has separate licensing described in
[LICENSE-DATA](LICENSE-DATA). The source distribution remains under the
Apache License 2.0.

## Installation

### Release installer

For tagged releases, install the latest supported Linux or macOS binary with:

```sh
curl -fsSL https://raw.githubusercontent.com/zuli2021/zuli-proxybroker-extended/main/install.sh | sh
```

The installer resolves the latest GitHub Release by default. Set
`PROXYBROKER_VERSION=v0.4.1` to select this release explicitly.

Installation is fail-closed: SHA-256 verification is mandatory, and `LICENSE`,
`NOTICE`, and `LICENSE-DATA` are retained with the installed documentation.
Windows users should download the matching release asset directly or build from
source.

### Build from source

Build from source with Rust 1.85 or newer, Cargo, and Git. Network access is
required by proxy discovery and checking operations.

```sh
git clone https://github.com/zuli2021/zuli-proxybroker-extended.git
cd zuli-proxybroker-extended
cargo build --release --locked
./target/release/proxybroker --version
```

From a cloned checkout, install the CLI with:

```sh
cargo install --path . --locked
```

The installed executable name remains `proxybroker`.

### Rust library dependency

The package is not published to crates.io. Applications can use the stable
release tag as a direct Git dependency:

```toml
[dependencies]
proxybroker = { package = "zuli-proxybroker-extended", git = "https://github.com/zuli2021/zuli-proxybroker-extended.git", tag = "v0.4.1" }
```

Rust imports remain:

```rust
use proxybroker::{Broker, FindQuery, Proto, TypeSpec};
```

For unreleased development work, use an exact commit rather than relying on an
unpinned branch.

### Docker

Run the stable versioned container image with:

```sh
docker run --rm -p 8888:8888 ghcr.io/zuli2021/zuli-proxybroker-extended:0.4.1 serve --host 0.0.0.0:8888
```

The application defaults to binding on `127.0.0.1:8888`. A containerized server
intended to be reached through a published Docker port must explicitly use
`serve --host 0.0.0.0:8888`, as shown above. Local container validation completed
on the current Docker Desktop-backed Linux amd64 environment: the committed
scratch image built with an 11.41 MB context and ran as UID/GID `65532:65532`.
Restricted `--version`, `serve --help`, and `find --help` checks passed with no
network, a read-only root filesystem, all capabilities dropped, and
no-new-privileges.

The release workflow publishes the `0.4.1` and `latest` image tags only after the
GitHub Release and all binary assets succeed. The container image currently
targets Linux amd64; Linux aarch64 users should use the corresponding release
binary. Broad Windows, WSL, and Docker Desktop compatibility is not claimed,
and live proxy-server traffic has not been validated.

## Usage

```sh
proxybroker grab --limit 10                      # scrape providers, no checking
proxybroker find --types HTTP HTTPS --limit 10   # scrape + check + classify anonymity
proxybroker find --types SOCKS5 --format json    # machine-readable output
proxybroker find --types HTTP --show-stats       # + an aggregate summary on stderr
proxybroker find --types HTTP --dnsbl zen.spamhaus.org   # reject blocklisted IPs
proxybroker serve --types HTTP --host 127.0.0.1:8888     # local rotating proxy server

# bring your own providers (YAML/JSON configs, one provider per file):
proxybroker --provider-dir ./my-providers find --types HTTP
proxybroker --provider-dir ./my-providers --providers-only grab   # ignore the bundled set
```

As a library:

```rust
use proxybroker::{Broker, FindQuery, Proto, TypeSpec};
use futures_util::StreamExt;

let broker = Broker::builder().build();
let mut stream = broker.find(FindQuery {
    types: vec![TypeSpec::any(Proto::Http)],
    limit: Some(10),
    ..Default::default()
}).await?;
while let Some(proxy) = stream.next().await {
    println!("{}", proxy.addr());
}
```

## Why this exists

There was no Rust equivalent with a library API. Checked before starting (2026-07-15):

| crate | latest | published | ships a lib? | scope |
|---|---|---|---|---|
| [`proxy-rs`](https://crates.io/crates/proxy-rs) | 0.3.7 | 2023-10-24 | **no** | closest analogue — scraper + checker + serve, but binary-only and unmaintained |
| [`proxy-scraper-checker`](https://crates.io/crates/proxy-scraper-checker) | 0.1.3 | 2024-06-14 | no | one source only |
| [`open_proxies`](https://crates.io/crates/open_proxies) | 0.1.1 | 2022-11-15 | yes | checker only |
| [`proxy-scraper`](https://crates.io/crates/proxy-scraper) | 0.2.0 | 2024-05-03 | yes | different domain (MTProxy/Shadowsocks link parsing) |

`proxy-rs` is the real precedent, and it publishes no library target on any version. This
crate is library-first, with the CLI as a thin shell over it.

## Features

| feature | default | what it does |
|---|---|---|
| `cli` | yes | the `proxybroker` binary (clap, logging, output formats) |
| `server` | yes | the local rotating proxy server |
| `geo` | yes | country lookup code |
| `geo-bundled` | yes | bundles the DB-IP database (~3.9 MB). Turn off to supply your own. |

`--no-default-features` gives you the library with no geo data, no server, and no CLI
dependencies.

## Geolocation data

When built with `geo-bundled` (on by default), this crate includes the DB-IP Country Lite
database:

> IP Geolocation by DB-IP (https://db-ip.com)

licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[LICENSE-DATA](LICENSE-DATA).

**Why not MaxMind GeoLite2**, which the Python version bundles? GeoLite2's EULA requires
licensees to destroy superseded copies within 30 days of a new release. A published
crates.io version is immutable — it cannot be destroyed — so bundling GeoLite2 in a
published crate cannot be made compliant by attribution or feature flags. (The Python
project's bundled copy was built 2017-09-06 and is 8.9 years stale, and its `update-geo`
command has been broken since MaxMind retired the anonymous download endpoint in 2019.)
DB-IP Lite is CC BY 4.0, has no update-or-destroy clause, and no ShareAlike obligation.

You can always bring your own database — including your own lawfully-licensed GeoLite2:

```sh
proxybroker --geo-db /path/to/GeoLite2-Country.mmdb find --types HTTP
```

### ASN attribution

To tag each proxy with the Autonomous System that owns its IP (its network operator), pass a
separate ASN database with `--asn-db`. This is opt-in and unbundled — no ASN data ships with the
crate — for the same licensing reason as the City data above:

```sh
proxybroker --asn-db /path/to/GeoLite2-ASN.mmdb find --types HTTP --format json
```

Each proxy then carries an `asn` object (`{ "number": 15169, "org": "Google LLC" }`, or `null`
when no `--asn-db` resolved it) in `--format json`, and the `{{asn}}` / `{{asn_org}}` tokens work
in `--output-format` templates. `--geo-db` and `--asn-db` are independent and can be combined.

Full analysis with primary sources: [`docs/systematic-refactor/research.md`](docs/systematic-refactor/research.md).

## Licence

Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Bundled geo data is CC BY 4.0 — see [LICENSE-DATA](LICENSE-DATA). The code licence does
not cover the data, and the data licence does not cover the code.
