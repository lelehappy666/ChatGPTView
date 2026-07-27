#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
FAKE_BIN="$TEST_ROOT/bin"
COMMAND_LOG="$TEST_ROOT/codesign.log"
PACKAGE_LOG="$TEST_ROOT/package.log"
APP="$TEST_ROOT/Codex Monitor.app"
mkdir -p "$FAKE_BIN" "$APP"
touch "$COMMAND_LOG" "$PACKAGE_LOG"
export COMMAND_LOG PACKAGE_LOG TEST_ROOT

cat >"$FAKE_BIN/codesign" <<'STUB'
#!/bin/bash
set -euo pipefail

printf 'codesign' >>"$COMMAND_LOG"
printf ' <%s>' "$@" >>"$COMMAND_LOG"
printf '\n' >>"$COMMAND_LOG"

case "$1" in
    --force)
        [[ "${MOCK_CODESIGN_FAILURE:-}" != "sign" ]] || exit 41
        ;;
    --verify)
        [[ "${MOCK_CODESIGN_FAILURE:-}" != "verify" ]] || exit 42
        ;;
    -d)
        [[ "${MOCK_CODESIGN_FAILURE:-}" != "requirement" ]] || exit 43
        printf '%s\n' "${MOCK_REQUIREMENT:?请设置模拟指定要求}" >&2
        ;;
    *)
        echo "未预期的 codesign 调用：$*" >&2
        exit 90
        ;;
esac
STUB
chmod +x "$FAKE_BIN/codesign"

cat >"$FAKE_BIN/xcrun" <<'STUB'
#!/bin/bash
set -euo pipefail

if [[ "${*: -1}" == "--show-bin-path" ]]; then
    printf '%s\n' "$TEST_ROOT/release-bin"
fi
STUB
chmod +x "$FAKE_BIN/xcrun"

cat >"$FAKE_BIN/bash" <<'STUB'
#!/bin/bash
set -euo pipefail

printf 'bash' >>"$PACKAGE_LOG"
printf ' <%s>' "$@" >>"$PACKAGE_LOG"
printf '\n' >>"$PACKAGE_LOG"
STUB
chmod +x "$FAKE_BIN/bash"

run_sign() {
    PATH="$FAKE_BIN:$PATH" \
        CODE_SIGN_IDENTITY="Stable Test Identity" \
        MOCK_REQUIREMENT="$1" \
        /bin/bash "$ROOT/scripts/sign-app.sh" "$APP"
}

assert_log_equals() {
    local expected="$1"
    local actual
    actual="$(cat "$COMMAND_LOG")"
    [[ "$actual" == "$expected" ]] || {
        echo "codesign 调用不匹配：" >&2
        echo "期望：$expected" >&2
        echo "实际：$actual" >&2
        exit 1
    }
}

: >"$COMMAND_LOG"
run_sign '# designated => identifier "com.dafeng.codexmonitor" and anchor trusted'
assert_log_equals $'codesign <--force> <--deep> <--options> <runtime> <--timestamp=none> <--sign> <Stable Test Identity> <'"$APP"$'>\ncodesign <--verify> <--deep> <--strict> <--verbose=2> <'"$APP"$'>\ncodesign <-d> <-r-> <'"$APP"$'>'

: >"$COMMAND_LOG"
if run_sign '# designated => cdhash' >"$TEST_ROOT/cdhash-output" 2>&1; then
    echo "临时 cdhash 指定要求不应通过" >&2
    exit 1
fi
grep -Fq '签名失败：应用指定要求仍是临时 cdhash' "$TEST_ROOT/cdhash-output"

: >"$COMMAND_LOG"
if PATH="$FAKE_BIN:$PATH" CODE_SIGN_IDENTITY="Stable Test Identity" \
    MOCK_REQUIREMENT='# designated => identifier "com.dafeng.codexmonitor"' \
    MOCK_CODESIGN_FAILURE=verify \
    /bin/bash "$ROOT/scripts/sign-app.sh" "$APP"; then
    echo "签名校验失败不应被吞掉" >&2
    exit 1
fi
[[ "$(wc -l <"$COMMAND_LOG" | tr -d ' ')" == "2" ]] || {
    echo "校验失败后不应继续读取指定要求" >&2
    exit 1
}

: >"$COMMAND_LOG"
if PATH="$FAKE_BIN:$PATH" CODE_SIGN_IDENTITY="Stable Test Identity" \
    MOCK_REQUIREMENT='# designated => identifier "com.dafeng.codexmonitor"' \
    MOCK_CODESIGN_FAILURE=sign \
    /bin/bash "$ROOT/scripts/sign-app.sh" "$APP"; then
    echo "签名失败不应被吞掉" >&2
    exit 1
fi
[[ "$(wc -l <"$COMMAND_LOG" | tr -d ' ')" == "1" ]] || {
    echo "签名失败后不应继续校验" >&2
    exit 1
}

PACKAGE_ROOT="$TEST_ROOT/package-cwd"
mkdir -p "$PACKAGE_ROOT/Resources" "$TEST_ROOT/release-bin"
touch "$PACKAGE_ROOT/Resources/Info.plist" "$PACKAGE_ROOT/Resources/AppIcon.icns"
touch "$TEST_ROOT/release-bin/CodexMonitor"
(
    cd "$PACKAGE_ROOT"
    PATH="$FAKE_BIN:$PATH" /bin/bash "$ROOT/scripts/package-app.sh"
)
expected_package_call="bash <$ROOT/scripts/sign-app.sh> <dist/Codex Monitor.app>"
[[ "$(cat "$PACKAGE_LOG")" == "$expected_package_call" ]] || {
    echo "打包脚本未从脚本目录调用独立签名脚本" >&2
    exit 1
}
