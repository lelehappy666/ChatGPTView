# 当前刘海界面海报实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 生成一张严格展示当前五个 macOS 刘海分页的 4K、16:9 产品海报，并替换 README 首屏旧设计图。

**架构：** 使用当前 `main` 分支中的实际 SwiftUI 页面视图和同一份本地数据快照逐页渲染，不让图像模型重绘界面。图像生成能力只负责制作无文字、无界面的深色紫光背景；最终通过 SwiftUI `ImageRenderer` 确定性合成品牌区、五个等比例刘海面板和背景。

**技术栈：** Swift 6.2、SwiftUI、AppKit、`ImageRenderer`、macOS `sips`、内置图像生成工具。

## 全局约束

- 画布固定为 3840 × 2160 像素，比例为 16:9。
- 五个刘海面板固定保持 420:320 宽高比，内部不拉伸、不裁切、不重排。
- 页面顺序固定为：本周额度、每日活动、项目分析、统计总览、GitHub 活跃。
- 五页必须使用同一次本地数据扫描和同一份 GitHub 缓存快照。
- 图像生成模型不得生成面板内部文字、数字、热力格、图表或项目列表。
- 最终文档和 Git 提交信息均使用中文。

---

### 任务一：建立可复用的当前界面海报渲染器

**文件：**

- 新建：`scripts/generate-notch-poster.swift`
- 读取：`Sources/CodexMonitor/Notch/NotchDashboardView.swift`
- 读取：`Sources/CodexMonitor/Notch/WeeklyQuotaPage.swift`
- 读取：`Sources/CodexMonitor/Notch/DailyActivityPage.swift`
- 读取：`Sources/CodexMonitor/Notch/ProjectAnalyticsPage.swift`
- 读取：`Sources/CodexMonitor/Notch/StatisticsPage.swift`
- 读取：`Sources/CodexMonitor/GitHub/GitHubActivityPage.swift`

**接口：**

- 输入：`--background <PNG 路径>`、`--output <PNG 路径>`。
- 数据输入：`AppPaths.sessionsRoot()` 下的当前 Codex 会话，以及 `com.dafeng.codexmonitor` 用户偏好中的 GitHub 活跃缓存。
- 输出：3840 × 2160 PNG。

- [ ] **步骤 1：编写数据快照加载器**

在 `scripts/generate-notch-poster.swift` 中添加 `PosterSnapshotLoader`：

```swift
enum PosterSnapshotLoader {
    static func loadMonitorSnapshot() async throws -> MonitorSnapshot {
        let root = AppPaths.sessionsRoot()
        let sessions = try await IncrementalSessionScanner().scan(root: root)
        let analytics = await ProjectAnalyticsIndex().update(sessions: sessions)
        return UsageAggregator.makeSnapshot(
            sessions: sessions,
            projectAnalytics: analytics
        )
    }

    @MainActor
    static func loadGitHubSnapshot() -> GitHubActivitySnapshot? {
        guard let defaults = UserDefaults(
            suiteName: "com.dafeng.codexmonitor"
        ) else {
            return nil
        }
        return UserDefaultsGitHubActivityCache(defaults: defaults).load()
    }
}
```

- [ ] **步骤 2：编写单页刘海外壳**

添加 `PosterNotchFrame<Content>`，结构必须与当前 `NotchDashboardView` 一致：

```swift
struct PosterNotchFrame<Content: View>: View {
    let selectedPage: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: NotchLayout.contentTop)
            content()
                .frame(
                    width: NotchLayout.size.width,
                    height: NotchLayout.pageContentHeight
                )
                .clipped()
            HStack(spacing: 6) {
                ForEach(0..<NotchLayout.pageCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == selectedPage
                                ? Color(red: 0.66, green: 0.60, blue: 0.94)
                                : Color.white.opacity(0.20)
                        )
                        .frame(
                            width: index == selectedPage ? 16 : 5,
                            height: 5
                        )
                }
            }
            .frame(height: NotchLayout.pagerHeight)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .frame(width: NotchLayout.size.width, height: NotchLayout.size.height)
        .background(Color.black)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
        )
    }
}
```

- [ ] **步骤 3：使用实际页面视图组成五页**

页面内容直接实例化当前视图：

