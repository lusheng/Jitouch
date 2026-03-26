# Jitouch 开发任务清单

> 更新于 2026-03-25 — 基于仓库全面评估后制定的后续演进路线

## 项目现状

### 已完成（Phase 1 迁移）

| 模块 | 状态 | 说明 |
|------|------|------|
| 纯 Swift 项目结构 | ✅ | XcodeGen + project.yml，Swift 6 strict concurrency |
| MultitouchSupport 私有 API 边界 | ✅ | 仅 1 个 C header，Bridging Header 导入 |
| 触摸数据模型 | ✅ | TouchFrame / TouchPoint / GestureEvent 全值类型 Sendable |
| 设备管理 | ✅ | DeviceManager — IOKit 热插拔 + MTDevice 回调 |
| 事件拦截 | ✅ | EventTapManager — CGEventTap + tapDisabledByTimeout 恢复 |
| 手势识别引擎 | ✅ | 12 个识别器，GestureRecognizerProtocol 协议 |
| 命令执行器 | ✅ | CommandExecutor — 键盘模拟、窗口操作、系统命令 |
| 设置系统 | ✅ | LegacySettingsStore 兼容旧 plist + 自动持久化 |
| SwiftUI UI | ✅ | MenuBarExtra + Settings 窗口 + Onboarding 向导 |
| 视觉反馈 | ✅ | Move/Resize overlay + 字符识别轨迹 overlay |
| 菜单栏状态 | ✅ | 设备状态、权限状态、当前 App 路由 |

### 当前代码统计

```
Swift:  11,184 行 / 40 文件
ObjC:    7,492 行 / 21 文件（仅参考，不编译）
测试:    0 行
CI/CD:  无
```

### 已知的架构问题

1. **SettingsRootView.swift 2,219 行** — 单文件过大，5 个 Tab + 手势编辑器 + 应用覆盖全挤在一起
2. **JitouchAppModel.swift 682 行** — God Object，混合了生命周期、设置、运行时协调
3. **CommandExecutor.swift 1,002 行** — 键盘/窗口/系统命令/Open URL/Open File 全在一个 switch 里
4. **测试覆盖 0%** — 手势识别器是纯状态机，天然可测但未测
5. **无 CI/CD** — 每次提交无自动验证，Release 手动构建
6. **EventTap 无主动恢复** — 权限撤销或系统异常后不会自动重建
7. **设置格式绑定旧 plist** — 无 schema 版本化，无导入导出
8. **功能 parity 状态仍不完全清晰** — `Gesture.m` 的主体能力已拆出，但仍需逐项核对已迁移 / 待迁移 / 明确废弃
9. **Assets.xcassets 基本为空** — 仍依赖旧 `icns/png` 资源，高 DPI 和模板图标尚未彻底现代化
10. **多显示器窗口管理仍有风险** — 最大化、左右分屏、Move/Resize 主要基于 `NSScreen.main`
11. **回调桥使用 `nonisolated(unsafe)` 全局状态** — 当前可用，但长期需要收敛为更可审计的桥接层
12. **`ShowIcon` 等兼容项仍是“保留但未生效”状态** — 需要明确是继续支持还是正式废弃

---

## 近期迭代任务清单（新增）

> 这一组任务比后面的长期 Phase 更贴近当前代码现状，建议作为接下来 4-8 周的主线 backlog。

### Iteration A — 事实校准与防回归（P0）

#### Task A1 — 建立功能 parity 真值表

**目标**: 把“看起来已迁移”变成“可核对的已迁移”。

1. 从旧 `jitouch/Jitouch/Gesture.m` 提取：
   - 全部 `dispatchCommand(@"...")` 手势名
   - 全部 `command isEqualToString:@"..."` 动作名
2. 在仓库中创建一份 parity 清单，例如：
   - `docs/parity-matrix.md`
   - 或在本文件新增 `Parity Matrix` 章节
3. 每项标记为：
   - `已迁移并验证`
   - `已迁移待真机验证`
   - `未迁移`
   - `决定废弃`
4. 第一批必须明确结论的项目：
   - Trackpad `Two-Fix One-Slide-*`
   - `One-Fix Three-Slide`
   - `Quick Tab Switching`
   - `Select Tab Above Cursor`
   - `Dashboard` / `Spaces`

**验收标准**:
- 后续讨论 parity 时不再依赖口头判断
- 能明确回答“还有哪些旧功能不能删旧代码”

#### Task A2 — 测试基础设施 + 可回放输入夹具

**目标**: 先把识别器变成可验证系统，再谈调参。

1. 在 `project.yml` 中加入 `JitouchTests` target
2. 创建 `JitouchTests/TestHelpers/TouchFrameFactory.swift`
3. 创建 `JitouchTests/Fixtures/` 或内置 builder，用于回放：
   - 三指 / 四指 swipe
   - 三指 tap / 四指 tap
   - 固定指 tap / slide
   - Move / Resize 起手
   - 字符识别轨迹（`L`, `B`, `Up`, `Left` 等）
4. 第一批测试建议：
   - `CharacterRecognitionEngineTests`
   - `TrackpadSwipeRecognizerTests`
   - `TrackpadTapRecognizerTests`
   - `TrackpadFixFingerRecognizerTests`
   - `MagicMouseRecognizerTests`
   - `LegacySettingsStoreTests`

**验收标准**:
- `xcodebuild test` 可运行
- 至少覆盖最核心的 5 类识别器和设置兼容逻辑

