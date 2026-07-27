#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/signing-identity.sh"

if security find-identity -v -p codesigning 2>/dev/null \
    | grep -Fq "\"$LOCAL_SIGNING_IDENTITY\""; then
    echo "本地签名身份已存在：$LOCAL_SIGNING_IDENTITY"
    exit 0
fi

DEFAULT_KEYCHAIN_OUTPUT="$(security default-keychain -d user)"
if [[ "$DEFAULT_KEYCHAIN_OUTPUT" =~ \"([^\"]*)\" ]]; then
    LOGIN_KEYCHAIN="${BASH_REMATCH[1]}"
else
    echo "本地签名设置失败：无法解析登录钥匙串路径" >&2
    exit 1
fi
if [[ -z "$LOGIN_KEYCHAIN" ]]; then
    echo "本地签名设置失败：登录钥匙串路径为空" >&2
    exit 1
fi
TMP="$(mktemp -d)"
IMPORTED=0
CERTIFICATE_FINGERPRINT=""

cleanup() {
    local status=$?
    trap - EXIT

    if ((status != 0 && IMPORTED == 1 && ${#CERTIFICATE_FINGERPRINT} > 0)); then
        if ! security delete-identity -Z "$CERTIFICATE_FINGERPRINT" -t "$LOGIN_KEYCHAIN"; then
            echo "本地签名身份回滚失败：无法删除本次创建的身份。" >&2
        fi
    fi

    rm -rf "$TMP"
    exit "$status"
}
trap cleanup EXIT

openssl req -new -newkey rsa:2048 -x509 -sha256 -days 3650 -nodes \
    -keyout "$TMP/private-key.pem" \
    -out "$TMP/certificate.pem" \
    -subj "/CN=$LOCAL_SIGNING_IDENTITY/O=Codex Monitor Local Development/" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"

CERTIFICATE_FINGERPRINT="$(
    openssl x509 -in "$TMP/certificate.pem" -noout -fingerprint -sha256 \
        | awk -F= '{ gsub(/:/, "", $2); print $2 }'
)"
P12_PASSWORD="$(openssl rand -hex 32)"

openssl pkcs12 -export \
    -inkey "$TMP/private-key.pem" \
    -in "$TMP/certificate.pem" \
    -out "$TMP/identity.p12" \
    -passout "pass:$P12_PASSWORD" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha1

security import "$TMP/identity.p12" \
    -k "$LOGIN_KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign
unset P12_PASSWORD
IMPORTED=1

security add-trusted-cert \
    -r trustAsRoot \
    -p codeSign \
    -k "$LOGIN_KEYCHAIN" \
    "$TMP/certificate.pem"

security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | grep -F "\"$LOCAL_SIGNING_IDENTITY\""
IMPORTED=0

echo "本地签名身份创建完成：$LOCAL_SIGNING_IDENTITY"
