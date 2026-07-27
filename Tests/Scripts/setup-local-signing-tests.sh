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
GENERATED_IDENTITY="$TEST_ROOT/generated-identity.p12"
GENERATED_IDENTITY_PASSWORD="$TEST_ROOT/generated-identity-password"
CERTIFICATE_ONLY_IDENTITY="$TEST_ROOT/certificate-only/identity.p12"
IMPORT_VALIDATION_DIR="$TEST_ROOT/import-validation"
EXPECTED_FINGERPRINT_FILE="$TEST_ROOT/certificate-fingerprint"
ROLLBACK_OUTPUT="$TEST_ROOT/rollback-output.log"
CERTIFICATE_ONLY_OUTPUT="$TEST_ROOT/certificate-only-output.log"
INVALID_KEYCHAIN_OUTPUT="$TEST_ROOT/invalid-keychain-output.log"
mkdir -p "$FAKE_BIN" "$TEST_ROOT/tmp" "${MOCK_KEYCHAIN%/*}"
touch "$COMMAND_LOG"
export COMMAND_LOG MOCK_KEYCHAIN IDENTITY_MARKER ROLLBACK_MARKER
export GENERATED_CERTIFICATE GENERATED_IDENTITY IMPORT_VALIDATION_DIR
export GENERATED_IDENTITY_PASSWORD EXPECTED_FINGERPRINT_FILE

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
        case "${MOCK_DEFAULT_KEYCHAIN_OUTPUT:-valid}" in
            unpaired) printf '    "%s\n' "$MOCK_KEYCHAIN" ;;
            empty) printf '    ""\n' ;;
            *) printf '    "%s"\n' "$MOCK_KEYCHAIN" ;;
        esac
        ;;
    import)
        record
        reject_forbidden_access
        [[ ${#args[@]} -eq 8 && "${args[1]}" == */identity.p12 &&
            "${args[2]}" == "-k" && "${args[3]}" == "$MOCK_KEYCHAIN" &&
            "${args[4]}" == "-P" && "${args[5]}" =~ ^[0-9a-f]{64}$ &&
            "${args[6]}" == "-T" && "${args[7]}" == "/usr/bin/codesign" ]] ||
            fail "导入必须使用随机 256 位口令，且仅授权 /usr/bin/codesign"
        identity_password="${args[5]}"
        pkcs12_info="$(
            openssl pkcs12 -in "${args[1]}" \
                -passin "pass:$identity_password" -info -noout 2>&1
        )"
        grep -Fiq 'MAC: sha1' <<<"$pkcs12_info" ||
            fail "PKCS#12 必须使用 macOS 兼容的 SHA-1 MAC"
        [[ "$(grep -Fic 'pbeWithSHA1And3-KeyTripleDES-CBC' <<<"$pkcs12_info")" -ge 2 ]] ||
            fail "PKCS#12 的证书和私钥必须使用显式 3DES 兼容加密"
        rm -rf "$IMPORT_VALIDATION_DIR"
        mkdir -p "$IMPORT_VALIDATION_DIR"
        certificate_file="$IMPORT_VALIDATION_DIR/certificate.pem"
        private_key_file="$IMPORT_VALIDATION_DIR/private-key.pem"
        openssl pkcs12 -in "${args[1]}" -passin "pass:$identity_password" \
            -clcerts -nokeys -out "$certificate_file"
        openssl x509 -in "$certificate_file" -noout
        openssl pkcs12 -in "${args[1]}" -passin "pass:$identity_password" \
            -nocerts -nodes -out "$private_key_file"
        openssl pkey -in "$private_key_file" -noout
        certificate_public_key="$({
            openssl x509 -in "$certificate_file" -pubkey -noout \
                | openssl pkey -pubin -outform DER \
                | openssl dgst -sha256 -r \
                | awk '{print $1}'
        })"
        private_public_key="$({
            openssl pkey -in "$private_key_file" -pubout -outform DER \
                | openssl dgst -sha256 -r \
                | awk '{print $1}'
        })"
        [[ -n "$certificate_public_key" && "$certificate_public_key" == "$private_public_key" ]] ||
            fail "PKCS#12 证书与私钥不匹配"
        cp "${args[1]}" "$GENERATED_IDENTITY"
        printf '%s' "$identity_password" >"$GENERATED_IDENTITY_PASSWORD"
        [[ "${MOCK_FAIL_AT:-}" != "import" ]] || exit 41
        touch "$IDENTITY_MARKER"
        ;;
    add-trusted-cert)
        reject_forbidden_access
        [[ "${args[*]}" != *"trustRoot"* ]] ||
            fail "不得将本地代码签名证书设为持久信任根"
        [[ ${#args[@]} -eq 8 && "${args[1]}" == "-r" &&
            "${args[2]}" == "trustAsRoot" && "${args[3]}" == "-p" &&
            "${args[4]}" == "codeSign" && "${args[5]}" == "-k" &&
            "${args[6]}" == "$MOCK_KEYCHAIN" && "${args[7]}" == */certificate.pem ]] ||
            fail "必须仅为登录钥匙串添加 trustAsRoot 代码签名信任"
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
        [[ "${MOCK_ROLLBACK_FAIL:-0}" != "1" ]] || exit 51
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

run_fake_import() {
    PATH="$FAKE_BIN:$PATH" security import "$1" \
        -k "$MOCK_KEYCHAIN" \
        -P "$2" \
        -T /usr/bin/codesign
}

reset_case() {
    : >"$COMMAND_LOG"
    rm -f "$IDENTITY_MARKER" "$ROLLBACK_MARKER" "$GENERATED_CERTIFICATE" \
        "$GENERATED_IDENTITY" "$GENERATED_IDENTITY_PASSWORD" \
        "$EXPECTED_FINGERPRINT_FILE" "$ROLLBACK_OUTPUT" \
        "$CERTIFICATE_ONLY_OUTPUT" "$INVALID_KEYCHAIN_OUTPUT"
    rm -rf "$IMPORT_VALIDATION_DIR"
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

assert_temporary_material_cleaned() {
    if find "$TEST_ROOT/tmp" -type f \
        \( -name 'private-key.pem' -o -name 'certificate.pem' -o -name 'identity.p12' \) \
        | grep -q .; then
        echo "临时签名材料未清理" >&2
        exit 1
    fi
}

reset_case
run_setup
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,find-identity'
[[ -f "$IDENTITY_MARKER" ]]
[[ ! -e "$ROLLBACK_MARKER" ]]
[[ -f "$GENERATED_CERTIFICATE" && -f "$GENERATED_IDENTITY" ]]
[[ -s "$GENERATED_IDENTITY_PASSWORD" ]]
generated_identity_password="$(<"$GENERATED_IDENTITY_PASSWORD")"
openssl pkcs12 -in "$GENERATED_IDENTITY" \
    -passin "pass:$generated_identity_password" -noout -nokeys
openssl pkcs12 -in "$GENERATED_IDENTITY" \
    -passin "pass:$generated_identity_password" -noout -nocerts
basic_constraints="$(
    openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext basicConstraints
)"
grep -Fq 'CA:FALSE' <<<"$basic_constraints"
if grep -Fq 'CA:TRUE' <<<"$basic_constraints"; then
    echo "本地代码签名证书不应具有 CA 签发能力" >&2
    exit 1
fi
key_usage="$(openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext keyUsage)"
grep -Fq 'Digital Signature' <<<"$key_usage"
if grep -Fq 'Certificate Sign' <<<"$key_usage"; then
    echo "本地代码签名证书不应具有证书签发用途" >&2
    exit 1
fi
openssl x509 -in "$GENERATED_CERTIFICATE" -noout -ext extendedKeyUsage \
    | grep -Fq 'Code Signing'
assert_temporary_material_cleaned

mkdir -p "${CERTIFICATE_ONLY_IDENTITY%/*}"
certificate_only_password="$(
    printf '0123456789abcdef%.0s' {1..4}
)"
openssl pkcs12 -export \
    -nokeys \
    -in "$GENERATED_CERTIFICATE" \
    -out "$CERTIFICATE_ONLY_IDENTITY" \
    -passout "pass:$certificate_only_password" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha1
