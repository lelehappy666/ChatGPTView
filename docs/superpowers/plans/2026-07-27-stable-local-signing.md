# macOS 稳定本地签名实施计划

> **面向代理执行者：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项实施。本计划使用复选框跟踪进度。

**目标：** 为本机持续打包建立稳定代码签名身份，使后续版本被 macOS 钥匙串识别为同一应用，并发布 0.1.12（13）。

**架构：** 独立脚本负责解析签名身份，一次性设置脚本只负责创建和安装本地证书，打包脚本只使用已存在的稳定身份并拒绝回退到 `ad-hoc`。签名选择逻辑通过隔离的 Shell 测试验证，最终产物通过 `codesign` 连续打包验证指定要求稳定。

**技术栈：** Bash、OpenSSL、macOS `security`、`codesign`、Swift Package Manager、XCTest。

## 全局约束

- 本地签名身份固定命名为 `Codex Monitor Local Signing`。
- 私钥只进入当前用户登录钥匙串，不得写入仓库、应用包或构建产物。
- 环境变量 `CODE_SIGN_IDENTITY` 优先于默认本地身份。
- 未找到稳定身份时必须停止打包，不得回退到 `codesign --sign -`。
- 本地证书只在当前用户范围内信任代码签名用途。
- 不修改 GitHub Token 的服务名、账号名和内容。
- 版本更新为 `0.1.12 (13)`。
- 所有文档、脚本提示和 Git 提交使用中文。
- 直接在 `main` 分支工作。

---

### Task 1：可测试的签名身份解析

**文件：**

- 新建：`scripts/signing-identity.sh`
- 新建：`Tests/Scripts/signing-identity-tests.sh`

**接口：**

- `resolve_signing_identity() -> stdout`
- 输入：可选环境变量 `CODE_SIGN_IDENTITY`
- 默认身份：`Codex Monitor Local Signing`
- 失败：标准错误输出中文提示并返回非零状态

- [ ] **步骤1：编写失败的 Shell 测试**

```bash
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
```

- [ ] **步骤2：运行测试并确认正确失败**

```bash
bash Tests/Scripts/signing-identity-tests.sh
```

预期：失败，提示 `scripts/signing-identity.sh` 不存在。

- [ ] **步骤3：实现身份解析脚本**

```bash
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
```

- [ ] **步骤4：运行 Shell 测试并确认通过**

```bash
bash Tests/Scripts/signing-identity-tests.sh
bash -n scripts/signing-identity.sh
```

预期：退出状态均为0。

- [ ] **步骤5：提交**

```bash
git add scripts/signing-identity.sh Tests/Scripts/signing-identity-tests.sh
git commit -m "构建：增加稳定签名身份解析"
```

---

### Task 2：一次性本地签名设置

**文件：**

- 新建：`scripts/setup-local-signing.sh`
- 新建：`Tests/Scripts/setup-local-signing-tests.sh`

**接口：**

- 命令：`bash scripts/setup-local-signing.sh`
- 已存在有效身份：直接成功退出
- 不存在：由临时 CA 私钥签发不具备 CA 能力的叶子代码签名证书；PKCS#12 仅原子导入叶子证书与叶子私钥；仅把 CA 公钥证书以 `trustRoot + codeSign` 持久化到当前用户登录钥匙串；CA 私钥不进入钥匙串并随临时目录清理

- [ ] **步骤1：编写失败的隔离 Shell 行为测试**

`Tests/Scripts/setup-local-signing-tests.sh` 使用临时 `PATH` 提供假的 `security`，执行真实设置脚本；证书与 PKCS#12 产物由真实 `openssl` 检查，且不访问真实钥匙串。

```bash
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
```

- [ ] **步骤2：运行测试并确认正确失败**

```bash
bash Tests/Scripts/setup-local-signing-tests.sh
```

预期：失败，提示 `scripts/setup-local-signing.sh` 不存在。

