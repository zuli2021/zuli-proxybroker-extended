#!/usr/bin/env bash
# Modified by Zuli2021 in 2026 for Zuli ProxyBroker Extended.
# See NOTICE for attribution and the statement of changes.
# Build the proxybroker CLI for aarch64-linux-android with the SAME default feature set as
# desktop (cli, server, geo, geo-bundled). This script is the single source of truth for the
# Android build command so CI and the release workflow cannot silently drift.
#
# Requirements:
#   - The aarch64-linux-android Rust target is installed: `rustup target add aarch64-linux-android`
#   - ANDROID_NDK_HOME points at the current Android NDK LTS (r27d as of 2026-08-08).
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/android-ndk-r27d ./scripts/build-android.sh [v1.1.0]
#
# The optional argument is the release tag used to name the packaged archive. Without it, the
# script builds and validates the artifact but does not package a release archive.
#
# Outputs:
#   target/aarch64-linux-android/release/proxybroker        the built binary
#   target/android-release/proxybroker-$TAG-aarch64-linux-android.tar.gz   (with a tag arg)
#   target/android-release/proxybroker-$TAG-aarch64-linux-android.sha256   (with a tag arg)
#
# The archive contains the binary plus LICENSE, LICENSE-DATA, NOTICE, and README.md, and the
# SHA-256 asset uses the standard "hash  name" record format of the canonical release assets.

set -euo pipefail

err() {
	printf '%s\n' "build-android.sh: $*" >&2
	exit 1
}

TAG="${1:-}"
API_LEVEL="${ANDROID_API_LEVEL:-21}"
NDK_HOME="${ANDROID_NDK_HOME:-}"
TARGET="aarch64-linux-android"
BIN="target/$TARGET/release/proxybroker"
OUT_DIR="${ANDROID_OUT_DIR:-target/android-release}"

[ -n "$NDK_HOME" ] || err "ANDROID_NDK_HOME is required (set it to an extracted Android NDK LTS directory)"

case "$(uname -s)" in
Linux)
	case "$(uname -m)" in
	x86_64 | amd64) HOST_TAG="linux-x86_64" ;;
	aarch64 | arm64) HOST_TAG="linux-aarch64" ;;
	*) err "unsupported host architecture for the NDK: $(uname -m)" ;;
	esac
	;;
Darwin)
	HOST_TAG="darwin-x86_64"
	;;
*)
	err "unsupported host OS for the NDK: $(uname -s)"
	;;
esac

TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG"
[ -d "$TOOLCHAIN" ] || err "NDK LLVM prebuilt toolchain not found at: $TOOLCHAIN"

LINKER="$TOOLCHAIN/bin/$TARGET${API_LEVEL}-clang"
[ -x "$LINKER" ] || err "NDK linker not found: $LINKER (expected the NDK clang wrapper for API level $API_LEVEL)"

# Point cargo and the cc crate (ring's build script) at the NDK binutils. API level 21 is
# Rust's default minimum for aarch64-linux-android. The cc crate probes the underscore form
# (CC_<target> with dashes replaced by underscores), so only that spelling is exported.
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$LINKER"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="$TOOLCHAIN/bin/llvm-ar"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_STRIP="$TOOLCHAIN/bin/llvm-strip"
export CC_aarch64_linux_android="$LINKER"
export AR_aarch64_linux_android="$TOOLCHAIN/bin/llvm-ar"

echo "Building proxybroker for $TARGET with the default feature set (cli, server, geo, geo-bundled)..."
cargo build --release --locked --target "$TARGET"
[ -f "$BIN" ] || err "expected built binary not found: $BIN"

echo "Verifying the artifact is an AArch64 Android ELF..."
file "$BIN"
printf '%s\n' "---"
file "$BIN" | grep -q 'ELF 64-bit LSB' || err "artifact is not an ELF 64-bit binary"
file "$BIN" | grep -q 'ARM aarch64' || err "artifact is not AArch64"

READELF="$TOOLCHAIN/bin/llvm-readelf"
if [ -x "$READELF" ]; then
	"$READELF" -h "$BIN" | sed -n '1,14p'
	printf '%s\n' "--- dynamic dependencies ---"
	"$READELF" -d "$BIN" | grep -E 'NEEDED' || true
else
	printf '%s\n' "llvm-readelf not available; architecture check was done with file(1)"
fi

if [ -n "$TAG" ]; then
	echo "Packaging release archive for $TAG..."
	STAGE="$(mktemp -d)"
	trap 'rm -rf "$STAGE"' EXIT
	ARCHIVE_DIR="$STAGE/payload"
	mkdir -p "$ARCHIVE_DIR"
	cp "$BIN" "$ARCHIVE_DIR/proxybroker"
	for legal_file in LICENSE LICENSE-DATA NOTICE README.md; do
		[ -f "$legal_file" ] || err "missing required file for the release archive: $legal_file"
		cp "$legal_file" "$ARCHIVE_DIR/$legal_file"
	done

	BASE="proxybroker-$TAG-$TARGET"
	ARCHIVE="$BASE.tar.gz"
	CHECKSUM="$BASE.sha256"
	mkdir -p "$OUT_DIR"
	tar -czf "$OUT_DIR/$ARCHIVE" -C "$ARCHIVE_DIR" proxybroker LICENSE LICENSE-DATA NOTICE README.md
	(
		cd "$OUT_DIR"
		sha256sum "$ARCHIVE" > "$CHECKSUM"
	)
	[ -s "$OUT_DIR/$ARCHIVE" ] || err "packaged archive is empty"
	[ -s "$OUT_DIR/$CHECKSUM" ] || err "packaged checksum is empty"
	# The canonical release checksum record is exactly one line: "<hash>  <archive>".
	test "$(wc -l < "$OUT_DIR/$CHECKSUM")" = '1' || err "packaged checksum must contain exactly one line"
	printf 'Archive:  %s\n' "$OUT_DIR/$ARCHIVE"
	printf 'Checksum: %s\n' "$OUT_DIR/$CHECKSUM"
	printf '%s\n' "SHA-256:"
	cat "$OUT_DIR/$CHECKSUM"
fi

printf '%s\n' "Android build OK."
