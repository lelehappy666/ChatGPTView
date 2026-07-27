#!/usr/bin/env bash

LOCAL_SIGNING_IDENTITY="Codex Monitor Local Signing"

resolve_signing_identity() {
    if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
        printf '%s\n' "$CODE_SIGN_IDENTITY"
        return 0
    fi

    if security find-identity -v -p codesigning 2>/dev/null \
        | grep -Fq "\"$LOCAL_SIGNING_IDENTITY\""; then
        printf '%s\n' "$LOCAL_SIGNING_IDENTITY"
        return 0
    fi

    printf '%s\n' \
        "未找到稳定代码签名身份，请先运行 scripts/setup-local-signing.sh" >&2
    return 1
}
