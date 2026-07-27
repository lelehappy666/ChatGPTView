#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
FAKE_BIN="$TEST_ROOT/bin"
COMMAND_LOG="$TEST_ROOT/commands.log"
MOCK_KEYCHAIN="$TEST_ROOT/keychains/login keychain-db"
IDENTITY_MARKER="$TEST_ROOT/identity-created"
ROLLBACK_MARKER="$TEST_ROOT/identity-rolled-back"
GENERATED_CERTIFICATE="$TEST_ROOT/generated-certificate.pem"
EXPECTED_FINGERPRINT_FILE="$TEST_ROOT/certificate-fingerprint"
mkdir -p "$FAKE_BIN" "$TEST_ROOT/tmp" "${MOCK_KEYCHAIN%/*}"
touch "$COMMAND_LOG"
export COMMAND_LOG MOCK_KEYCHAIN IDENTITY_MARKER ROLLBACK_MARKER
export GENERATED_CERTIFICATE EXPECTED_FINGERPRINT_FILE

cat >"$FAKE_BIN/security" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

args=("$@")

fail() {
    echo "security 假命令参数错误：$*" >&2
    exit 90
}

record() {
    printf '%s\t' "${args[@]}" >>"$COMMAND_LOG"
    printf '\n' >>"$COMMAND_LOG"
}

reject_forbidden_access() {
    local argument
    for argument in "${args[@]}"; do
        case "$argument" in
            -A) fail "不得使用 -A 允许所有应用访问私钥" ;;
            -d) fail "不得使用 -d 添加管理员信任" ;;
        esac
    done
}

case "${args[0]:-}" in
    find-identity)
        if ((${#args[@]} == 4)); then
            [[ "${args[*]}" == "find-identity -v -p codesigning" ]] || fail "初始身份查询"
        elif ((${#args[@]} == 5)); then
            [[ "${args[1]}" == "-v" && "${args[2]}" == "-p" &&
                "${args[3]}" == "codesigning" && "${args[4]}" == "$MOCK_KEYCHAIN" ]] ||
                fail "最终身份查询"
        else
            fail "find-identity 参数数量"
        fi
        record
        if [[ "${MOCK_IDENTITY_EXISTS:-0}" == "1" ||
            ( -f "$IDENTITY_MARKER" && "${MOCK_FAIL_AT:-}" != "verify" ) ]]; then
            printf '  1) ABC "Codex Monitor Local Signing"\n'
        fi
        ;;
    default-keychain)
        [[ "${args[*]}" == "default-keychain -d user" ]] || fail "默认钥匙串查询"
        record
        printf '"%s"\n' "$MOCK_KEYCHAIN"
        ;;
    import)
        reject_forbidden_access
        [[ ${#args[@]} -eq 6 && "${args[1]}" == */private-key.pem &&
            "${args[2]}" == "-k" && "${args[3]}" == "$MOCK_KEYCHAIN" &&
            "${args[4]}" == "-T" && "${args[5]}" == "/usr/bin/codesign" ]] ||
            fail "导入必须仅授权 /usr/bin/codesign，且参数顺序固定"
        record
        touch "$IDENTITY_MARKER"
        ;;
    add-trusted-cert)
        reject_forbidden_access
        [[ ${#args[@]} -eq 8 && "${args[1]}" == "-r" &&
            "${args[2]}" == "trustRoot" && "${args[3]}" == "-p" &&
            "${args[4]}" == "codeSign" && "${args[5]}" == "-k" &&
            "${args[6]}" == "$MOCK_KEYCHAIN" && "${args[7]}" == */certificate.pem ]] ||
            fail "代码签名信任参数或顺序错误"
        cp "${args[7]}" "$GENERATED_CERTIFICATE"
        openssl x509 -in "${args[7]}" -noout -fingerprint -sha256 \
            | sed -E 's/.*=//; s/://g' >"$EXPECTED_FINGERPRINT_FILE"
        record
        [[ "${MOCK_FAIL_AT:-}" != "trust" ]] || exit 42
        ;;
    delete-identity)
        [[ -s "$EXPECTED_FINGERPRINT_FILE" ]] || fail "回滚前没有本次证书指纹"
        expected_fingerprint="$(<"$EXPECTED_FINGERPRINT_FILE")"
        [[ ${#args[@]} -eq 5 && "${args[1]}" == "-Z" &&
            "${args[2]}" == "$expected_fingerprint" && "${args[3]}" == "-t" &&
            "${args[4]}" == "$MOCK_KEYCHAIN" ]] ||
            fail "回滚必须仅按本次证书指纹删除身份"
        record
        rm -f "$IDENTITY_MARKER"
        touch "$ROLLBACK_MARKER"
        ;;
    *)
        fail "未知命令 ${args[0]:-}"
        ;;
esac
STUB
chmod +x "$FAKE_BIN/security"

run_setup() {
    PATH="$FAKE_BIN:$PATH" TMPDIR="$TEST_ROOT/tmp" \
        bash "$ROOT/scripts/setup-local-signing.sh"
}

reset_case() {
    : >"$COMMAND_LOG"
    rm -f "$IDENTITY_MARKER" "$ROLLBACK_MARKER" "$GENERATED_CERTIFICATE" \
        "$EXPECTED_FINGERPRINT_FILE"
}

assert_command_order() {
    local expected="$1"
    local actual
    actual="$(awk -F '\t' '{print $1}' "$COMMAND_LOG" | paste -sd, -)"
    [[ "$actual" == "$expected" ]] || {
        echo "命令顺序错误：期望 $expected，实际 $actual" >&2
        exit 1
    }
}

reset_case
run_setup
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,find-identity'
[[ -f "$IDENTITY_MARKER" ]]
[[ ! -e "$ROLLBACK_MARKER" ]]
[[ -f "$GENERATED_CERTIFICATE" ]]
openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext basicConstraints \
    | grep -Fq 'CA:TRUE'
openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext keyUsage \
    | grep -Fq 'Digital Signature, Certificate Sign'
openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext extendedKeyUsage \
    | grep -Fq 'Code Signing'

if find "$TEST_ROOT/tmp" -type f \
    \( -name 'private-key.pem' -o -name 'certificate.pem' \) \
    | grep -q .; then
    echo "临时签名材料未清理"
    exit 1
fi

reset_case
if MOCK_FAIL_AT=trust run_setup; then
    echo "信任失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,delete-identity'
[[ -f "$ROLLBACK_MARKER" && ! -e "$IDENTITY_MARKER" ]]

reset_case
if MOCK_FAIL_AT=verify run_setup; then
    echo "最终身份校验失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,find-identity,delete-identity'
[[ -f "$ROLLBACK_MARKER" && ! -e "$IDENTITY_MARKER" ]]

reset_case
MOCK_IDENTITY_EXISTS=1 run_setup
assert_command_order 'find-identity'
[[ ! -e "$GENERATED_CERTIFICATE" ]]
