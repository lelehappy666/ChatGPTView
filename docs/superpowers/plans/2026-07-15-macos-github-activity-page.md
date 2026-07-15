# macOS GitHub 活跃页实施计划

> **供智能代理执行：** 必须使用 `superpowers:executing-plans` 按任务执行；每项均采用测试先行方式。

**目标：** 在现有 macOS 刘海面板中增加可授权、可展示最近 12 个月贡献和最近更新 6 个仓库的第 4 页，并打包为可本地测试的 App。

**架构：** 采用独立的 GitHub 领域模型、GraphQL 客户端、Keychain 凭据仓库和 `GitHubActivityStore`。SwiftUI 页面只观察状态并触发动作，排序、缓存和 GraphQL 解码均与界面分离，便于单元测试。授权采用用户在 GitHub 创建只读令牌、复制后由应用从剪贴板绑定的流程，避免要求测试者注册 OAuth App。

**技术栈：** Swift 6.2、SwiftUI、Foundation URLSession、GitHub GraphQL API、Security Keychain、XCTest、Swift Package Manager。

## 全局约束

- 所有新增文档和界面文案使用中文。
- 所有 Git 提交信息使用中文。
- 只实现 macOS 第 4 页，不修改 Windows 版本。
- GitHub 令牌只存储在 macOS Keychain，不写入 UserDefaults、缓存或日志。
- 仓库按 `pushedAt` 降序展示最多 6 个。
- 页面保持 `420 × 260` 的现有刘海面板尺寸，并遵循“减少动态效果”设置。

---

### 任务 1：GitHub 领域模型与排序规则

**文件：**
- 新建：`Sources/CodexMonitor/GitHub/GitHubModels.swift`
- 新建：`Tests/CodexMonitorTests/GitHubModelsTests.swift`
- 修改：`Sources/CodexMonitor/Notch/NotchLayout.swift`
- 修改：`Tests/CodexMonitorTests/LayoutContractTests.swift`
- 修改：`Tests/CodexMonitorTests/AppIntegrationTests.swift`

**接口：**
- 产出：`GitHubContributionDay`、`GitHubRepository`、`GitHubActivitySnapshot`。
- 产出：`Array<GitHubRepository>.recentlyPushed(limit:)`，按推送时间降序并限制数量。
- 产出：`NotchLayout.pageCount == 4`，`PageNavigation` 自动按页面数夹取。

- [ ] 先添加排序、截断和 4 页导航测试。
- [ ] 运行 `xcrun swift test --disable-sandbox --filter GitHubModelsTests`，确认因类型不存在而失败。
- [ ] 实现最小模型与排序扩展，并把 `pageCount` 改为 4。
- [ ] 运行模型和布局测试，确认通过。
- [ ] 使用中文提交 `测试：定义 GitHub 活跃数据规则`。

### 任务 2：GraphQL 响应解码与请求客户端

**文件：**
- 新建：`Sources/CodexMonitor/GitHub/GitHubGraphQLClient.swift`
- 新建：`Tests/CodexMonitorTests/GitHubGraphQLClientTests.swift`

**接口：**
- 产出：`protocol GitHubActivityLoading { func fetchActivity(token: String) async throws -> GitHubActivitySnapshot }`。
- 产出：`GitHubGraphQLClient`，向 `https://api.github.com/graphql` 发送 Bearer 请求。
- 产出：`GitHubAPIError`，区分令牌无效、限流、服务器响应和数据格式错误。

- [ ] 写入固定 GraphQL JSON 的解码测试，验证用户名、贡献总数、日期格和 6 个仓库。
- [ ] 写入错误响应测试，验证 `errors` 数组和 HTTP 401 被转成中文可展示错误。
- [ ] 运行 `xcrun swift test --disable-sandbox --filter GitHubGraphQLClientTests`，确认失败原因是客户端尚未实现。
- [ ] 实现 GraphQL 查询、ISO 8601 日期解码、HTTP 状态检查和响应映射。
- [ ] 运行客户端测试，确认通过。
- [ ] 使用中文提交 `功能：接入 GitHub 活跃数据接口`。