#### Task A3 — 修正当前文档中的“过早完成”描述

**目标**: 避免后续 roadmap 建立在错误状态判断上。

1. 将 `Gesture.m → ✅ 已迁移` 调整为更准确的状态：
   - `🟡 主体已迁移，仍有 parity 收尾`
2. 将命令系统描述从“全量完成”改成：
   - “主体已迁移，剩余遗留动作需逐项裁剪或补齐”
3. 在 README 或本文件里明确：
   - 当前主要缺口是 parity、真机验证、测试、资源现代化

**验收标准**:
- 文档状态与代码现实一致

---

### Iteration B — 先拆大文件，再补稳定性（P0-P1）

#### Task B1 — 拆分 `SettingsRootView.swift`

**目标**: 降低 UI 修改成本，避免一个文件承载全部设置逻辑。

建议拆分为：
```
Views/
├── SettingsRootView.swift
├── Settings/
│   ├── OverviewTab.swift
│   ├── PermissionsTab.swift
│   ├── TrackpadSettingsTab.swift
│   ├── MagicMouseSettingsTab.swift
│   ├── CharacterRecognitionTab.swift
│   ├── GeneralSettingsTab.swift
│   ├── DiagnosticsTab.swift
│   └── Components/
```

**验收标准**:
- `SettingsRootView.swift` 控制在约 200-300 行
- 功能不变，仅做结构拆分

#### Task B2 — 拆分 `CommandExecutor.swift`

**目标**: 将命令路由与具体执行能力拆开。

建议结构：
```
Services/
├── CommandExecutor.swift
├── Executors/
│   ├── KeyboardCommandExecutor.swift
│   ├── WindowCommandExecutor.swift
│   ├── MouseCommandExecutor.swift
│   ├── SystemCommandExecutor.swift
│   └── ResourceCommandExecutor.swift
```

其中：
- `CommandExecutor` 只做路由与 resolution
- `WindowCommandExecutor` 负责 AX 窗口操作
- `SystemCommandExecutor` 负责 Mission Control / Launchpad / Dock 通知
- `ResourceCommandExecutor` 负责 Open URL / Open File

**验收标准**:
- 主文件显著瘦身
- 命令逻辑更容易测

#### Task B3 — 拆分 `JitouchAppModel.swift`

**目标**: 让 `AppModel` 从 God Object 退化为组合层。

建议拆为：
- `AppLifecycleCoordinator`
- `RuntimeCoordinator`
- `SettingsCoordinator`
- `OnboardingCoordinator`

**验收标准**:
- `JitouchAppModel.swift` 只保留对外 observable 状态与少量 facade

#### Task B4 — EventTap 健康检查与自动恢复

**目标**: 把“当前能跑”提升到“长期挂着也稳”。

1. 加入定时健康检查
2. tap disabled 后自动 re-enable / recreate
3. AX 权限撤销时自动降级，权限恢复时自动重启
4. 所有恢复事件写入 `os.Logger`

**验收标准**:
- 菜单栏能看出 runtime 异常
- 无需手动重启即可从常见 tap 失效场景恢复

#### Task B5 — 设备管理与窗口管理容错

**目标**: 降低真机环境下最容易出问题的两个点。

1. `DeviceManager`：
   - 收紧未知 `familyID` 的兜底分类策略
   - 补设备枚举失败重试与日志
2. `CommandExecutor`：
   - 基于窗口所在屏幕而不是 `NSScreen.main` 计算目标 frame
   - 处理多显示器、Dock 位置和不同 visibleFrame

**验收标准**:
- 真机插拔 / 唤醒 / 多显示器场景下行为更稳定

---

### Iteration C — 补产品面缺口（P1）

#### Task C1 — 资源现代化与高 DPI 收尾

**目标**: 完成从旧 png/icns 到现代资源管线的切换。

1. 真正建立 `Assets.xcassets`
2. 导入 / 重制：
   - AppIcon
   - 菜单栏模板图标
   - 诊断 / overlay 所需资源
3. 评估是否统一改为：
   - SF Symbols
   - PDF vector asset
   - 必要时保留少量位图资源
4. 清理旧资源引用路径

**验收标准**:
- 新 App 不再依赖 legacy 资源布局
- Retina / 深浅色 / 模板图标表现正常

#### Task C2 — 设置系统 v1 schema 化

**目标**: 从“长期绑死旧 plist”升级到“兼容旧格式但以新格式为主”。

1. 定义新的 Codable schema
2. 旧 `com.jitouch.Jitouch` 作为 importer
3. 新格式放到 `Application Support`
4. 增加 `settingsSchemaVersion`
5. 补导入 / 导出能力

**验收标准**:
- 新旧设置边界清晰
- 后续新增配置不再继续污染 legacy plist

#### Task C3 — 菜单栏与兼容项清理

**目标**: 明确哪些兼容项继续支持，哪些正式废弃。

需要逐项决策：
- `ShowIcon`
- 旧命令别名（如 `Chrome` / `Word`）
- 旧 PrefPane 残留语义
- 旧动作名的兼容读写

**验收标准**:
- 每个兼容项都有明确策略：支持 / 迁移 / 废弃

#### Task C4 — 真机验证矩阵

**目标**: 建立 Tahoe 时代真正有价值的验证清单。

建议按矩阵记录：
- macOS 15 / macOS 26
- 内建 Trackpad / Magic Trackpad / Magic Mouse
- 单显示器 / 多显示器
- Intel（如仍支持）/ Apple Silicon