```swift
PosterNotchFrame(selectedPage: 0) {
    WeeklyQuotaPage(
        snapshot: snapshot,
        refreshState: .updated,
        onRefresh: {}
    )
}
PosterNotchFrame(selectedPage: 1) {
    DailyActivityPage(snapshot: snapshot)
}
PosterNotchFrame(selectedPage: 2) {
    ProjectAnalyticsPage(
        analytics: snapshot.projectAnalytics,
        reduceMotion: true
    )
}
PosterNotchFrame(selectedPage: 3) {
    StatisticsPage(snapshot: snapshot)
}
PosterNotchFrame(selectedPage: 4) {
    GitHubActivityPage(store: githubStore)
}
```

GitHub 缓存存在时，通过固定缓存、固定凭据和固定加载器构造 `GitHubActivityStore` 并执行 `loadIfNeeded()`，确保进入 `.loaded` 状态；缓存不存在时保留软件当前的未绑定授权界面。

```swift
final class PosterGitHubLoader: GitHubActivityLoading, @unchecked Sendable {
    let snapshot: GitHubActivitySnapshot

    init(snapshot: GitHubActivitySnapshot) {
        self.snapshot = snapshot
    }

    func fetchActivity(token: String) async throws -> GitHubActivitySnapshot {
        snapshot
    }
}

final class PosterGitHubCredentials: GitHubCredentialStoring,
    @unchecked Sendable {
    func readToken() throws -> String? { "poster-cached-token" }
    func saveToken(_ token: String) throws {}
    func deleteToken() throws {}
}

@MainActor
final class PosterGitHubCache: GitHubActivityCaching {
    let snapshot: GitHubActivitySnapshot?

    init(snapshot: GitHubActivitySnapshot?) {
        self.snapshot = snapshot
    }

    func load() -> GitHubActivitySnapshot? { snapshot }
    func save(_ snapshot: GitHubActivitySnapshot) {}
    func clear() {}
}

@MainActor
func makeGitHubStore(
    snapshot: GitHubActivitySnapshot?
) async -> GitHubActivityStore {
    guard let snapshot else {
        return GitHubActivityStore(
            cache: PosterGitHubCache(snapshot: nil)
        )
    }
    let store = GitHubActivityStore(
        loader: PosterGitHubLoader(snapshot: snapshot),
        credentials: PosterGitHubCredentials(),
        cache: PosterGitHubCache(snapshot: snapshot)
    )
    await store.loadIfNeeded()
    return store
}
```

- [ ] **步骤 4：实现 2 + 3 产品矩阵**

在 1920 × 1080 点画布中构造 `NotchPosterView`：

- 顶部品牌区高度 110 点。
- 第一排两个面板，居中排列。
- 第二排三个面板，居中排列。
- 面板统一显示尺寸为 520 × 396.19 点。
- 水平间距 28 点，垂直间距 24 点。
- 背景只作为底图铺满，不参与页面内容渲染。

- [ ] **步骤 5：实现 PNG 导出**

```swift
let renderer = ImageRenderer(
    content: NotchPosterView(
        background: backgroundImage,
        snapshot: monitorSnapshot,
        githubStore: githubStore
    )
)
renderer.proposedSize = ProposedViewSize(
    width: 1920,
    height: 1080
)
renderer.scale = 2

guard let image = renderer.nsImage,
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw PosterRenderError.imageEncodingFailed
}
try png.write(to: outputURL, options: .atomic)
```

- [ ] **步骤 6：编译渲染器**

运行：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
mkdir -p .build/module-cache
find Sources/CodexMonitor -name '*.swift' \
  ! -path '*/App/CodexMonitorApp.swift' -print0 |
  xargs -0 xcrun swiftc \
    -swift-version 6 \
    -target arm64-apple-macosx14.0 \
    -module-cache-path .build/module-cache \
    scripts/generate-notch-poster.swift \
    -o .build/generate-notch-poster