### 任务 3：Keychain、缓存与页面状态仓库

**文件：**
- 新建：`Sources/CodexMonitor/GitHub/GitHubCredentialStore.swift`
- 新建：`Sources/CodexMonitor/GitHub/GitHubActivityStore.swift`
- 新建：`Tests/CodexMonitorTests/GitHubActivityStoreTests.swift`

**接口：**
- 产出：`protocol GitHubCredentialStoring`，含 `readToken()`、`saveToken(_:)`、`deleteToken()`。
- 产出：`KeychainGitHubCredentialStore`，服务名为 `com.dafeng.codexmonitor.github`。
- 产出：`GitHubActivityStore.State`：`unbound`、`loading`、`loaded`、`failed`。
- 产出：`bind(token:)`、`refresh()`、`disconnect()`，数据缓存不包含令牌。

- [ ] 使用内存凭据仓库和伪加载器写入绑定成功、授权失败、缓存回退、解绑清理测试。
- [ ] 运行 `xcrun swift test --disable-sandbox --filter GitHubActivityStoreTests`，确认类型缺失导致失败。
- [ ] 实现 Keychain 访问、Codable UserDefaults 缓存和主线程状态仓库。
- [ ] 运行状态仓库测试，确认通过。
- [ ] 使用中文提交 `功能：保存 GitHub 授权与页面状态`。

### 任务 4：第 4 页授权态与已授权态界面

**文件：**
- 新建：`Sources/CodexMonitor/GitHub/GitHubActivityPage.swift`
- 新建：`Sources/CodexMonitor/GitHub/GitHubContributionHeatmap.swift`
- 新建：`Sources/CodexMonitor/GitHub/RecentRepositoryGrid.swift`
- 修改：`Sources/CodexMonitor/Notch/NotchDashboardView.swift`

**接口：**
- 消费：`GitHubActivityStore` 及其状态。
- 产出：授权弹窗，可打开 GitHub 令牌页面并从剪贴板绑定令牌。
- 产出：最近 12 个月贡献网格、贡献总数、用户名状态和 2 列 3 行仓库链接。

- [ ] 添加可测试的授权文案、贡献格标准化和仓库链接策略断言。
- [ ] 运行对应测试，确认新增断言先失败。
- [ ] 实现未绑定、加载、成功、缓存错误和空数据状态，并把页面插入第 4 个位置。
- [ ] 确保按钮使用系统浏览器打开 URL，绑定动作只从系统剪贴板读取且不打印令牌。
- [ ] 运行完整测试，确认界面编译且行为测试通过。
- [ ] 使用中文提交 `功能：新增 GitHub 活跃第四页`。

### 任务 5：验证、打包与交付

**文件：**
- 可能修改：`Resources/Info.plist`（仅在打包验证发现必要时）
- 产物：`dist/Codex Monitor.app`
- 产物：`dist/Codex-Monitor-macOS.zip`

**验收：**
- 运行 `xcrun swift test --disable-sandbox`，预期全部测试通过且 0 失败。
- 运行 `bash scripts/package-app.sh`，预期生成并临时签名 App。
- 运行 `codesign --verify --deep --strict 'dist/Codex Monitor.app'`，预期退出码 0。
- 运行 `plutil -lint 'dist/Codex Monitor.app/Contents/Info.plist'`，预期输出 `OK`。
- 运行 `ditto -c -k --sequesterRsrc --keepParent 'dist/Codex Monitor.app' 'dist/Codex-Monitor-macOS.zip'`。
- 检查 Git 状态，仅包含本功能预期变更和打包产物。
- 使用中文提交 `构建：完成 GitHub 活跃页并打包测试版`。
