#!/usr/bin/env bash
set -euo pipefail

repo_root="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
  pwd
)"
test_root="$(mktemp -d)"
cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

version="v0.4.2"
target="x86_64-unknown-linux-musl"
archive="proxybroker-$version-$target.tar.gz"
checksum="proxybroker-$version-$target.sha256"
base_url="https://github.com/zuli2021/zuli-proxybroker-extended/releases/download/$version"
fixture_dir="$test_root/fixtures"
payload_dir="$test_root/payload"
mock_bin="$test_root/mock-bin"
install_bin="$test_root/install/bin"
install_doc="$test_root/install/doc"
curl_log="$test_root/curl.log"
mkdir -p "$fixture_dir" "$payload_dir" "$mock_bin"

cat > "$payload_dir/proxybroker" <<'EOF'
#!/bin/sh
printf '%s\n' 'proxybroker 0.4.2'
printf '%s\n' 'IP Geolocation by DB-IP'
EOF
chmod 0755 "$payload_dir/proxybroker"
printf '%s\n' 'fixture LICENSE' > "$payload_dir/LICENSE"
printf '%s\n' 'fixture LICENSE-DATA' > "$payload_dir/LICENSE-DATA"
printf '%s\n' 'fixture NOTICE' > "$payload_dir/NOTICE"
printf '%s\n' 'fixture README' > "$payload_dir/README.md"

tar -czf "$fixture_dir/$archive" \
  -C "$payload_dir" \
  proxybroker LICENSE LICENSE-DATA NOTICE README.md
(
  cd "$fixture_dir"
  sha256sum "$archive" > "$checksum"
)
test ! -e "$fixture_dir/$archive.sha256"

cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 || "$1" != "-fsSL" || "$3" != "-o" ]]; then
  printf 'mock curl: unexpected arguments:' >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  exit 1
fi

url="$2"
destination="$4"
printf '%s\n' "$url" >> "$CURL_LOG"

case "$url" in
"$EXPECTED_ARCHIVE_URL")
  source_path="$FIXTURE_DIR/$EXPECTED_ARCHIVE"
  ;;
"$EXPECTED_CHECKSUM_URL")
  source_path="$FIXTURE_DIR/$EXPECTED_CHECKSUM"
  ;;
*)
  printf 'mock curl: unexpected URL: %s\n' "$url" >&2
  exit 1
  ;;
esac

cp -- "$source_path" "$destination"
EOF
chmod 0755 "$mock_bin/curl"

export CURL_LOG="$curl_log"
export EXPECTED_ARCHIVE="$archive"
export EXPECTED_CHECKSUM="$checksum"
export EXPECTED_ARCHIVE_URL="$base_url/$archive"
export EXPECTED_CHECKSUM_URL="$base_url/$checksum"
export FIXTURE_DIR="$fixture_dir"

install_output="$(
  PATH="$mock_bin:$PATH" \
    PROXYBROKER_VERSION="$version" \
    PROXYBROKER_BIN_DIR="$install_bin" \
    PROXYBROKER_DOC_DIR="$install_doc" \
    sh "$repo_root/install.sh"
)"
printf '%s\n' "$install_output"

mapfile -t requested_urls < "$curl_log"
test "${#requested_urls[@]}" -eq 2
test "${requested_urls[0]}" = "$EXPECTED_ARCHIVE_URL"
test "${requested_urls[1]}" = "$EXPECTED_CHECKSUM_URL"
if grep -F '.tar.gz.sha256' "$curl_log" >/dev/null; then
  printf '%s\n' 'legacy .tar.gz.sha256 URL was requested' >&2
  exit 1
fi

test -x "$install_bin/proxybroker"
binary_output="$("$install_bin/proxybroker" --version)"
printf '%s\n' "$binary_output"
grep -F 'proxybroker 0.4.2' <<<"$binary_output" >/dev/null
grep -F 'IP Geolocation by DB-IP' <<<"$binary_output" >/dev/null
grep -F 'Verifying SHA-256 checksum ...' <<<"$install_output" >/dev/null

for legal_file in LICENSE LICENSE-DATA NOTICE; do
  test -f "$install_doc/$legal_file"
  cmp "$payload_dir/$legal_file" "$install_doc/$legal_file"
done

printf 'Requested archive URL: %s\n' "$EXPECTED_ARCHIVE_URL"
printf 'Requested checksum URL: %s\n' "$EXPECTED_CHECKSUM_URL"
printf '%s\n' 'Legacy .tar.gz.sha256 URL requested: no'
printf '%s\n' 'Installed binary, checksum verification, legal files, version, and attribution verified.'