每个矩阵项至少验证：
- 设备发现
- EventTap 启动
- 常用 gesture
- Move / Resize
- 字符识别
- 登录启动

**验收标准**:
- 不是“编译通过即兼容”，而是有真实设备结论

---

### Iteration D — 发布与开源收尾（P1-P2）

#### Task D1 — CI / Release 自动化

1. PR CI：`xcodegen generate` + `xcodebuild build` + `xcodebuild test`
2. Tag Release：签名、公证、打包、上传 artifact
3. 可选：SwiftLint / SwiftFormat

#### Task D2 — 开源维护材料

1. `CONTRIBUTING.md`
2. Issue / PR Template
3. `CHANGELOG.md`
4. 架构导读文档
5. 真机验证结果文档

#### Task D3 — Legacy 目录退场条件

**只有满足以下条件才建议删除 `jitouch/`**：
- parity 真值表完成
- 剩余未迁移项全部关闭
- 至少一轮真机回归完成
- 测试与 CI 基线建立

---

## Phase 2: 工程质量基础

> 优先级最高。没有测试和 CI 的代码只是看起来能跑。

### Task 2.1 — 测试基础设施搭建

**目标**: 在 project.yml 中添加测试 target，建立第一批单元测试。

1. 在 `project.yml` 中添加 `JitouchTests` target：
   - type: `unitTestBundle`
   - platform: macOS
   - dependencies: `[Jitouch]`
   - sources: `JitouchTests/`

2. 创建目录 `JitouchTests/`

3. 优先编写以下测试（按 ROI 排序）：

   **手势识别器测试**（最高 ROI — 纯状态机，输入 TouchFrame 输出 GestureEvent）：
   - `CharacterRecognitionEngineTests` — 路径匹配和评分算法，输入轨迹点序列，断言识别结果
   - `TrackpadSwipeRecognizerTests` — 构造三指/四指滑动的 TouchFrame 序列，验证方向判定
   - `TrackpadTapRecognizerTests` — 点击时间窗口、手指数判定
   - `TrackpadFixFingerRecognizerTests` — 固定指识别、操作指方向
   - `MagicMouseRecognizerTests` — Magic Mouse 手势识别

   **设置系统测试**：
   - `LegacySettingsStoreTests` — plist 读取、格式兼容、默认值回退
   - `CommandCatalogTests` — 手势→命令解析、per-app 覆盖优先级

   **辅助工具**：
   - 创建 `TestHelpers/TouchFrameFactory.swift` — 工厂方法生成测试用 TouchFrame 序列
   - 模拟三指轻拍：3 个 makeTouch → touching (短暂) → breakTouch
   - 模拟三指左滑：3 个 makeTouch → touching (x 递减) → breakTouch
   - 模拟字符 "L"：轨迹点序列 ↓→

4. 验证：`xcodebuild test` 通过

**注意**: 手势识别器当前直接依赖具体服务，可能需要先提取协议（见 Task 2.3）才能完全 mock。第一批测试可以直接构造 TouchFrame 调用 `processFrame()` 来测试。

---

### Task 2.2 — CI/CD 流水线

**目标**: PR 合入前自动编译 + 测试；Release 自动构建 + 签名 + 公证。

1. **GitHub Actions — PR 检查** (`.github/workflows/ci.yml`)：
   ```
   触发: pull_request + push to main
   环境: macos-15 runner
   步骤:
   - brew install xcodegen
   - xcodegen generate
   - xcodebuild build -scheme Jitouch -configuration Debug CODE_SIGNING_ALLOWED=NO
   - xcodebuild test -scheme Jitouch (当测试 target 就绪后启用)
   ```

2. **GitHub Actions — Release** (`.github/workflows/release.yml`)：
   ```
   触发: tag push (v*)
   步骤:
   - 构建 Release configuration
   - 代码签名 (Developer ID Application)
   - notarytool 提交公证
   - 打包 .dmg
   - 创建 GitHub Release + 上传 artifact
   ```
   签名证书和 Apple ID 凭据通过 GitHub Secrets 注入。

3. **可选：SwiftLint**
   - 添加 `.swiftlint.yml` 基础规则
   - CI 中运行 `swiftlint lint --strict`

4. 验证：PR 提交后 CI 自动运行，状态检查通过

---

### Task 2.3 — 服务层可测试性重构

**目标**: 为核心服务提取协议接口，支持测试注入。

1. 提取协议：
   ```swift
   protocol DeviceManaging: AnyObject, Sendable {
       var trackpadDevices: [MTDeviceRef] { get }
       var magicMouseDevices: [MTDeviceRef] { get }
       func start(trackpadHandler: MTContactCallbackFunction,
                  mouseHandler: MTContactCallbackFunction)
       func stop()
   }

   protocol EventTapManaging: AnyObject, Sendable {
       var isRunning: Bool { get }
       func start() throws
       func stop()
   }

   protocol CommandExecuting: AnyObject, Sendable {
       func execute(_ event: GestureEvent, settings: JitouchSettings,
                    commands: ApplicationCommandSet) async
   }
   ```

2. 让现有实现遵循协议（无需改变外部行为）

3. `JitouchAppModel` 通过协议引用服务（而非具体类型）

4. 创建 Mock 实现用于测试：
   - `MockDeviceManager` — 可控制的设备列表
   - `MockEventTapManager` — 记录 start/stop 调用
   - `MockCommandExecutor` — 记录收到的 GestureEvent

