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

LOGIN_KEYCHAIN="$(security default-keychain -d user)"
if [[ "$LOGIN_KEYCHAIN" == \"*\" && "$LOGIN_KEYCHAIN" == *\" ]]; then
    LOGIN_KEYCHAIN="${LOGIN_KEYCHAIN:1:${#LOGIN_KEYCHAIN}-2}"
fi
TMP="$(mktemp -d)"
IMPORTED=0
CERTIFICATE_FINGERPRINT=""

cleanup() {
    local status=$?
    trap - EXIT

    if ((status != 0 && IMPORTED == 1 && ${#CERTIFICATE_FINGERPRINT} > 0)); then
        security delete-identity -Z "$CERTIFICATE_FINGERPRINT" -t "$LOGIN_KEYCHAIN" \
            >/dev/null 2>&1 || true
    fi

    rm -rf "$TMP"
    exit "$status"
}
trap cleanup EXIT

openssl req -new -newkey rsa:2048 -x509 -sha256 -days 3650 -nodes \
    -keyout "$TMP/private-key.pem" \
    -out "$TMP/certificate.pem" \
    -subj "/CN=$LOCAL_SIGNING_IDENTITY/O=Codex Monitor Local Development/" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign" \
    -addext "extendedKeyUsage=codeSigning"

CERTIFICATE_FINGERPRINT="$(
    openssl x509 -in "$TMP/certificate.pem" -noout -fingerprint -sha256 \
        | awk -F= '{ gsub(/:/, "", $2); print $2 }'
)"

security import "$TMP/private-key.pem" \
    -k "$LOGIN_KEYCHAIN" \
    -T /usr/bin/codesign
IMPORTED=1

security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$LOGIN_KEYCHAIN" \
    "$TMP/certificate.pem"

security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | grep -F "\"$LOCAL_SIGNING_IDENTITY\""
IMPORTED=0

echo "本地签名身份创建完成：$LOCAL_SIGNING_IDENTITY"
