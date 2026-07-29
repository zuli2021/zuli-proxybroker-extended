#!/bin/sh
# proxybroker installer — downloads the release binary for your OS/arch, verifies its checksum,
# and installs it to user directories. No sudo, no build toolchain.
#
#   curl -fsSL https://raw.githubusercontent.com/zuli2021/zuli-proxybroker-extended/main/install.sh | sh
#
# Environment overrides:
#   PROXYBROKER_VERSION   release tag to install (default: the latest release)
#   PROXYBROKER_BIN_DIR   install directory     (default: $HOME/.local/bin)
#   PROXYBROKER_DOC_DIR   notice directory      (default: $HOME/.local/share/doc/zuli-proxybroker-extended)
set -eu

REPO="zuli2021/zuli-proxybroker-extended"
BIN="proxybroker"
BIN_DIR="${PROXYBROKER_BIN_DIR:-$HOME/.local/bin}"
DOC_DIR="${PROXYBROKER_DOC_DIR:-$HOME/.local/share/doc/zuli-proxybroker-extended}"
tmp=""
install_tmp=""

err() {
	printf '%s\n' "install.sh: $*" >&2
	exit 1
}

cleanup() {
	if [ -n "$install_tmp" ]; then
		rm -f "$install_tmp" >/dev/null 2>&1 || :
	fi
	if [ -n "$tmp" ]; then
		rm -rf "$tmp" >/dev/null 2>&1 || :
	fi
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || err "$1 is required"
}

require_command curl
require_command tar
require_command mktemp
require_command install
require_command mv

# Resolve the version (default: latest release tag).
VERSION="${PROXYBROKER_VERSION:-}"
if [ -z "$VERSION" ]; then
	VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
		grep '"tag_name"' | head -1 | cut -d'"' -f4)
fi
[ -n "$VERSION" ] || err "could not resolve the latest release version"

# Detect OS/arch and map to a release target triple.
os=$(uname -s)
arch=$(uname -m)
case "$os" in
Linux)
	case "$arch" in
	x86_64 | amd64) target="x86_64-unknown-linux-musl" ;;
	aarch64 | arm64) target="aarch64-unknown-linux-musl" ;;
	*) err "unsupported architecture: $arch" ;;
	esac
	;;
Darwin)
	case "$arch" in
	x86_64 | amd64) target="x86_64-apple-darwin" ;;
	arm64 | aarch64) target="aarch64-apple-darwin" ;;
	*) err "unsupported architecture: $arch" ;;
	esac
	;;
*) err "unsupported OS: $os" ;;
esac

asset="$BIN-$VERSION-$target.tar.gz"
checksum_asset="$BIN-$VERSION-$target.sha256"
base="https://github.com/$REPO/releases/download/$VERSION"
tmp=$(mktemp -d) || err "could not create a temporary directory"
[ -n "$tmp" ] || err "could not create a temporary directory"
trap cleanup 0

archive_path="$tmp/$asset"
checksum_path="$tmp/$checksum_asset"
verification_path="$tmp/$asset.verified.sha256"
extract_dir="$tmp/extracted"

printf 'Downloading %s ...\n' "$asset"
curl -fsSL "$base/$asset" -o "$archive_path" ||
	err "failed to download release archive: $asset"
curl -fsSL "$base/$checksum_asset" -o "$checksum_path" ||
	err "failed to download SHA-256 checksum: $checksum_asset"
[ -s "$archive_path" ] || err "downloaded archive is empty: $asset"
[ -s "$checksum_path" ] || err "downloaded SHA-256 checksum is empty: $checksum_asset"

# The release action writes a SHA-256 asset. Accept either a bare digest or a
# standard digest-and-filename record, but require exactly one valid SHA-256
# digest before translating it into the selected verifier's input format.
checksum_record_count=0
expected_hash=""
while IFS= read -r checksum_line || [ -n "$checksum_line" ]; do
	checksum_record_count=$((checksum_record_count + 1))
	[ "$checksum_record_count" -eq 1 ] || err "malformed SHA-256 checksum data"

	expected_hash=${checksum_line%%[!0123456789abcdefABCDEF]*}
	remainder=${checksum_line#"$expected_hash"}
	[ -n "$expected_hash" ] || err "malformed SHA-256 checksum data"
	[ "${#expected_hash}" -eq 64 ] || err "malformed SHA-256 checksum data"
	case "$remainder" in
	"") ;;
	[[:space:]]*) ;;
	*) err "malformed SHA-256 checksum data" ;;
	esac
done < "$checksum_path"
[ "$checksum_record_count" -eq 1 ] || err "empty SHA-256 checksum data"

printf 'Verifying SHA-256 checksum ...\n'
printf '%s  %s\n' "$expected_hash" "$asset" > "$verification_path" ||
	err "could not prepare SHA-256 verification data"
if command -v sha256sum >/dev/null 2>&1; then
	(cd "$tmp" && sha256sum -c "$verification_path" >/dev/null) ||
		err "SHA-256 checksum mismatch"
elif command -v shasum >/dev/null 2>&1; then
	(cd "$tmp" && shasum -a 256 -c "$verification_path" >/dev/null) ||
		err "SHA-256 checksum mismatch"
else
	err "SHA-256 verification is mandatory; install sha256sum or shasum"
fi

mkdir -p "$extract_dir" || err "could not create extraction directory"
tar -xzf "$archive_path" -C "$extract_dir" ||
	err "could not extract release archive: $asset"

for required_file in "$BIN" LICENSE NOTICE LICENSE-DATA; do
	[ -f "$extract_dir/$required_file" ] ||
		err "archive is missing required file: $required_file"
done

[ ! -d "$BIN_DIR/$BIN" ] || err "binary destination is a directory: $BIN_DIR/$BIN"
for legal_file in LICENSE NOTICE LICENSE-DATA; do
	[ ! -d "$DOC_DIR/$legal_file" ] ||
		err "documentation destination is a directory: $DOC_DIR/$legal_file"
done

mkdir -p "$DOC_DIR" || err "could not create documentation directory: $DOC_DIR"
mkdir -p "$BIN_DIR" || err "could not create binary directory: $BIN_DIR"

for legal_file in LICENSE NOTICE LICENSE-DATA; do
	install_tmp=$(mktemp "$DOC_DIR/.${legal_file}.XXXXXX") ||
		err "could not create temporary documentation file"
	install -m 0644 "$extract_dir/$legal_file" "$install_tmp" ||
		err "could not install $legal_file"
	mv -f "$install_tmp" "$DOC_DIR/$legal_file" ||
		err "could not finalize installation of $legal_file"
	install_tmp=""
done

install_tmp=$(mktemp "$BIN_DIR/.${BIN}.XXXXXX") ||
	err "could not create temporary binary file"
install -m 0755 "$extract_dir/$BIN" "$install_tmp" ||
	err "could not install $BIN"
mv -f "$install_tmp" "$BIN_DIR/$BIN" ||
	err "could not finalize installation of $BIN"
install_tmp=""

printf '\nInstalled binary: %s\n' "$BIN_DIR/$BIN"
printf 'Documentation directory: %s\n' "$DOC_DIR"
printf 'Version: %s\n' "$VERSION"
printf 'Target: %s\n' "$target"
printf 'IP Geolocation by DB-IP (https://db-ip.com), licensed CC BY 4.0\n'
case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) printf 'Note: %s is not on your PATH - add it, e.g. export PATH="%s:%s"\n' "$BIN_DIR" "$BIN_DIR" "\$PATH" ;;
esac