5. 验证：现有功能不受影响，测试可以注入 mock

---

## Phase 3: 架构优化

> 拆分过大的文件，清理 God Object。

### Task 3.1 — 拆分 SettingsRootView (2,219 行)

**目标**: 按 Tab 拆分为独立 View 文件，每个 300-500 行。

拆分方案：
```
Views/
├── SettingsRootView.swift          ← 瘦身为 Tab 容器 (~100 行)
├── Settings/
│   ├── TrackpadSettingsTab.swift    ← Trackpad 手势配置
│   ├── MagicMouseSettingsTab.swift  ← Magic Mouse 手势配置
│   ├── CharacterRecognitionTab.swift ← 字符识别配置
│   ├── GeneralSettingsTab.swift     ← 通用设置 + 权限 + 调试
│   ├── AppOverridesTab.swift        ← 应用专属覆盖
│   └── Components/
│       ├── GestureEditorView.swift  ← 手势编辑器（复用）
│       ├── CommandPickerView.swift  ← 命令选择下拉
│       └── OverrideDiffBadge.swift  ← 覆盖差异标记
```

原则：
- SettingsRootView 只做 Tab 切换和窗口级布局
- 每个 Tab 是独立的 struct View，接收 `@Bindable` 的 model
- 可复用组件提取到 Components/
- 不改变任何功能行为

---

### Task 3.2 — 拆分 JitouchAppModel (682 行)

**目标**: 拆分为 3 个职责清晰的协调器。

```
JitouchAppModel.swift  ← 退化为薄组合层 (~150 行)
  ├── AppLifecycleCoordinator.swift  ← 启动/停止序列、系统事件监听、唤醒恢复
  ├── SettingsCoordinator.swift      ← 设置读写、迁移、验证、persist()
  └── RuntimeCoordinator.swift       ← 运行时服务编排、设备→引擎→执行器的连接
```

JitouchAppModel 保留为 @Observable 的对外接口，内部委托给三个 coordinator。

---

### Task 3.3 — 拆分 CommandExecutor (1,002 行)

**目标**: 按命令类别拆分执行逻辑。

```
Services/
├── CommandExecutor.swift         ← 路由层 (~100 行)，按 CommandType.category 分发
├── Executors/
│   ├── KeyboardCommandExecutor.swift   ← 键盘快捷键模拟
│   ├── WindowCommandExecutor.swift     ← AXUIElement 窗口操作
│   ├── SystemCommandExecutor.swift     ← Mission Control / Launchpad / Spaces
│   ├── MouseCommandExecutor.swift      ← 中键点击、自动滚动
│   └── ScriptCommandExecutor.swift     ← AppleScript / Open URL / Open File
```

---

## Phase 4: 稳定性与容错

> 让 App 在真实环境中可靠运行。

### Task 4.1 — EventTap 健康监控和自动恢复

**目标**: EventTap 被系统 disable 后自动恢复，权限撤销后优雅降级。

1. **心跳检测**：
   - 定时器（每 5 秒）检查 `CGEvent.tapIsEnabled(tap:)` 状态
   - 如果 disabled，尝试 `CGEvent.tapEnable(tap:, enable: true)`
   - 如果 re-enable 失败 3 次，销毁并重建整个 EventTap

2. **权限变更响应**：
   - 定时检查 `AXIsProcessTrusted()`
   - 权限被撤销 → 停止所有运行时服务 → 菜单栏显示警告 → 引导重新授权
   - 权限重新授予 → 自动重启服务

3. **菜单栏健康指示**：
   - 正常：标准图标
   - EventTap 异常：图标带黄色警告点
   - 权限缺失：图标变灰 + 提示文字

4. 使用 `os.Logger` 记录所有恢复事件，便于排查

---

### Task 4.2 — 设备管理容错增强

**目标**: 设备断连/重连、系统唤醒后稳定恢复。

1. **IOKit 热插拔回调容错**：
   - 回调中 catch 所有异常，避免崩溃
   - 设备移除时确保释放 MTDevice 资源（stop + unregister callback）

2. **系统唤醒恢复**：
   - 监听 `NSWorkspace.didWakeNotification`
   - 唤醒后延迟 2 秒，然后 stop → start 全部设备
   - 加入重试逻辑（最多 3 次，间隔 1 秒）

3. **设备枚举失败处理**：
   - `MTDeviceCreateList()` 返回空或 nil → 延迟重试
   - familyID 查询失败 → 跳过该设备并记录日志

---

### Task 4.3 — 性能优化

**目标**: 确保触摸帧处理 < 1ms 延迟，无多余内存分配。

1. **触摸回调热路径分析**：
   - 使用 Instruments / os_signpost 标记 `handleTouchFrame` 耗时
   - 目标：每帧处理时间 P99 < 1ms

2. **减少堆分配**：
   - TouchPoint 已是 struct，确认 TouchFrame 的 `[TouchPoint]` 不产生不必要的 copy
   - 考虑固定大小数组（最多 11 个手指）替代动态 Array
   - 识别器内部状态变量使用值类型

3. **避免主线程阻塞**：
   - 触摸回调在 MultitouchSupport 的回调线程执行，识别器在同一线程完成
   - 仅在最终执行命令时 dispatch 到主线程
   - 确认 @MainActor 标注不会导致回调中隐式 dispatch

---

## Phase 5: 设置系统演进

> 从旧 plist 兼容层过渡到现代化设置系统。

