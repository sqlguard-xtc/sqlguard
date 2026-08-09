#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'SqlGuard action failed: %s\n' "$1" >&2
  exit 1
}

require_single_line() {
  local name="$1"
  local value="$2"
  [[ -n "$value" ]] || fail "${name} must not be empty."
  case "$value" in
    *$'\r'*|*$'\n'*) fail "${name} must be a single line." ;;
  esac
}

action_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spec="${SQLGUARD_ACTION_SPEC:-}"
version="${SQLGUARD_ACTION_VERSION:-latest}"
format="${SQLGUARD_ACTION_FORMAT:-junit}"
output="${SQLGUARD_ACTION_OUTPUT:-sqlguard-results.xml}"
runner_temp="${RUNNER_TEMP:-}"
github_output="${GITHUB_OUTPUT:-}"

require_single_line 'spec' "$spec"
require_single_line 'version' "$version"
require_single_line 'format' "$format"
require_single_line 'output' "$output"
require_single_line 'RUNNER_TEMP' "$runner_temp"
require_single_line 'GITHUB_OUTPUT' "$github_output"

case "$format" in
  json|junit) ;;
  *) fail "format must be 'json' or 'junit'." ;;
esac

install_directory="${SQLGUARD_ACTION_INSTALL_DIR:-${runner_temp}/sqlguard-bin}"
require_single_line 'install directory' "$install_directory"

bash "${action_root}/install.sh" --version "$version" --install-dir "$install_directory"
executable="${install_directory}/sqlguard"
[[ -x "$executable" ]] || fail "installed executable was not found at '${executable}'."

"$executable" validate-spec --spec "$spec"
"$executable" run --spec "$spec" --format "$format" --out "$output"

printf 'report=%s\n' "$output" >> "$github_output"
