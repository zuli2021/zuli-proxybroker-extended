# Changelog

All notable changes to Zuli ProxyBroker Extended are documented in this file.

## [1.1.0] - unreleased

Distribution closure for v1.1.0. No feature redesign; this release completes the
distribution surface around the frozen v1.0.0 API and CLI contract.

- Adds an `aarch64-linux-android` release binary with the same default feature set
  (`cli`, `server`, `geo`, `geo-bundled`) as desktop, built and validated in a dedicated
  Android CI workflow, packaged and checksummed as a canonical GitHub Release asset.
- Prepares crates.io publication: package version `1.1.0`, the `publish = false` flag is
  removed as approved, the crate package retains `LICENSE`, `LICENSE-DATA`, `NOTICE`,
  `README.md`, and the bundled DB-IP Country Lite data. Actual crates.io submission remains
  owner-gated and has not occurred.
- Prepares a non-blocking Docker Hub mirror of the canonical GHCR image (mirror only; it
  never gates the canonical release path).
- Adds repository-side distribution material for WinGet, Scoop, Homebrew, Chocolatey, AUR,
  Nixpkgs, and Termux under `distribution/`. Nothing has been submitted.
- Keeps the canonical GitHub Releases workflow, its exact asset-set verification, and the
  GHCR `latest` policy intact; Android is added as a separate release path outside the
  desktop binary matrix.

## [1.0.0] - 2026-07-29

- Declares the first stable Zuli release.
- Establishes the documented Rust library API under Semantic Versioning and
  treats the documented CLI interface as a compatibility contract.
- Provides multi-protocol public-proxy discovery and checking for HTTP, HTTPS,
  SOCKS4, and SOCKS5, including anonymity classification.
- Provides rotating proxy-server operation.
- Includes persistence and observability capabilities plus optional Redis,
  SQLite, TUI, metrics, MCP, and connector integrations.
- Retains verified release packaging with cross-platform assets, SHA-256
  checksums, mandatory installer verification, and the original legal notices.
- Remains an independently maintained derivative with attribution to
  TurtIeSocks/proxybroker-rs and its upstream lineage preserved.

This stability declaration does not make third-party public proxies available,
trustworthy, or safe.