### Task 5.1 — 设置 Schema 版本化

**目标**: 引入版本化的 Codable 设置格式，支持向前兼容。

1. 定义 `SettingsSchema_v1`（对应当前 LegacySettingsStore 的语义）

2. 迁移逻辑：
   ```
   App 启动
     → 检查 plist 中是否有 "settingsSchemaVersion" key
     → 无版本标记 → 按旧格式读取 → 自动迁移为 v1 并写入版本标记
     → 版本 < 当前 → 运行对应迁移函数链
     → 版本 = 当前 → 直接加载
   ```

3. 后续每次 schema 变更，新增迁移函数 `migrateV1toV2()` 等

4. 保留 LegacySettingsStore 作为 v0 → v1 的一次性迁移器

---

### Task 5.2 — 设置导入/导出

**目标**: 用户可以导出完整设置为 JSON 文件，在另一台 Mac 上导入。

1. 导出：将当前设置序列化为带版本号的 JSON → NSSavePanel 保存
2. 导入：NSOpenPanel 选择 JSON → 验证版本号 → 反序列化 → 确认覆盖 → 应用
3. UI：设置窗口 General Tab 底部添加"导入设置"/"导出设置"按钮
4. 格式包含：全局设置 + 所有手势绑定 + 应用覆盖 + 字符识别配置

---

## Phase 6: 功能增强

> 差异化功能，提升竞争力。

### Task 6.1 — 国际化 (i18n)

**目标**: 支持中英文 UI。

1. 创建 `Localizable.xcstrings`（Xcode 15+ String Catalog）
2. 将所有硬编码 UI 字符串替换为 `String(localized:)` 调用
3. 首批语言：英语 (en) + 简体中文 (zh-Hans)
4. 命令名称、手势名称、Onboarding 文案、菜单栏文案
5. 设置窗口标题、Tab 名称、Section 标题

---

### Task 6.2 — 手势冲突检测

**目标**: 当用户配置的手势条件重叠时，在 Settings UI 中给出可视化提示。

1. 定义冲突规则：
   - 相同 finger count + 相同 device type 的手势互斥性检查
   - 例如：三指轻拍 vs 三指滑动（轻拍是短时间接触，滑动有位移要求）— 这不算冲突
   - 例如：一固一滑左 vs 三指左滑 — 潜在冲突（取决于手指排布）

2. Settings UI 中在冲突手势旁边显示警告图标 + tooltip 说明

3. 不阻止用户保存，仅作为提示

---

### Task 6.3 — 窗口管理增强

**目标**: 扩展 Move/Resize 支持屏幕边缘吸附和分屏。

1. **边缘吸附**：
   - 拖拽窗口到屏幕边缘 → 自动 snap 到半屏/四分屏
   - 吸附区域：屏幕左/右边缘（50%宽度）、四个角（25%面积）
   - 接近边缘时显示半透明预览区域

2. **多显示器支持**：
   - 窗口拖过屏幕边界 → 自动切换到相邻显示器
   - `moveToNextScreen` 命令遍历 `NSScreen.screens`

3. 需要的底层能力：
   - AXUIElement 设置窗口 position + size
   - 当前 `TrackpadMoveResizeRecognizer` 已支持 dx/dy，在 `CommandExecutor` 中添加吸附判定逻辑

---

### Task 6.4 — 交互式手势教程

**目标**: Onboarding 中添加"试一试"步骤。

1. 在 OnboardingFlowView 中新增 "Try It" 步骤
2. 显示一个手势名称（如"三指左滑"）+ 动画示意
3. 用户在触控板上执行该手势 → App 实时识别并给出 ✅ 反馈
4. 完成 3-5 个基础手势后标记 onboarding 完成
5. 需要临时模式：识别到手势后不执行命令，仅反馈给 Onboarding UI

---

### Task 6.5 — 自定义手势录制（远期）

**目标**: 用户可以录制自定义触摸轨迹并绑定为手势。

1. 手势录制 UI：
   - 点击"录制"按钮 → 进入录制模式
   - 实时显示触摸轨迹
   - 录制完成 → 保存为 `GestureTemplate`（轨迹点序列 + 手指数 + 时间特征）

2. 匹配引擎：
   - 新增 `CustomGestureRecognizer`，对录制的模板做 DTW (Dynamic Time Warping) 匹配
   - 匹配阈值可调

3. 管理 UI：
   - 自定义手势列表、命名、绑定命令、删除
   - 存储在设置 JSON 中

4. 这是大型功能，建议在其他 Phase 稳定后再启动

---

## Phase 7: 开源发布

> 让项目进入可持续的开源状态。

### Task 7.1 — 代码签名与分发

1. **Developer ID 证书配置**：
   - 在 project.yml Release 配置中设置 DEVELOPMENT_TEAM
   - Hardened Runtime 签名

2. **公证 (Notarization)**：
   - CI 中集成 `notarytool submit` + `stapler staple`
   - 未公证的 app 在 macOS 上会被 Gatekeeper 拦截

3. **分发格式**：
   - .dmg（拖拽安装）
   - 可选：Homebrew Cask formula

4. **自动更新**（可选）：
   - 集成 Sparkle 2.x (SPM)
   - appcast.xml 托管在 GitHub Pages 或 Releases

---

### Task 7.2 — 开源准备