reset_case
if run_fake_import "$CERTIFICATE_ONLY_IDENTITY" "$certificate_only_password" \
    >"$CERTIFICATE_ONLY_OUTPUT" 2>&1; then
    echo "证书-only PKCS#12 不应建立完整身份" >&2
    exit 1
fi
[[ ! -e "$IDENTITY_MARKER" && ! -e "$ROLLBACK_MARKER" ]]

reset_case
if MOCK_DEFAULT_KEYCHAIN_OUTPUT=unpaired run_setup \
    >"$INVALID_KEYCHAIN_OUTPUT" 2>&1; then
    echo "缺少成对引号的默认钥匙串输出不应通过" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain'
grep -Fq '本地签名设置失败：无法解析登录钥匙串路径' \
    "$INVALID_KEYCHAIN_OUTPUT"
[[ ! -e "$IDENTITY_MARKER" && ! -e "$GENERATED_IDENTITY" ]]

reset_case
if MOCK_DEFAULT_KEYCHAIN_OUTPUT=empty run_setup \
    >"$INVALID_KEYCHAIN_OUTPUT" 2>&1; then
    echo "空默认钥匙串路径不应通过" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain'
grep -Fq '本地签名设置失败：登录钥匙串路径为空' \
    "$INVALID_KEYCHAIN_OUTPUT"
[[ ! -e "$IDENTITY_MARKER" && ! -e "$GENERATED_IDENTITY" ]]

reset_case
if MOCK_FAIL_AT=import run_setup; then
    echo "PKCS#12 导入失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import'
[[ ! -e "$IDENTITY_MARKER" && ! -e "$ROLLBACK_MARKER" ]]
assert_temporary_material_cleaned

reset_case
if MOCK_FAIL_AT=trust run_setup; then
    echo "信任失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,delete-identity'
[[ -f "$ROLLBACK_MARKER" && ! -e "$IDENTITY_MARKER" ]]
assert_temporary_material_cleaned

reset_case
if MOCK_FAIL_AT=verify run_setup; then
    echo "最终身份校验失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,find-identity,delete-identity'
[[ -f "$ROLLBACK_MARKER" && ! -e "$IDENTITY_MARKER" ]]
assert_temporary_material_cleaned

reset_case
if MOCK_FAIL_AT=trust MOCK_ROLLBACK_FAIL=1 run_setup >"$ROLLBACK_OUTPUT" 2>&1; then
    echo "回滚失败时设置脚本不应成功" >&2
    exit 1
fi
assert_command_order 'find-identity,default-keychain,import,add-trusted-cert,delete-identity'
grep -Fq '本地签名身份回滚失败' "$ROLLBACK_OUTPUT"
[[ -f "$IDENTITY_MARKER" && ! -e "$ROLLBACK_MARKER" ]]
assert_temporary_material_cleaned

reset_case
MOCK_IDENTITY_EXISTS=1 run_setup
assert_command_order 'find-identity'
[[ ! -e "$GENERATED_CERTIFICATE" && ! -e "$GENERATED_IDENTITY" ]]