- [ ] **步骤3：实现一次性设置脚本**

脚本主体使用以下确定流程：

```bash
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
    -addext "extendedKeyUsage=codeSigning"

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
```

- [ ] **步骤4：运行无副作用语法检查和隔离行为测试**

```bash
bash -n scripts/setup-local-signing.sh
bash Tests/Scripts/setup-local-signing-tests.sh
```

预期：语法检查与目标测试通过。

- [ ] **步骤5：提交**

```bash
git add scripts/setup-local-signing.sh \
  Tests/Scripts/setup-local-signing-tests.sh
git commit -m "构建：增加本地签名身份设置"
```

---

### Task 3：打包脚本拒绝临时签名

**文件：**

- 新建：`scripts/sign-app.sh`
- 新建：`Tests/Scripts/sign-app-tests.sh`
- 修改：`scripts/package-app.sh`

**接口：**

- 消费：`resolve_signing_identity()`
- 命令：`bash scripts/sign-app.sh <应用路径>`
- 产出：使用稳定身份签名的 `dist/Codex Monitor.app`

- [ ] **步骤1：编写失败的签名行为测试**

`Tests/Scripts/sign-app-tests.sh` 执行真实签名脚本，以假的 `codesign` 记录参数并返回可控指定要求：

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
FAKE_BIN="$TEST_ROOT/bin"
COMMAND_LOG="$TEST_ROOT/codesign.log"
APP="$TEST_ROOT/Codex Monitor.app"
mkdir -p "$FAKE_BIN" "$APP"
export COMMAND_LOG

cat >"$FAKE_BIN/codesign" <<'STUB'
#!/usr/bin/env bash
printf 'codesign' >>"$COMMAND_LOG"
printf ' <%s>' "$@" >>"$COMMAND_LOG"
printf '\n' >>"$COMMAND_LOG"
if [[ "$1" == "-d" ]]; then
    printf '%s\n' "$MOCK_REQUIREMENT" >&2
fi
STUB
chmod +x "$FAKE_BIN/codesign"

export CODE_SIGN_IDENTITY="Stable Test Identity"
export MOCK_REQUIREMENT='# designated => identifier "com.dafeng.codexmonitor" and anchor trusted'
PATH="$FAKE_BIN:$PATH" bash "$ROOT/scripts/sign-app.sh" "$APP"

grep -F '<--sign> <Stable Test Identity>' "$COMMAND_LOG"
grep -F '<--verify> <--deep> <--strict>' "$COMMAND_LOG"

export MOCK_REQUIREMENT='# designated => cdhash H"1234"'
if PATH="$FAKE_BIN:$PATH" bash "$ROOT/scripts/sign-app.sh" "$APP"; then
    echo "临时 cdhash 指定要求不应通过"
    exit 1
fi
```

- [ ] **步骤2：运行测试并确认正确失败**

```bash
bash Tests/Scripts/sign-app-tests.sh
```

预期：失败，提示 `scripts/sign-app.sh` 不存在。

- [ ] **步骤3：实现独立签名脚本**

`scripts/sign-app.sh`：

```bash
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
if [[ "$REQUIREMENT" == *'=> cdhash '* ]]; then
    echo "签名失败：应用指定要求仍是临时 cdhash" >&2
    exit 1
fi
```

- [ ] **步骤4：让打包脚本调用独立签名脚本**

将原有 `codesign --force --deep --sign - "$APP"` 替换为：

```bash
bash "$SCRIPT_DIR/sign-app.sh" "$APP"
```

- [ ] **步骤5：运行隔离行为测试与 Shell 语法检查**

```bash
bash -n scripts/package-app.sh
bash -n scripts/sign-app.sh
bash Tests/Scripts/sign-app-tests.sh
```

预期：全部通过。

- [ ] **步骤6：提交**

```bash
git add scripts/sign-app.sh scripts/package-app.sh \
  Tests/Scripts/sign-app-tests.sh