1. 添加 `LICENSE` 文件 (GPL v3)
2. 创建 `CONTRIBUTING.md`：
   - 开发环境搭建（Xcode 16+, xcodegen, macOS 15+）
   - 编码规范（Swift 6, strict concurrency）
   - PR 流程
   - 架构概述和关键模块导读
3. 创建 `.github/ISSUE_TEMPLATE/` — bug report + feature request
4. 创建 `.github/PULL_REQUEST_TEMPLATE.md`
5. 更新 `README.md`（安装说明、功能列表、截图、致谢）
6. 创建 `CHANGELOG.md`
7. 评估是否删除 `jitouch/` 旧代码目录（或在 README 中标记为 legacy reference）

---

### Task 7.3 — macOS 版本兼容性验证

1. **macOS 15 (Sequoia)** — 当前主要开发环境，持续验证
2. **macOS 16 (Tahoe)** — 需重点关注：
   - MultitouchSupport 私有 API 是否有签名变化
   - CGEventTap 行为是否变化
   - IOKit 设备枚举接口是否变化
   - SwiftUI 行为差异（MenuBarExtra、Settings window）
3. CI 中添加 macOS 16 runner（当 GitHub Actions 支持时）
4. 对私有 API 调用加运行时 guard：调用失败时 graceful degrade 而非 crash

---

## 优先级总览

```
Phase 2: 工程质量基础    ████████████ P0 — 立即开始
  2.1 测试基础设施         ●●●○  中等工作量，收益极高
  2.2 CI/CD                ●●○○  小工作量，持续收益
  2.3 服务层可测试性       ●●○○  小工作量，为测试铺路

Phase 3: 架构优化         ████████████ P0 — 与 Phase 2 并行
  3.1 拆分 SettingsRootView ●○○○  小工作量，立即改善开发体验
  3.2 拆分 JitouchAppModel  ●●○○  中等工作量
  3.3 拆分 CommandExecutor   ●●○○  中等工作量

Phase 4: 稳定性与容错     ████████░░░░ P1
  4.1 EventTap 恢复         ●●○○  关键稳定性
  4.2 设备管理容错          ●○○○  小工作量
  4.3 性能优化              ●●○○  需要 Instruments profiling

Phase 5: 设置系统演进     ████░░░░░░░░ P2
  5.1 Schema 版本化         ●●○○
  5.2 设置导入/导出         ●○○○

Phase 6: 功能增强         ████░░░░░░░░ P2-P3
  6.1 国际化               ●●●○  覆盖面广
  6.2 手势冲突检测          ●○○○
  6.3 窗口管理增强          ●●○○
  6.4 交互式手势教程        ●●○○
  6.5 自定义手势录制        ●●●●  大型功能，远期

Phase 7: 开源发布         ████████░░░░ P1
  7.1 代码签名与分发        ●●●○  发布前必须
  7.2 开源准备              ●●○○
  7.3 macOS 兼容性验证      ●●○○  持续性工作
```

### 建议执行顺序

```
第 1 批（立即）:  2.1 + 2.2 + 3.1
第 2 批:          2.3 + 3.2 + 3.3
第 3 批:          4.1 + 4.2 + 7.1
第 4 批:          5.1 + 6.1 + 7.2
第 5 批:          4.3 + 5.2 + 6.2 + 6.3 + 7.3
远期:             6.4 + 6.5
```

---

## Milestone 1 — 工程质量基线与设置 UI 解耦

> 对应“第 1 批（立即）”。目标不是增加功能，而是把后续迭代的基础设施和开发体验打稳。

### 里程碑目标

1. 建立最小可用测试体系，能在本地和 CI 中运行
2. 建立第一份功能 parity 真值表，避免后续重构建立在错误假设上
3. 将 `SettingsRootView.swift` 拆到可维护状态，降低后续 UI 迭代成本
4. 建立 PR 级自动构建检查，避免主分支持续积累回归

### 完成定义（Definition of Done）

- `xcodebuild test` 可运行，至少覆盖首批核心识别器与设置兼容逻辑
- GitHub Actions PR CI 可自动执行 `xcodegen generate` + `xcodebuild build`
- `SettingsRootView.swift` 降到约 200-300 行，仅保留窗口级容器与导航
- parity 清单已经落库，并明确第一批遗留项状态

### 非目标（本里程碑不做）

- 不在这一批处理 EventTap 自动恢复
- 不在这一批推进 schema 版本化
- 不在这一批做新功能增强
- 不在这一批删除 `jitouch/` legacy 目录

### Issue List

| ID | 标题 | 来源 | 预估 | 依赖 |
|----|------|------|------|------|
| M1-01 | 建立功能 parity 真值表并校正文档状态 | Iteration A / Task A1 + A3 | S | 无 |
| M1-02 | 添加 `JitouchTests` target 与测试目录骨架 | Phase 2 / Task 2.1 | S | 无 |
| M1-03 | 实现 `TouchFrameFactory` 与首批测试夹具 | Phase 2 / Task 2.1 | M | M1-02 |
| M1-04 | 补第一批识别器与设置兼容测试 | Phase 2 / Task 2.1 | M | M1-03 |
| M1-05 | 建立 PR CI 基线工作流 | Phase 2 / Task 2.2 | S | M1-02 |
| M1-06 | 拆分 `SettingsRootView` 为 Tab 容器 + 子视图骨架 | Phase 3 / Task 3.1 | M | 无 |
| M1-07 | 提取 Settings 公共组件并完成 UI 拆分收尾 | Phase 3 / Task 3.1 | M | M1-06 |

