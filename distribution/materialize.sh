#!/usr/bin/env bash
# Modified by Zuli2021 in 2026 for Zuli ProxyBroker Extended.
# See NOTICE for attribution and the statement of changes.
# Deterministic renderer for the DIST-001 downstream distribution manifests.
#
# The v1.1.0 canonical release artifacts and their SHA-256 hashes do not exist until the
# reviewed release workflow produces them, so the `distribution/` templates are rendered here
# at release time from the canonical assets. This script never fabricates a hash: every
# required hash is either computed from a provided canonical artifact or downloaded from the
# actual release.
#
# Usage:
#   ./distribution/materialize.sh v1.1.0 \
#       [--asset-dir DIR]         local directory holding the canonical release archives
#                                 (proxybroker-<tag>-x86_64-pc-windows-msvc.zip etc.)
#       [--source-tarball FILE]   the GitHub auto-generated <tag>.tar.gz source archive
#       [--nix-git-sri SRI]       SRI hash of the git export (nix-prefetch-git output) for the
#                                 Nixpkgs template; without it the Nix template is not rendered
#       [--out-dir DIR]           output directory (default: distribution/out)
#
# Without --asset-dir/--source-tarball, the canonical release assets are downloaded from the
# actual GitHub Release (requires the release to exist). Rendered output is then structurally
# validated (JSON/YAML/XML/shell/PKGBUILD) using the tools available on the host.

set -euo pipefail

err() {
	printf '%s\n' "materialize.sh: $*" >&2
	exit 1
}

TAG="${1:-}"
[ -n "$TAG" ] || err "usage: ./distribution/materialize.sh vX.Y.Z [--asset-dir DIR] [--source-tarball FILE] [--nix-git-sri SRI] [--out-dir DIR]"
case "$TAG" in
v[0-9]*.[0-9]*.[0-9]*) ;;
*) err "invalid release tag '$TAG' (expected vMAJOR.MINOR.PATCH)" ;;
esac

ASSET_DIR=""
SOURCE_TARBALL=""
NIX_GIT_SRI=""
OUT_DIR="distribution/out"
while [ "$#" -gt 1 ]; do
	case "$2" in
	--asset-dir) ASSET_DIR="$3"; shift 2 ;;
	--source-tarball) SOURCE_TARBALL="$3"; shift 2 ;;
	--nix-git-sri) NIX_GIT_SRI="$3"; shift 2 ;;
	--out-dir) OUT_DIR="$3"; shift 2 ;;
	*) err "unknown option: $2" ;;
	esac
done

VERSION="${TAG#v}"
RELEASE_BASE_URL="https://github.com/zuli2021/zuli-proxybroker-extended/releases/download/$TAG"
WINDOWS_ASSET="proxybroker-$TAG-x86_64-pc-windows-msvc.zip"

[ -n "$VERSION" ] || err "could not derive the version from tag '$TAG'"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- source tarball hash ---------------------------------------------------
if [ -n "$SOURCE_TARBALL" ]; then
	[ -s "$SOURCE_TARBALL" ] || err "--source-tarball file is empty: $SOURCE_TARBALL"
	SOURCE_TARBALL_SHA256="$(sha256sum "$SOURCE_TARBALL" | awk '{print $1}')"
else
	if [ -n "$ASSET_DIR" ] && [ -s "$ASSET_DIR/../$TAG.tar.gz" ]; then
		SOURCE_TARBALL_SHA256="$(sha256sum "$ASSET_DIR/../$TAG.tar.gz" | awk '{print $1}')"
	else
		echo "Downloading the GitHub source archive $TAG.tar.gz ..."
		curl -fsSL -o "$work/$TAG.tar.gz" \
			"https://github.com/zuli2021/zuli-proxybroker-extended/archive/refs/tags/$TAG.tar.gz"
		SOURCE_TARBALL_SHA256="$(sha256sum "$work/$TAG.tar.gz" | awk '{print $1}')"
	fi
fi

# --- windows zip hash ------------------------------------------------------
if [ -n "$ASSET_DIR" ] && [ -s "$ASSET_DIR/$WINDOWS_ASSET" ]; then
	WINDOWS_ZIP_SHA256="$(sha256sum "$ASSET_DIR/$WINDOWS_ASSET" | awk '{print $1}')"
else
	echo "Downloading the canonical Windows release asset $WINDOWS_ASSET ..."
	curl -fsSL -o "$work/$WINDOWS_ASSET" "$RELEASE_BASE_URL/$WINDOWS_ASSET"
	WINDOWS_ZIP_SHA256="$(sha256sum "$work/$WINDOWS_ASSET" | awk '{print $1}')"
fi

# --- Nix SRI hashes --------------------------------------------------------
# base32 SRI (sha256-...) of the source tarball bytes, usable with fetchzip.
SOURCE_TARBALL_SRI="sha256-$(printf '%s' "$SOURCE_TARBALL_SHA256" | xxd -r -p | base32 | tr -d '=')"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

