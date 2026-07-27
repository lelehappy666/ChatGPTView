#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/security" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_IDENTITIES:-}"
STUB
chmod +x "$TMP/security"

source "$ROOT/scripts/signing-identity.sh"

CODE_SIGN_IDENTITY="Apple Development: Tester"
[[ "$(PATH="$TMP:$PATH" resolve_signing_identity)" == "$CODE_SIGN_IDENTITY" ]]

unset CODE_SIGN_IDENTITY
MOCK_IDENTITIES='  1) ABC "Codex Monitor Local Signing"'
export MOCK_IDENTITIES
[[ "$(PATH="$TMP:$PATH" resolve_signing_identity)" == "Codex Monitor Local Signing" ]]

MOCK_IDENTITIES=""
export MOCK_IDENTITIES
if PATH="$TMP:$PATH" resolve_signing_identity >/dev/null 2>&1; then
    echo "缺少身份时不应成功"
    exit 1
fi
