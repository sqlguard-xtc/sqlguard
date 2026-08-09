#!/usr/bin/env bash
set -euo pipefail

repository="xtcsystems/sqlguard"
version="latest"
install_directory="${SQLGUARD_INSTALL_DIR:-${HOME}/.local/bin}"
asset_directory="${SQLGUARD_INSTALLER_ASSET_DIR:-}"
skip_execution_check="${SQLGUARD_INSTALLER_SKIP_EXECUTION_CHECK:-0}"
platform_override="${SQLGUARD_INSTALLER_PLATFORM_OVERRIDE:-}"
temporary_directory=""
staged_executable=""

usage() {
  cat <<'EOF'
Install SqlGuard from a checksum-verified GitHub Release.

Usage: install.sh [--version <version|latest>] [--install-dir <directory>]
EOF
}

fail() {
  printf 'SqlGuard installation failed: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ -n "$staged_executable" && -e "$staged_executable" ]]; then
    rm -f -- "$staged_executable"
  fi
  if [[ -n "$temporary_directory" && -d "$temporary_directory" ]]; then
    rm -rf -- "$temporary_directory"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail '--version requires a value.'
      version="$2"
      shift 2
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || fail '--install-dir requires a value.'
      install_directory="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument '$1'."
      ;;
  esac
done

if [[ -n "$platform_override" ]]; then
  platform="$platform_override"
else
  [[ "$(uname -s)" == "Linux" ]] || fail 'This installer supports Linux only. Use install.ps1 on Windows.'
  [[ "$(uname -m)" == "x86_64" ]] || fail 'SqlGuard currently supports Linux x64 only.'
  platform="linux-x64"
fi
[[ "$platform" == "linux-x64" ]] || fail "Unsupported installer platform '$platform'."
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required to verify the release.'

if [[ "$version" == "latest" ]]; then
  if [[ -n "$asset_directory" ]]; then
    mapfile -t checksum_candidates < <(find "$asset_directory" -maxdepth 1 -type f -name 'sqlguard-v*-checksums.txt' -print)
    [[ ${#checksum_candidates[@]} -eq 1 ]] || fail 'Offline latest-version resolution requires exactly one versioned checksum file.'
    checksum_base="$(basename "${checksum_candidates[0]}")"
    tag="${checksum_base#sqlguard-}"
    tag="${tag%-checksums.txt}"
  else
    command -v curl >/dev/null 2>&1 || fail 'curl is required to resolve and download a release.'
    release_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "https://github.com/${repository}/releases/latest")"
    tag="${release_url##*/}"
  fi
else
  tag="$version"
  [[ "$tag" == v* ]] || tag="v${tag}"
fi

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]] || fail "Invalid release tag '$tag'."
version_text="${tag#v}"
asset_name="sqlguard-v${version_text}-linux-x64"
checksum_name="sqlguard-v${version_text}-checksums.txt"

temporary_directory="$(mktemp -d)"
downloaded_asset="${temporary_directory}/${asset_name}"
downloaded_checksums="${temporary_directory}/${checksum_name}"

if [[ -n "$asset_directory" ]]; then
  [[ -f "${asset_directory}/${asset_name}" ]] || fail "Required offline asset '${asset_name}' was not found."
  [[ -f "${asset_directory}/${checksum_name}" ]] || fail "Required offline asset '${checksum_name}' was not found."
  cp -- "${asset_directory}/${asset_name}" "$downloaded_asset"
  cp -- "${asset_directory}/${checksum_name}" "$downloaded_checksums"
else
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download a release.'
  release_base="https://github.com/${repository}/releases/download/${tag}"
  curl -fsSL "${release_base}/${asset_name}" -o "$downloaded_asset"
  curl -fsSL "${release_base}/${checksum_name}" -o "$downloaded_checksums"
fi

if ! expected_checksum="$(
  awk -v target="$asset_name" '
    ($2 == target || $2 == "*" target) && $1 ~ /^[0-9A-Fa-f]{64}$/ {
      print tolower($1)
      count++
    }
    END { if (count != 1) exit 42 }
  ' "$downloaded_checksums"
)"; then
  fail "Checksum manifest must contain exactly one SHA-256 entry for '${asset_name}'."
fi

actual_checksum="$(sha256sum "$downloaded_asset" | awk '{ print tolower($1) }')"
[[ "$actual_checksum" == "$expected_checksum" ]] || fail "Checksum verification failed for '${asset_name}'."

mkdir -p -- "$install_directory"
destination="${install_directory}/sqlguard"
staged_executable="${install_directory}/.sqlguard.$$.tmp"
cp -- "$downloaded_asset" "$staged_executable"
chmod 0755 "$staged_executable"

if [[ "$skip_execution_check" != "1" ]]; then
  "$staged_executable" --version
fi

mv -f -- "$staged_executable" "$destination"
staged_executable=""

printf "Installed SqlGuard %s to '%s'.\n" "$tag" "$destination"
printf 'Verified SHA-256: %s\n' "$actual_checksum"
case ":${PATH}:" in
  *":${install_directory}:"*) ;;
  *) printf "Add '%s' to PATH or invoke '%s' directly.\n" "$install_directory" "$destination" ;;
esac