### Issue 细化

#### M1-01 — 建立功能 parity 真值表并校正文档状态

**目标**
- 形成一份可以持续维护的旧功能对照表，明确哪些能力已经迁移、哪些待验证、哪些决定废弃。

**建议交付物**
- `docs/parity-matrix.md`
- 更新 `REFACTOR_TASKS.md` / `README.md` 中过于乐观的状态描述

**任务拆分**
1. 从 `jitouch/Jitouch/Gesture.m` 提取全部手势名和动作名
2. 在新仓库中逐项对照：
   - 新 recognizer 是否能产出该手势事件
   - 新 command executor 是否能执行该动作
3. 标记状态：
   - `已迁移并验证`
   - `已迁移待真机验证`
   - `未迁移`
   - `已废弃`
4. 第一批必须单独列出的遗留项：
   - `Two-Fix One-Slide-*`（Trackpad）
   - `One-Fix Three-Slide`
   - `Quick Tab Switching`
   - `Select Tab Above Cursor`
   - `Dashboard`
   - `Spaces`

**验收标准**
- 团队可以明确回答“删除 legacy 前还差什么”
- 后续 issue 能直接引用 parity 清单

#### M1-02 — 添加 `JitouchTests` target 与测试目录骨架

**目标**
- 让仓库第一次具备可运行测试 target。

**涉及文件**
- `project.yml`
- `JitouchTests/`

**任务拆分**
1. 在 `project.yml` 添加 `JitouchTests`
2. 创建基础目录：
   - `JitouchTests/TestHelpers/`
   - `JitouchTests/Recognizers/`
   - `JitouchTests/Services/`
3. 生成工程并确认 test target 能被 Xcode / `xcodebuild` 识别

**验收标准**
- `xcodegen generate` 后存在 `JitouchTests`
- `xcodebuild test -scheme Jitouch` 至少能启动测试流程

#### M1-03 — 实现 `TouchFrameFactory` 与首批测试夹具

**目标**
- 让识别器测试可读、可复用、可扩展，而不是在每个测试里手写低层 `TouchFrame`。

**建议交付物**
- `JitouchTests/TestHelpers/TouchFrameFactory.swift`
- 如有必要：`GestureFixtureBuilder.swift`

**任务拆分**
1. 封装常用辅助：
   - 单帧 `TouchFrame` builder
   - 多帧序列 builder
   - 常用触点状态快捷构造
2. 内置首批轨迹夹具：
   - 三指左滑 / 右滑 / 上滑 / 下滑
   - 三指 tap / 四指 tap
   - 固定指 tap / 固定指双滑
   - 字符 `L` / `B` / `Up` / `Left`

**验收标准**
- 后续识别器测试能用工厂函数表达，不需要重复写底层 frame 组装

#### M1-04 — 补第一批识别器与设置兼容测试

**目标**
- 给高 ROI 模块先加防回归网。

**建议测试范围**
- `CharacterRecognitionEngineTests`
- `TrackpadSwipeRecognizerTests`
- `TrackpadTapRecognizerTests`
- `TrackpadFixFingerRecognizerTests`
- `MagicMouseRecognizerTests`
- `LegacySettingsStoreTests`

**任务拆分**
1. 先覆盖纯算法与纯状态机
2. 再覆盖 legacy 设置兼容：
   - 默认值回退
   - 布尔 / 数值 /字符串兼容读取
   - command sets 反序列化
3. 为已知 tricky case 留回归样本

**验收标准**
- 至少 6 个测试文件
- 能覆盖第一批最常修改、最易回归的识别逻辑

#### M1-05 — 建立 PR CI 基线工作流

**目标**
- 每次提交自动校验“工程可生成、代码可编译”。

**建议交付物**
- `.github/workflows/ci.yml`

**任务拆分**
1. 安装 `xcodegen`
2. 运行 `xcodegen generate`
3. 运行 `xcodebuild build -scheme Jitouch -configuration Debug CODE_SIGNING_ALLOWED=NO`
4. 测试 target 就绪后追加 `xcodebuild test`

**验收标准**
- PR / push 到主分支自动触发
- 构建失败能阻止低质量变更直接进入主线

#### M1-06 — 拆分 `SettingsRootView` 为 Tab 容器 + 子视图骨架

**目标**
- 先拆结构，不在第一步里做 UI 行为变更。

**建议拆分方式**
- `SettingsRootView.swift`：只保留导航和容器布局
- `Views/Settings/OverviewTab.swift`
- `Views/Settings/PermissionsTab.swift`
- `Views/Settings/TrackpadSettingsTab.swift`
- `Views/Settings/MagicMouseSettingsTab.swift`
- `Views/Settings/CharacterRecognitionTab.swift`
- `Views/Settings/GeneralSettingsTab.swift`
- `Views/Settings/DiagnosticsTab.swift`

**任务拆分**
1. 先创建空骨架并接线
2. 逐段搬运现有 body 内容
3. 保持所有 binding 与 environment 注入不变

**验收标准**
- UI 行为无变化
- 主文件显著缩小

#### M1-07 — 提取 Settings 公共组件并完成 UI 拆分收尾

**目标**
- 把拆出来的 tab 再进一步去重，避免复制粘贴式重构。

**建议提取的组件**
- `GestureEditorView`
- `CommandPickerView`
- `AppOverridePickerView`
- `SettingsSectionCard`
- `DiagnosticMetricRow`

