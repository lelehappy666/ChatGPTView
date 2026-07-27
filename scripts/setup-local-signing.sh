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
CA_TRUST_MAY_EXIST=0
LEAF_FINGERPRINT=""
CA_FINGERPRINT=""

cleanup() {
    local status=$?
    trap - EXIT

    if ((status != 0 && IMPORTED == 1 && ${#LEAF_FINGERPRINT} > 0)); then
        if ! security delete-identity -Z "$LEAF_FINGERPRINT" "$LOGIN_KEYCHAIN"; then
            echo "本地签名叶子身份回滚失败：无法删除本次创建的叶子身份。" >&2
        fi
    fi
    if ((status != 0 && CA_TRUST_MAY_EXIST == 1 && ${#CA_FINGERPRINT} > 0)); then
        if ! security delete-certificate \
            -Z "$CA_FINGERPRINT" -t "$LOGIN_KEYCHAIN"; then
            echo "本地签名 CA 回滚/清理未确认：无法删除本次可能创建的 CA 证书和用户信任。" >&2
        fi
    fi

    rm -rf "$TMP"
    exit "$status"
}
trap cleanup EXIT

openssl req -new -newkey rsa:2048 -x509 -sha256 -days 3651 -nodes \
    -keyout "$TMP/ca-private-key.pem" \
    -out "$TMP/ca-certificate.pem" \
    -subj "/CN=$LOCAL_SIGNING_IDENTITY Ephemeral CA/O=Codex Monitor Local Development/" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"

openssl req -new -newkey rsa:2048 -sha256 -nodes \
    -keyout "$TMP/private-key.pem" \
    -out "$TMP/certificate.csr" \
    -subj "/CN=$LOCAL_SIGNING_IDENTITY/O=Codex Monitor Local Development/" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"

openssl x509 -req \
    -in "$TMP/certificate.csr" \
    -CA "$TMP/ca-certificate.pem" \
    -CAkey "$TMP/ca-private-key.pem" \
    -CAcreateserial \
    -days 3650 \
    -sha256 \
    -copy_extensions copy \
    -out "$TMP/certificate.pem"

openssl verify -CAfile "$TMP/ca-certificate.pem" "$TMP/certificate.pem"

LEAF_FINGERPRINT="$(
    openssl x509 -in "$TMP/certificate.pem" -noout -fingerprint -sha256 \
        | awk -F= '{ gsub(/:/, "", $2); print $2 }'
)"
CA_FINGERPRINT="$(
    openssl x509 -in "$TMP/ca-certificate.pem" -noout -fingerprint -sha256 \
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

CA_TRUST_MAY_EXIST=1
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$LOGIN_KEYCHAIN" \
    "$TMP/ca-certificate.pem"

security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | grep -F "\"$LOCAL_SIGNING_IDENTITY\""
IMPORTED=0

echo "本地签名身份创建完成：$LOCAL_SIGNING_IDENTITY"