render() {
	sed -e "s|@TAG@|$TAG|g" \
		-e "s|@VERSION@|$VERSION|g" \
		-e "s|@RELEASE_BASE_URL@|$RELEASE_BASE_URL|g" \
		-e "s|@SOURCE_TARBALL_SHA256@|$SOURCE_TARBALL_SHA256|g" \
		-e "s|@SOURCE_TARBALL_SRI@|$SOURCE_TARBALL_SRI|g" \
		-e "s|@SOURCE_GIT_SRI@|${NIX_GIT_SRI:-@SOURCE_GIT_SRI@}|g" \
		-e "s|@WINDOWS_ZIP_SHA256@|$WINDOWS_ZIP_SHA256|g" \
		"$1"
}

# --- render each ecosystem template ----------------------------------------
render "distribution/winget/zuli2021.ZuliProxyBrokerExtended.yaml.template" \
	> "$OUT_DIR/zuli2021.ZuliProxyBrokerExtended.yaml"
render "distribution/scoop/zuli-proxybroker-extended.json.template" \
	> "$OUT_DIR/zuli-proxybroker-extended.json"
render "distribution/homebrew/zuli-proxybroker-extended.rb.template" \
	> "$OUT_DIR/zuli-proxybroker-extended.rb"
mkdir -p "$OUT_DIR/chocolatey"
render "distribution/chocolatey/zuli-proxybroker-extended.nuspec.template" \
	> "$OUT_DIR/chocolatey/zuli-proxybroker-extended.nuspec"
mkdir -p "$OUT_DIR/chocolatey/tools"
render "distribution/chocolatey/tools/chocolateyinstall.ps1.template" \
	> "$OUT_DIR/chocolatey/tools/chocolateyinstall.ps1"
mkdir -p "$OUT_DIR/aur"
render "distribution/aur/PKGBUILD.template" > "$OUT_DIR/aur/PKGBUILD"
mkdir -p "$OUT_DIR/termux"
render "distribution/termux/build.sh.template" > "$OUT_DIR/termux/build.sh"
if [ -n "$NIX_GIT_SRI" ]; then
	mkdir -p "$OUT_DIR/nixpkgs/zuli-proxybroker-extended"
	render "distribution/nixpkgs/package.nix.template" \
		> "$OUT_DIR/nixpkgs/zuli-proxybroker-extended/package.nix"
	cp Cargo.lock "$OUT_DIR/nixpkgs/zuli-proxybroker-extended/Cargo.lock"
else
	echo "Skipping the Nixpkgs template (no --nix-git-sri given)."
	echo "  Produce it with: nix-prefetch-git --url https://github.com/zuli2021/zuli-proxybroker-extended --rev $TAG"
	echo "  then re-run with --nix-git-sri '<result>'."
fi

# --- structural validation of the rendered output ---------------------------
if command -v python3 >/dev/null 2>&1; then
	python3 - "$OUT_DIR" <<'PYEOF'
import json, os, sys
try:
    import yaml
    HAVE_YAML = True
except Exception:
    HAVE_YAML = False
try:
    import xml.etree.ElementTree as ET
    HAVE_XML = True
except Exception:
    HAVE_XML = False

out = sys.argv[1]
checks = []

def check(name, ok):
    checks.append((name, ok))

win = os.path.join(out, "zuli2021.ZuliProxyBrokerExtended.yaml")
check("winget YAML parses", yaml.safe_load(open(win)) is not None if HAVE_YAML else False)
scoop = os.path.join(out, "zuli-proxybroker-extended.json")
json.load(open(scoop))
check("scoop JSON parses", True)
nuspec = os.path.join(out, "chocolatey", "zuli-proxybroker-extended.nuspec")
if HAVE_XML:
    ET.parse(nuspec)
    check("chocolatey nuspec XML parses", True)
else:
    check("chocolatey nuspec XML parses", False)

failed = [n for n, ok in checks if not ok]
for n, ok in checks:
    print(("PASS" if ok else "SKIP/FAIL") + "  " + n)
if failed:
    print("missing validator(s) for: " + ", ".join(failed))
    sys.exit(1)
PYEOF
fi
if command -v bash >/dev/null 2>&1; then
	bash -n "$OUT_DIR/aur/PKGBUILD" || err "rendered AUR PKGBUILD failed bash syntax"
	bash -n "$OUT_DIR/termux/build.sh" || err "rendered Termux build.sh failed bash syntax"
fi

printf '%s\n' "Materialized distribution manifests for $TAG into $OUT_DIR"
printf '%s\n' "Source tarball SHA-256:  $SOURCE_TARBALL_SHA256"
printf '%s\n' "Windows zip SHA-256:     $WINDOWS_ZIP_SHA256"