**任务拆分**
1. 抽出重复 section / row / picker
2. 统一命名和目录结构
3. 顺手补最基础的 preview 或构造样例

**验收标准**
- Tab 文件职责清晰
- 公共 UI 组件可在后续设置页复用

### 建议并行方式

```
并行流 A: M1-01 + M1-02 + M1-06
并行流 B: M1-03 + M1-05（在 M1-02 完成后）
并行流 C: M1-04 + M1-07（分别依赖 M1-03 / M1-06）
```

### 建议合入顺序

```
PR 1: M1-02 测试 target 骨架
PR 2: M1-01 parity 真值表与文档校正
PR 3: M1-06 SettingsRootView 骨架拆分
PR 4: M1-03 测试夹具
PR 5: M1-05 CI 基线
PR 6: M1-04 第一批测试
PR 7: M1-07 UI 组件抽取收尾
```

---

## 架构概览（当前）

```
Jitouch.app (Pure Swift, SwiftUI, macOS 15+)
├── App Layer          — SwiftUI 生命周期、MenuBarExtra、Settings 界面
├── Command Layer      — 手势→动作映射、CommandExecutor
├── Gesture Layer      — 手势识别状态机 (12 个识别器, GestureRecognizerProtocol)
├── Touch Layer        — MultitouchSupport 私有 API (C header + Swift 直接调用)
├── Event Layer        — CGEventTap 鼠标事件拦截 (Swift CGEvent API)
└── Device Layer       — IOKit 设备热插拔 (Swift IOKit API)
```

**私有 API 边界**: 仅 `MultitouchSupport.h` 一个 C 头文件，通过 Bridging Header 导入。

### 文件结构

```
JitouchApp/
├── App/
│   └── JitouchApp.swift                          # @main 入口
├── Models/
│   ├── AppSettings.swift                         # JitouchSettings, Handedness, LogLevel
│   ├── CommandModels.swift                       # GestureCommand, ApplicationCommandSet
│   ├── TouchModels.swift                         # TouchFrame, TouchPoint, GestureEvent
│   ├── OnboardingModels.swift                    # OnboardingChecklistItem
│   └── SettingsNavigationModels.swift            # JitouchSettingsPane
├── Services/
│   ├── JitouchAppModel.swift                     # 中央状态协调
│   ├── CommandExecutor.swift                     # 手势→命令执行
│   ├── CommandCatalog.swift                      # 手势→命令映射目录
│   ├── DeviceManager.swift                       # MTDevice 管理
│   ├── EventTapManager.swift                     # CGEventTap 管理
│   ├── GestureEngine.swift                       # 识别器路由
│   ├── LegacySettingsStore.swift                 # 旧 plist 兼容
│   ├── AccessibilityPermissionService.swift      # AXIsProcessTrusted
│   ├── LaunchAtLoginService.swift                # SMAppService
│   ├── KeyboardSimulationService.swift           # CGEvent 键盘模拟
│   ├── MagicMouseCharacterRecognitionService.swift
│   ├── CommandFeedbackOverlayController.swift    # 命令执行反馈 overlay
│   ├── CharacterRecognitionOverlayController.swift
│   ├── CharacterRecognitionDiagnosticsStore.swift
│   └── Recognizers/
│       ├── GestureRecognizerProtocol.swift
│       ├── TrackpadTapRecognizer.swift
│       ├── TrackpadSwipeRecognizer.swift
│       ├── TrackpadFixFingerRecognizer.swift
│       ├── TrackpadPinchRecognizer.swift
│       ├── TrackpadMoveResizeRecognizer.swift
│       ├── TrackpadTabSwitchRecognizer.swift
│       ├── TrackpadCharacterRecognizer.swift
│       ├── TrackpadOneFingerCharacterRecognizer.swift
│       ├── TrackpadGestureContext.swift
│       ├── CharacterRecognitionEngine.swift
│       └── MagicMouseRecognizer.swift
├── Views/
│   ├── SettingsRootView.swift                    # 设置窗口 (待拆分)
│   ├── MenuBarContentView.swift                  # 菜单栏内容
│   ├── OnboardingFlowView.swift                  # 首次启动向导
│   ├── JitouchChrome.swift                       # 可复用 UI 组件
│   └── ShortcutRecorderField.swift               # 快捷键录制
├── PrivateAPI/
│   ├── MultitouchSupport.h
│   └── PrivateAPIs.h
├── Jitouch-Bridging-Header.h
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/

jitouch/                                          # 旧 ObjC 源码 (仅参考)
```

### 旧文件到新模块映射（参考）

| 旧文件 | 新模块 | 状态 |
|--------|--------|------|
| `Gesture.m` (4,304 行) | DeviceManager + EventTapManager + GestureEngine + Recognizers/* | 🟡 主体已迁移，仍有 parity 收尾 |
| `Settings.m` | AppSettings + CommandModels + LegacySettingsStore | ✅ 已迁移 |
| `JitouchAppDelegate.m` | JitouchAppModel + MenuBarContentView | 🟡 主体已迁移，仍需持续收敛生命周期职责 |
| `KeyUtility.m` | CommandExecutor + KeyboardSimulationService | 🟡 主体已迁移，命令分类仍待拆分 |
| `CursorWindow.m` / `GestureWindow.m` | Overlay controllers | ✅ 已迁移 |
| `SystemEvents.h` / `SystemPreferences.h` | 未直接迁入，默认不再依赖 ScriptingBridge | ✅ 设计决策 |