```

预期：生成 `.build/generate-notch-poster`，且不存在重复 `@main` 或未解析类型错误。

- [ ] **步骤 7：提交渲染器**

```bash
git add scripts/generate-notch-poster.swift
git commit -m "工具：新增当前刘海海报渲染器"
```

---

### 任务二：生成无文字海报背景

**文件：**

- 新建：`docs/designs/codex-monitor-poster-background-v1.png`

**接口：**

- 输入：深色 macOS 产品海报背景提示词。
- 输出：3840 × 2160、无文字、无 UI、无设备边框的 PNG。

- [ ] **步骤 1：调用内置图像生成工具**

使用以下提示词生成背景：

```text
16:9 premium macOS utility product poster background only, near-black graphite
gradient, subtle deep violet ambient glow concentrated behind a centered
five-panel product grid, restrained soft bloom, very faint glassy depth,
clean negative space, no text, no letters, no numbers, no logos, no icons,
no interface, no windows, no devices, no mockups, no borders, no watermark.
```

- [ ] **步骤 2：保存并检查背景**

将生成结果保存为
`docs/designs/codex-monitor-poster-background-v1.png`。

运行：

```bash
sips -g pixelWidth -g pixelHeight \
  docs/designs/codex-monitor-poster-background-v1.png
```

预期：输出宽高为 3840 × 2160；画面不包含文字、图标、窗口或设备。

- [ ] **步骤 3：提交背景**

```bash
git add docs/designs/codex-monitor-poster-background-v1.png
git commit -m "设计：新增刘海海报深色背景"
```

---

### 任务三：生成并检查最终 4K 海报

**文件：**

- 新建：`docs/designs/codex-monitor-current-notch-poster-v1.png`

**接口：**

- 输入：任务一渲染器、任务二背景、当前本地数据。
- 输出：README 可直接引用的 4K PNG。

- [ ] **步骤 1：运行海报渲染器**

```bash
.build/generate-notch-poster \
  --background docs/designs/codex-monitor-poster-background-v1.png \
  --output docs/designs/codex-monitor-current-notch-poster-v1.png
```

预期：命令退出码为 0，并生成最终 PNG。

- [ ] **步骤 2：检查文件尺寸**

```bash
sips -g pixelWidth -g pixelHeight \
  docs/designs/codex-monitor-current-notch-poster-v1.png
```

预期：

```text
pixelWidth: 3840
pixelHeight: 2160
```

- [ ] **步骤 3：进行视觉检查**

逐项确认：

- 五页完整出现且顺序正确。
- 五个面板比例一致，没有裁切和变形。
- 每页标题、数字、热力格、项目图表、统计卡片、GitHub 仓库和分页指示点清晰。
- 背景中没有任何额外文字、UI 或隐私内容。
- 第一排两个面板和第二排三个面板均居中。

- [ ] **步骤 4：提交最终海报**

```bash
git add docs/designs/codex-monitor-current-notch-poster-v1.png
git commit -m "设计：生成当前刘海界面五页海报"
```

---

### 任务四：替换 README 首屏海报

**文件：**

- 修改：`README.md`

**接口：**

- 输入：`docs/designs/codex-monitor-current-notch-poster-v1.png`。
- 输出：README 首屏展示当前软件五页刘海海报。

- [ ] **步骤 1：替换图片路径和替代文字**

将 README 中旧的：

```html
<img src="docs/designs/macos-notch-pages-v1.png" alt="Codex Monitor macOS 刘海面板四页设计">
```

替换为：

```html
<img src="docs/designs/codex-monitor-current-notch-poster-v1.png" alt="Codex Monitor 当前 macOS 刘海面板五页海报">
```

- [ ] **步骤 2：检查文档引用**

```bash
rg -n "codex-monitor-current-notch-poster-v1|macos-notch-pages-v1" README.md
```

预期：README 只引用新海报路径，旧图片不再作为首屏海报。

- [ ] **步骤 3：提交 README 更新**

```bash
git add README.md
git commit -m "文档：首屏改用当前刘海五页海报"
```

---

### 任务五：最终交付检查

**文件：**

- 检查：`docs/designs/codex-monitor-current-notch-poster-v1.png`
- 检查：`README.md`

- [ ] **步骤 1：检查工作区和图片元数据**

```bash
git status --short
sips -g pixelWidth -g pixelHeight \
  docs/designs/codex-monitor-current-notch-poster-v1.png
```

预期：没有意外的未提交文件，图片尺寸为 3840 × 2160。

- [ ] **步骤 2：检查 README 图片文件存在**

```bash
test -f docs/designs/codex-monitor-current-notch-poster-v1.png
test -f Resources/AppIconPreview.png
```

预期：两个命令均退出 0。

- [ ] **步骤 3：打开最终图片进行人工视觉确认**

重点确认中文无乱码、数字未被生成模型改写、所有分页圆点状态正确、项目分析按钮和 GitHub 图标保持当前实现。