git commit -m "修复：打包时强制使用稳定签名"
```

---

### Task 4：版本更新

**文件：**

- 修改：`Resources/Info.plist`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**

- 产出：版本 `0.1.12`、构建号 `13`

- [ ] **步骤1：先修改版本断言**

将 `testAppMetadataDeclaresPackagedIcon` 中版本断言改为：

```swift
XCTAssertEqual(
    plist["CFBundleShortVersionString"] as? String,
    "0.1.12"
)
XCTAssertEqual(plist["CFBundleVersion"] as? String, "13")
```

- [ ] **步骤2：运行测试并确认正确失败**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox \
  --filter AppIntegrationTests/testAppMetadataDeclaresPackagedIcon
```

预期：实际值仍为 `0.1.11 (12)`，断言失败。

- [ ] **步骤3：更新 `Info.plist`**

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.12</string>
<key>CFBundleVersion</key>
<string>13</string>
```

- [ ] **步骤4：重新运行版本测试**

运行步骤2中的命令。

预期：测试通过。

- [ ] **步骤5：提交**

```bash
git add Resources/Info.plist Tests/CodexMonitorTests/AppIntegrationTests.swift
git commit -m "发布：更新手动刷新与稳定签名版本"
```

---

### Task 5：建立身份、连续打包与最终验证

**文件：**

- 执行：`scripts/setup-local-signing.sh`
- 执行：`scripts/package-app.sh`
- 验证：`dist/Codex Monitor.app`

**接口：**

- 消费：任务一至任务四的脚本与版本
- 产出：稳定签名的 `Codex Monitor.app`

- [ ] **步骤1：运行完整自动测试**

```bash
set -o pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/codex-monitor-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/codex-monitor-swift-cache \
xcrun swift test --disable-sandbox 2>&1 | tail -50
```

预期：全部测试通过，0失败。

- [ ] **步骤2：一次性建立本地签名身份**

```bash
bash scripts/setup-local-signing.sh
```

预期：找到或创建 `Codex Monitor Local Signing`。新建时仅叶子 identity 与 CA 公钥证书进入登录钥匙串，CA 公钥证书使用当前用户的 `trustRoot + codeSign` 信任；CA 私钥始终只存在于 `umask 077` 临时目录并在退出时销毁。macOS 可能要求一次登录钥匙串授权。

- [ ] **步骤3：第一次打包并保存指定要求**

```bash
bash scripts/package-app.sh
codesign -d -r- "dist/Codex Monitor.app" 2>&1 \
    | tee /tmp/codex-monitor-requirement-1.txt
```

预期：打包成功，指定要求不以单独 `cdhash` 表示。

- [ ] **步骤4：第二次打包并比较指定要求**

```bash
bash scripts/package-app.sh
codesign -d -r- "dist/Codex Monitor.app" 2>&1 \
    | tee /tmp/codex-monitor-requirement-2.txt
diff -u \
    /tmp/codex-monitor-requirement-1.txt \
    /tmp/codex-monitor-requirement-2.txt
```

预期：`diff` 无输出，连续两次打包的指定要求完全一致。

- [ ] **步骤5：验证版本、签名和工作区**

```bash
plutil -p "dist/Codex Monitor.app/Contents/Info.plist" \
    | rg "CFBundleShortVersionString|CFBundleVersion"
codesign --verify --deep --strict --verbose=2 \
    "dist/Codex Monitor.app"
git diff --check
git status --short --branch
```

预期：

- 版本为 `0.1.12`，构建号为 `13`。
- `codesign` 验证通过。
- 工作区没有未提交改动。

- [ ] **步骤6：首次运行说明**

首次打开稳定签名版本并访问 GitHub 页面时：

1. 若 macOS 再次显示旧 Token 访问提示，输入登录钥匙串密码。
2. 选择“始终允许”。
3. 后续使用同一签名身份打包的版本不再重复提示。
