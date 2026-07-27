#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
FAKE_BIN="$TEST_ROOT/bin"
COMMAND_LOG="$TEST_ROOT/commands.log"
mkdir -p "$FAKE_BIN"
touch "$COMMAND_LOG"
export COMMAND_LOG
export MOCK_KEYCHAIN="$TEST_ROOT/login.keychain-db"
export IDENTITY_MARKER="$TEST_ROOT/identity-created"
mkdir -p "$TEST_ROOT/tmp"

cat >"$FAKE_BIN/security" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    find-identity)
        [[ "${MOCK_IDENTITY_EXISTS:-0}" == "1" || -f "$IDENTITY_MARKER" ]] &&
            printf '  1) ABC "Codex Monitor Local Signing"\n'
        ;;
    default-keychain)
        printf '"%s"\n' "$MOCK_KEYCHAIN"
        ;;
    import|add-trusted-cert)
        [[ "$1" == "import" ]] && touch "$IDENTITY_MARKER"
        printf 'security' >>"$COMMAND_LOG"
        printf ' <%s>' "$@" >>"$COMMAND_LOG"
        printf '\n' >>"$COMMAND_LOG"
        ;;
esac
STUB
chmod +x "$FAKE_BIN/security"

cat >"$FAKE_BIN/openssl" <<'STUB'
#!/usr/bin/env bash
printf 'openssl' >>"$COMMAND_LOG"
printf ' <%s>' "$@" >>"$COMMAND_LOG"
printf '\n' >>"$COMMAND_LOG"
while (($#)); do
    case "$1" in
        -keyout|-out)
            target="$2"
            printf '临时测试材料\n' >"$target"
            shift 2
            ;;
        *) shift ;;
    esac
done
STUB
chmod +x "$FAKE_BIN/openssl"

PATH="$FAKE_BIN:$PATH" TMPDIR="$TEST_ROOT/tmp" \
    bash "$ROOT/scripts/setup-local-signing.sh"

grep -F '<import>' "$COMMAND_LOG"
grep -F '<-T> </usr/bin/codesign>' "$COMMAND_LOG"
grep -F '<add-trusted-cert>' "$COMMAND_LOG"
grep -F '<-p> <codeSign>' "$COMMAND_LOG"
grep -F '<extendedKeyUsage=codeSigning>' "$COMMAND_LOG"

if find "$TEST_ROOT/tmp" -type f \
    \( -name 'private-key.pem' -o -name 'certificate.pem' \) \
    | grep -q .; then
    echo "临时签名材料未清理"
    exit 1
fi

: >"$COMMAND_LOG"
rm -f "$IDENTITY_MARKER"
MOCK_IDENTITY_EXISTS=1 PATH="$FAKE_BIN:$PATH" \
    bash "$ROOT/scripts/setup-local-signing.sh"
if grep -Fq 'openssl' "$COMMAND_LOG"; then
    echo "已有身份时不应重新生成"
    exit 1
fi
