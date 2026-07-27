#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/signing-identity.sh"

APP="${1:?请提供应用路径}"
SIGNING_IDENTITY="$(resolve_signing_identity)"

codesign --force --deep --options runtime --timestamp=none \
    --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

REQUIREMENT="$(codesign -d -r- "$APP" 2>&1)"
if [[ "$REQUIREMENT" == *'=> cdhash'* ]]; then
    echo "签名失败：应用指定要求仍是临时 cdhash" >&2
    exit 1
fi
