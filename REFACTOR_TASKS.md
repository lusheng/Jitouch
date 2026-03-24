# Jitouch 现代化重构 Task List

## 重构目标
- 纯 Swift 实现（仅保留一个 C 头文件声明 MultitouchSupport 私有 API 类型）
- prefPane → 独立 SwiftUI MenuBar App
- 支持 macOS 15+ 至 macOS 26 (Tahoe)
- Retina 高清分辨率（SF Symbols + 矢量资源）
- 开源免费 (GPL v3)

## 当前仓库审计（2026-03-24）
- 旧实现的功能核心几乎全部集中在 `jitouch/Jitouch/Gesture.m`，单文件 4304 行，混合了设备发现、私有 API、事件拦截、手势状态机、命令分发和字符识别。
- `jitouch/Jitouch/Settings.m` 仍然是旧版配置结构的“真相来源”，包括默认手势、plist key 和兼容行为；迁移时应优先复用其数据语义，而不是重新发明格式。
- `jitouch/Jitouch/JitouchAppDelegate.m` 主要承担菜单栏、可访问性提示和设置同步职责，适合迁移为新的 `AppModel` + `MenuBarExtra`。
- `jitouch/Jitouch/SystemEvents.h` 与 `jitouch/Jitouch/SystemPreferences.h` 是旧式 ScriptingBridge 头，长期目标应尽量从新架构中移除，仅在确实需要 Apple Events 自动化时以更小边界重引入。
- 新版工程建议以 `project.yml` 作为工程真源，通过 `xcodegen generate` 生成 `Jitouch.xcodeproj`，避免手写 `pbxproj`。
- 新版独立 App 应继续兼容旧偏好域 `com.jitouch.Jitouch`，优先实现“读取旧配置直接可用”，再逐步做设置迁移和格式升级。

## 推荐实施顺序
1. 先把独立 App 壳、偏好读取兼容层和私有 API 头文件边界搭起来，让仓库重新具备可持续演进的工程基础。
2. 然后拆 `Gesture.m`：先分离设备管理、事件拦截、命令执行，再迁移手势识别器本体，避免直接做 4300 行的逐行翻译。
3. 最后再处理高清资源、设置 UI、开源打包和 Tahoe 兼容性收尾，这些适合建立在新架构已经稳定之后。

## 旧文件到新模块映射
| 旧文件 | 新模块 |
| --- | --- |
| `jitouch/Jitouch/JitouchAppDelegate.m` | `JitouchApp/App/` + `JitouchApp/Views/` + `JitouchApp/Services/JitouchAppModel.swift` |
| `jitouch/Jitouch/Settings.m` | `JitouchApp/Models/AppSettings.swift` + `JitouchApp/Models/CommandModels.swift` + `JitouchApp/Services/LegacySettingsStore.swift` |
| `jitouch/Jitouch/Gesture.m` | `JitouchApp/Services/DeviceManager.swift` + `EventTapManager.swift` + `GestureEngine.swift` + `Services/Recognizers/*` |
| `jitouch/Jitouch/KeyUtility.m` | `CommandExecutor.swift` / `KeyboardSimulationService.swift` |
| `jitouch/Jitouch/CursorWindow.m` / `GestureWindow.m` | `OverlayWindowController.swift` 或后续 SwiftUI/AppKit overlay bridge |
| `jitouch/Jitouch/SystemEvents.h` / `SystemPreferences.h` | 最小化 Apple Events 边界，默认不直接迁入 |

## 架构概览

```
Jitouch.app (Pure Swift, SwiftUI, macOS 15+)
├── App Layer          — SwiftUI 生命周期、MenuBarExtra、Settings 界面
├── Command Layer      — 手势→动作映射、CommandExecutor
├── Gesture Layer      — 手势识别状态机 (纯 Swift)
├── Touch Layer        — MultitouchSupport 私有 API (C header + Swift 直接调用)
├── Event Layer        — CGEventTap 鼠标事件拦截 (Swift CGEvent API)
└── Device Layer       — IOKit 设备热插拔 (Swift IOKit API)
```

**私有 API 边界**: 仅 MultitouchSupport.h 一个 C 头文件，通过 Bridging Header 导入，Swift 直接调用 C 函数，无需任何 .m 文件。

---

## Phase 1: 项目基础搭建

### Task 1.1 — 创建纯 Swift 项目结构

```
请在 /Users/lusheng/Documents/开发/Jitouch/ 下创建新的 Xcode 项目和目录结构。
要求纯 Swift 项目，不包含任何 ObjC .m 文件。

补充实现建议：
- 使用 `project.yml` + `xcodegen generate` 生成 `Jitouch.xcodeproj`
- 将 `project.yml` 视为工程真源，避免后续多人协作时直接手改 `pbxproj`

1. 创建目录结构:
   Jitouch/
   ├── JitouchApp/
   │   ├── App/
   │   │   └── JitouchApp.swift          # @main 入口
   │   ├── Views/                         # SwiftUI 视图
   │   ├── Models/                        # 数据模型
   │   ├── Services/                      # 业务服务层
   │   ├── PrivateAPI/                    # 私有 API C 头文件
   │   │   ├── MultitouchSupport.h        # MultitouchSupport 类型和函数声明
   │   │   └── PrivateAPIs.h              # 其他私有 C 函数声明 (CoreDockSendNotification 等)
   │   ├── Jitouch-Bridging-Header.h      # 桥接头文件，引入上述 .h
   │   └── Resources/
   │       └── Assets.xcassets/           # 图标和图片资源
   ├── Jitouch.xcodeproj/
   └── jitouch/                           # 旧 ObjC 源码 (仅参考)

2. Xcode 工程配置:
   - Product: Jitouch.app
   - Bundle ID: com.jitouch.Jitouch
   - Deployment Target: macOS 15.0
   - Swift Language Version: 6.0
   - App Category: public.app-category.utilities
   - App Sandbox: 关闭 (需要 CGEventTap、Accessibility API、私有框架)
   - Hardened Runtime: 开启，但禁用 Library Validation (需加载私有框架)
   - Signing: Sign to Run Locally
   - Framework Search Paths: /System/Library/PrivateFrameworks (用于链接 MultitouchSupport.framework)
   - Other Linker Flags: -framework MultitouchSupport -weak_framework MultitouchSupport
   - Bridging Header: JitouchApp/Jitouch-Bridging-Header.h
   - Info.plist:
     - LSUIElement = true (无 Dock 图标)
     - NSAppleEventsUsageDescription = "Jitouch needs to control applications for gesture commands."

3. 创建 Assets.xcassets:
   - AppIcon: 使用现有 jitouchicon.icns 转换
   - 菜单栏图标: 从 logosmall.png / logosmalloff.png 制作 Template Image
   - 手势图标: circle.png, move.png, resize.png, tab.png 导入为 Image Set

4. 创建 JitouchApp.swift 最小可运行版本:
   ```swift
   import SwiftUI

   @main
   struct JitouchApp: App {
       var body: some Scene {
           MenuBarExtra("Jitouch", image: "MenuBarIcon") {
               Button("Preferences...") {
                   // TODO
               }
               .keyboardShortcut(",", modifiers: .command)
               Divider()
               Button("Quit Jitouch") {
                   NSApplication.shared.terminate(nil)
               }
               .keyboardShortcut("q", modifiers: .command)
           }
           Settings {
               Text("Jitouch Settings")
                   .frame(width: 600, height: 400)
           }
       }
   }
   ```

5. 验证: 项目能编译运行，菜单栏显示图标，点击可看到菜单和空设置窗口。
```

### Task 1.2 — 创建 MultitouchSupport C 头文件

```
创建 MultitouchSupport.h 和 PrivateAPIs.h，仅做类型和函数声明，无需任何 .m 实现文件。
Swift 将通过 Bridging Header 直接调用这些 C 函数。

参考旧代码: jitouch/Jitouch/Gesture.h 第74-116行的类型定义。

1. 创建 JitouchApp/PrivateAPI/MultitouchSupport.h:

   ```c
   #ifndef MultitouchSupport_h
   #define MultitouchSupport_h

   #include <CoreFoundation/CoreFoundation.h>

   // Opaque device reference
   typedef struct __MTDevice* MTDeviceRef;

   // Touch state
   typedef enum {
       MTTouchStateNotTracking = 0,
       MTTouchStateStartInRange = 1,
       MTTouchStateHoverInRange = 2,
       MTTouchStateMakeTouch = 3,
       MTTouchStateTouching = 4,
       MTTouchStateBreakTouch = 5,
       MTTouchStateLingerInRange = 6,
       MTTouchStateOutOfRange = 7
   } MTTouchState;

   // Vector and readout
   typedef struct { float x, y; } MTVector;
   typedef struct { MTVector pos; MTVector vel; } MTReadout;

   // Finger data (passed in callback)
   typedef struct {
       int frame;
       double timestamp;
       int identifier;
       MTTouchState state;
       int fingerId;
       int handId;
       MTReadout normalized;
       float size;
       int zero1;
       float angle;
       float majorAxis;
       float minorAxis;
       MTReadout mm;
       int zero2[2];
       float zDensity;
   } Finger;

   // Callback type
   typedef int (*MTContactCallbackFunction)(MTDeviceRef device,
                                             Finger *data,
                                             int nFingers,
                                             double timestamp,
                                             int frame);

   // Device functions
   CFMutableArrayRef MTDeviceCreateList(void);
   void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
   void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
   void MTDeviceStart(MTDeviceRef, int);  // 0 = default run loop mode
   void MTDeviceStop(MTDeviceRef);
   bool MTDeviceIsRunning(MTDeviceRef);
   void MTDeviceGetFamilyID(MTDeviceRef, int *familyID);

   // Weak import: not available on all OS versions
   void MTDeviceGetDeviceID(MTDeviceRef, uint64_t *deviceID)
       __attribute__((weak_import));

   #endif
   ```

2. 创建 JitouchApp/PrivateAPI/PrivateAPIs.h:

   ```c
   #ifndef PrivateAPIs_h
   #define PrivateAPIs_h

   #include <CoreFoundation/CoreFoundation.h>

   // Dock/Mission Control private API
   void CoreDockSendNotification(CFStringRef notification);

   #endif
   ```

3. 创建 JitouchApp/Jitouch-Bridging-Header.h:

   ```c
   #import "PrivateAPI/MultitouchSupport.h"
   #import "PrivateAPI/PrivateAPIs.h"
   ```

4. 验证 Swift 中可以访问这些类型:
   在 JitouchApp.swift 中临时添加测试代码:
   ```swift
   func testBridge() {
       let devices = MTDeviceCreateList() as! [MTDeviceRef]
       print("Found \(devices.count) multitouch devices")
   }
   ```
   编译通过即可（运行时测试需在真机上）。
```

---

## Phase 2: 核心引擎移植

### Task 2.1 — 触摸数据模型

```
创建纯 Swift 触摸数据模型，替代旧代码中的 C 结构体和全局变量。

参考旧代码:
- jitouch/Jitouch/Gesture.h: Finger 结构体
- jitouch/Jitouch/Gesture.m 第126-181行: 全局状态变量

创建 JitouchApp/Models/TouchModels.swift:

1. TouchPoint — 单个触摸点 (从 C Finger 转换而来):
   ```swift
   struct TouchPoint: Sendable {
       let id: Int               // Finger.identifier
       let state: TouchState
       let position: CGPoint     // normalized 0-1 (from Finger.normalized.pos)
       let velocity: CGVector    // from Finger.normalized.vel
       let size: Float
       let angle: Float
       let majorAxis: Float
       let minorAxis: Float
       let timestamp: Double

       /// 从 C Finger 结构体转换
       init(finger: Finger) { ... }
   }
   ```

2. TouchState 枚举 (映射 MTTouchState):
   ```swift
   enum TouchState: Int, Sendable {
       case notTracking = 0
       case startInRange = 1
       case hoverInRange = 2
       case makeTouch = 3
       case touching = 4
       case breakTouch = 5
       case lingerInRange = 6
       case outOfRange = 7

       var isActive: Bool { self == .touching || self == .makeTouch }
   }
   ```

3. TouchFrame — 一帧触摸数据:
   ```swift
   struct TouchFrame: Sendable {
       let touches: [TouchPoint]
       let timestamp: Double
       let deviceType: DeviceType

       var activeTouches: [TouchPoint] { touches.filter { $0.state.isActive } }
       var fingerCount: Int { activeTouches.count }
   }
   ```

4. DeviceType:
   ```swift
   enum DeviceType: Sendable {
       case trackpad
       case magicMouse
   }
   ```

5. GestureEvent — 识别器输出:
   ```swift
   enum GestureEvent: Sendable {
       case threeFingerTap
       case threeFingerSwipe(Direction)
       case fourFingerTap
       case fourFingerSwipe(Direction)
       case oneFixOneTap(Side)           // left/right
       case oneFixTwoSlide(Direction)
       case twoFixIndexDoubleTap
       case twoFixOneSlide(Direction)
       case threeFingerPinch(PinchDirection)
       case moveResize(MoveResizePhase)
       case tabSwitch(TabDirection)
       case characterRecognized(Character)
       // Magic Mouse specific
       case mmThreeFingerSwipe(Direction)
       case mmMiddleClick
       case mmVShapeMoveResize(MoveResizePhase)
   }

   enum Direction: Sendable { case left, right, up, down }
   enum Side: Sendable { case left, right }
   enum PinchDirection: Sendable { case inward, outward }
   enum TabDirection: Sendable { case pinkyToIndex, indexToPinky }
   enum MoveResizePhase: Sendable { case began, changed(dx: CGFloat, dy: CGFloat), ended }
   ```

所有类型必须是值类型 (struct/enum) 并符合 Sendable。
```

### Task 2.2 — 设备管理服务

```
创建 JitouchApp/Services/DeviceManager.swift，纯 Swift 实现多点触控设备管理。

参考旧代码:
- jitouch/Jitouch/Gesture.m 第2853-2926行: IOKit 设备通知
- jitouch/Jitouch/Gesture.m 第3180-3230行: startDevice/stopDevice
- jitouch/Jitouch/Gesture.m 第2795-2852行: 回调注册

通过 Bridging Header 直接调用 MultitouchSupport C 函数，无需 ObjC 包装。

1. DeviceManager (@Observable, @MainActor):

   ```swift
   @Observable
   @MainActor
   final class DeviceManager {
       private(set) var trackpadDevices: [MTDeviceRef] = []
       private(set) var magicMouseDevices: [MTDeviceRef] = []
       private(set) var isRunning = false

       // 触摸回调 (C 函数指针，使用 @convention(c))
       private var trackpadCallback: MTContactCallbackFunction?
       private var magicMouseCallback: MTContactCallbackFunction?

       func start(
           trackpadHandler: @escaping MTContactCallbackFunction,
           mouseHandler: @escaping MTContactCallbackFunction
       ) { ... }

       func stop() { ... }
   }
   ```

2. 设备发现和分类:
   - 调用 MTDeviceCreateList() 获取所有设备
   - 用 MTDeviceGetFamilyID() 分类:
     * familyID in [98,99,100,101,102,103]: 确定是 Trackpad
     * familyID == 128 或 129: 确定是 Magic Mouse
     * familyID == 112: 需要通过 IOKit IORegistryEntrySearchCFProperty
       查询 "Multitouch ID" 进一步区分 (Trackpad vs Mouse)
   - 直接用 Swift IOKit API: IOServiceGetMatchingServices, IORegistryEntrySearchCFProperty

3. 设备启动:
   - MTRegisterContactFrameCallback(device, callback)
   - MTDeviceStart(device, 0)
   - 回调函数必须是 @convention(c) 全局/静态函数
   - 在全局函数中通过 Unmanaged<DeviceManager> 或全局变量回调到 Swift

4. IOKit 热插拔监听:
   - IOServiceAddMatchingNotification 监听 "AppleMultitouchDevice"
   - 设备添加: 重新扫描并注册回调
   - 设备移除: 停止并清理
   - 添加重试机制: 设备插入后可能需要延迟才能启动 (Timer 重试 3 次，每次 1 秒)

5. 系统唤醒处理:
   - 监听 NSWorkspace.didWakeNotification
   - 唤醒后调用 stop() 再 start() 重新初始化所有设备

验证: 运行后能打印检测到的设备数量和类型。
```

### Task 2.3 — 手势识别引擎 (核心)

```
这是最核心也是最复杂的 Task。将 Gesture.m 中 4300+ 行手势识别逻辑移植为纯 Swift。
拆分为独立的识别器模块，每个遵循统一协议。

参考旧代码 jitouch/Jitouch/Gesture.m 全文:
- 第200-800行: trackpadCallback 触摸帧处理
- 第800-1400行: Trackpad 各手势状态机
- 第1400-2000行: Magic Mouse 各手势状态机
- 第2000-2600行: 字符识别算法
- 第2600-2800行: 命令分发 (doCommand)

### 文件结构:

1. Services/GestureEngine.swift — 主控制器
2. Services/Recognizers/GestureRecognizerProtocol.swift — 统一协议
3. Services/Recognizers/TrackpadTapRecognizer.swift — 三指/四指点击
4. Services/Recognizers/TrackpadSwipeRecognizer.swift — 三指/四指滑动
5. Services/Recognizers/FixFingerRecognizer.swift — 固定指+操作指组合手势
6. Services/Recognizers/PinchRecognizer.swift — 三指捏合
7. Services/Recognizers/MoveResizeRecognizer.swift — 移动/调整窗口大小
8. Services/Recognizers/TabSwitchRecognizer.swift — Tab 切换
9. Services/Recognizers/MagicMouseRecognizer.swift — Magic Mouse 手势
10. Services/Recognizers/CharacterRecognizer.swift — 字符绘制识别

### 统一协议:

```swift
protocol GestureRecognizer: AnyObject, Sendable {
    var isEnabled: Bool { get set }
    func processFrame(_ frame: TouchFrame) -> [GestureEvent]
    func reset()
}
```

### GestureEngine:

```swift
@Observable
final class GestureEngine {
    var onGestureEvent: ((GestureEvent) -> Void)?

    private var trackpadRecognizers: [GestureRecognizer] = []
    private var mouseRecognizers: [GestureRecognizer] = []

    init() {
        trackpadRecognizers = [
            TrackpadTapRecognizer(),
            TrackpadSwipeRecognizer(),
            FixFingerRecognizer(),
            PinchRecognizer(),
            MoveResizeRecognizer(),
            TabSwitchRecognizer(),
            CharacterRecognizer(deviceType: .trackpad),
        ]
        mouseRecognizers = [
            MagicMouseRecognizer(),
            CharacterRecognizer(deviceType: .magicMouse),
        ]
    }

    /// 由 DeviceManager 的 C 回调调用
    func handleTouchFrame(_ frame: TouchFrame) {
        let recognizers = frame.deviceType == .trackpad
            ? trackpadRecognizers : mouseRecognizers
        for recognizer in recognizers {
            guard recognizer.isEnabled else { continue }
            let events = recognizer.processFrame(frame)
            for event in events {
                onGestureEvent?(event)
            }
        }
    }
}
```

### 关键移植细节:

**手指数量追踪** (参考旧代码 trackpadNFingers 变量):
- 每帧统计 state == .touching 的手指数
- 手指数变化 (nFingers: 0→3, 3→0 等) 触发手势开始/结束

**时间窗口**:
- 使用 CACurrentMediaTime() (等同于 mach_absolute_time)
- 点击判定: 触摸持续时间 < clickSpeed 阈值
- 滑动判定: 移动距离 > sensitivity 阈值

**手指排序和识别** (参考旧代码 handed 逻辑):
- 按 x 坐标排序确定手指身份 (拇指在最左/右)
- 左手模式和右手模式影响排序方向
- "固定指" 判定: 位移 < 阈值的手指

**双指滑动抑制** (参考旧代码第2017-2022行):
- 自然滚动时两指间距 < 阈值，不触发手势
- 时间窗口: 两指事件后的短时间内不处理三指事件

**Move/Resize 模式** (参考旧代码 moveResizeFlag):
- 进入模式后通过 CGEventTap 拦截鼠标移动
- 根据 dx/dy 移动或调整窗口大小
- 需要与 EventTapManager 协作

**字符识别算法** (参考旧代码第2000-2600行):
- 记录手指轨迹点序列
- 计算相邻点之间的角度 (DegreeSpan)
- 与预定义字符模板匹配 (A-Z 各有 DegreeSpan 序列)
- 评分系统选择最佳匹配

每个识别器应可独立测试。先实现最常用的手势 (三指/四指滑动和点击)，
逐步添加其他手势类型。
```

### Task 2.4 — CGEventTap 事件拦截

```
创建 JitouchApp/Services/EventTapManager.swift，纯 Swift 实现 CGEventTap。

参考旧代码:
- jitouch/Jitouch/Gesture.m 第3152-3178行: CGEventTap 创建
- jitouch/Jitouch/Gesture.m 第2932-3150行: CGEventCallback
- jitouch/Jitouch/Gesture.m 第3040-3100行: 超时恢复

所有 CGEvent API 在 Swift 中都有原生绑定，无需 ObjC。

1. EventTapManager:

   ```swift
   @Observable
   @MainActor
   final class EventTapManager {
       private(set) var isRunning = false
       private var eventTap: CFMachPort?
       private var runLoopSource: CFRunLoopSource?

       var onMouseEvent: ((CGEvent, CGEventType) -> CGEvent?)?

       func start() throws {
           guard AXIsProcessTrusted() else {
               throw EventTapError.accessibilityNotGranted
           }

           let mask: CGEventMask =
               (1 << CGEventType.scrollWheel.rawValue) |
               (1 << CGEventType.mouseMoved.rawValue) |
               (1 << CGEventType.leftMouseDown.rawValue) |
               (1 << CGEventType.leftMouseUp.rawValue) |
               (1 << CGEventType.rightMouseDown.rawValue) |
               (1 << CGEventType.rightMouseUp.rawValue) |
               (1 << CGEventType.otherMouseDown.rawValue) |
               (1 << CGEventType.otherMouseUp.rawValue) |
               (1 << CGEventType.leftMouseDragged.rawValue)

           // 使用 CGEvent.tapCreate — Swift 原生 API
           eventTap = CGEvent.tapCreate(
               tap: .cgSessionEventTap,
               place: .headInsertEventTap,
               options: .defaultTap,
               eventsOfInterest: mask,
               callback: eventTapCallback,  // 全局 @convention(c) 函数
               userInfo: Unmanaged.passUnretained(self).toOpaque()
           )
           // 添加到 RunLoop ...
       }

       func stop() { ... }
   }
   ```

2. 事件回调 (全局 C 函数):
   ```swift
   private func eventTapCallback(
       proxy: CGEventTapProxy,
       type: CGEventType,
       event: CGEvent,
       userInfo: UnsafeMutableRawPointer?
   ) -> Unmanaged<CGEvent>? {
       // 处理 tapDisabledByTimeout: 重新启用
       if type == .tapDisabledByTimeout {
           CGEvent.tapEnable(tap: machPort, enable: true)
           return Unmanaged.passRetained(event)
       }
       // 转发给 EventTapManager.onMouseEvent
       let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo!).takeUnretainedValue()
       if let result = manager.onMouseEvent?(event, type) {
           return Unmanaged.passRetained(result)
       }
       return Unmanaged.passRetained(event)
   }
   ```

3. 事件处理逻辑 (由 GestureEngine 设置 onMouseEvent):
   - 自动滚动模式: 修改 scrollWheel 事件的方向
   - Move/Resize 模式: 拦截 mouseMoved 并移动/调整窗口
   - 手势进行中: 吞掉 mouseDown/Up 防止误触发点击
   - 正常模式: 透传所有事件

4. 可靠性:
   - tapDisabledByTimeout: 检测后自动 CGEvent.tapEnable
   - 如果重新启用失败，重建整个 eventTap (参考旧代码的定时器重建机制)
   - 使用 os.Logger 记录 tap 禁用/恢复事件

5. 权限管理:
   - start() 前检查 AXIsProcessTrusted()
   - 未授权时抛出明确错误
   - 提供 requestAccessibility() 调用 AXIsProcessTrustedWithOptions

验证: 启动后能拦截鼠标事件并打印日志，不影响正常鼠标操作。
```

---

## Phase 3: 命令执行系统

### Task 3.1 — 命令模型和执行器

```
创建命令系统，纯 Swift 实现所有手势动作。

参考旧代码:
- jitouch/Jitouch/Gesture.m 第636-793行: doCommand() 所有命令
- jitouch/Jitouch/KeyUtility.m: 键盘模拟
- jitouch/Jitouch/Settings.m: 手势→命令映射

### 1. Models/GestureCommand.swift — 命令定义

```swift
enum CommandType: String, Codable, Sendable, CaseIterable {
    // 窗口操作
    case maximize, restore, fullscreen, minimize
    case close, zoom, moveToNextScreen
    case leftHalf, rightHalf, topHalf, bottomHalf  // 新增: 窗口分屏

    // 导航
    case browserBack, browserForward
    case nextTab, previousTab, newTab, closeTab, reopenTab

    // 系统
    case missionControl, showDesktop, appExpose
    case launchpad, spacesLeft, spacesRight
    case notificationCenter  // 新增

    // 应用
    case appSwitcher, quitApp, hideApp

    // 鼠标
    case middleClick, autoScroll

    // 自定义
    case keystroke  // 需要附带 keyCode + modifiers
    case none       // 禁用

    var displayName: String { ... }
    var category: CommandCategory { ... }
}

enum CommandCategory: String, CaseIterable {
    case window = "窗口"
    case navigation = "导航"
    case system = "系统"
    case app = "应用"
    case mouse = "鼠标"
    case custom = "自定义"
}

struct GestureBinding: Codable, Sendable, Identifiable {
    let id: UUID
    var gestureEvent: String     // GestureEvent 的序列化 key
    var command: CommandType
    var keyCode: Int?            // 仅 keystroke 命令
    var modifierFlags: Int?      // 仅 keystroke 命令
    var isEnabled: Bool
}
```

### 2. Services/CommandExecutor.swift — 命令执行

```swift
@MainActor
final class CommandExecutor {
    func execute(_ command: CommandType, binding: GestureBinding?) async {
        switch command {
        case .maximize: await maximizeWindow()
        case .fullscreen: await toggleFullscreen()
        case .minimize: await minimizeWindow()
        case .close: await closeWindow()
        case .browserBack: simulateKeystroke(keyCode: 0x7B, cmd: true)  // Cmd+[
        case .browserForward: simulateKeystroke(keyCode: 0x7C, cmd: true)
        case .nextTab: simulateKeystroke(keyCode: 0x09, ctrl: true)  // Ctrl+Tab
        case .missionControl: triggerMissionControl()
        case .showDesktop: triggerShowDesktop()
        case .keystroke:
            if let kc = binding?.keyCode, let mf = binding?.modifierFlags {
                simulateKeystroke(keyCode: kc, rawModifiers: mf)
            }
        // ... 其他命令
        }
    }
}
```

### 3. Services/KeySimulator.swift — 键盘模拟 (纯 Swift)

替代旧的 KeyUtility.m，使用 Swift CGEvent API:
```swift
func simulateKeystroke(keyCode: Int, shift: Bool = false, ctrl: Bool = false,
                       alt: Bool = false, cmd: Bool = false) {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source,
                          virtualKey: CGKeyCode(keyCode), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source,
                        virtualKey: CGKeyCode(keyCode), keyDown: false)
    var flags: CGEventFlags = []
    if shift { flags.insert(.maskShift) }
    if ctrl { flags.insert(.maskControl) }
    if alt { flags.insert(.maskAlternate) }
    if cmd { flags.insert(.maskCommand) }
    keyDown?.flags = flags
    keyUp?.flags = flags
    keyDown?.post(tap: .cgSessionEventTap)
    keyUp?.post(tap: .cgSessionEventTap)
}

// 特殊键 (媒体控制) — 使用 NSEvent
func simulateSpecialKey(_ keyType: Int) {
    // NX_KEYTYPE_PLAY, NX_KEYTYPE_NEXT 等
    // 使用 NSEvent.otherEvent(with: .systemDefined, ...) 并 CGEvent.post
}
```

### 4. Services/AccessibilityHelper.swift — 窗口操作 (纯 Swift AXUIElement)

```swift
@MainActor
final class AccessibilityHelper {
    static func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard let app = focusedApp else { return nil }
        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        return focusedWindow as! AXUIElement?
    }

    static func setWindowPosition(_ window: AXUIElement, _ point: CGPoint) { ... }
    static func setWindowSize(_ window: AXUIElement, _ size: CGSize) { ... }
    static func maximizeWindow(_ window: AXUIElement) { ... }
    static func pressButton(_ window: AXUIElement, attribute: String) { ... }
}
```

### 5. 系统命令:
- Mission Control: CoreDockSendNotification("com.apple.expose.awake" as CFString)
  (通过 PrivateAPIs.h 声明，Swift 直接调用)
- Show Desktop: CoreDockSendNotification("com.apple.expose.front.awake" as CFString)
- Launchpad: CoreDockSendNotification("com.apple.launchpad.toggle" as CFString)
- Spaces Left/Right: 模拟 Ctrl+←/→ 按键

验证: 能独立测试每个命令 (手动调用 execute)。
```

### Task 3.2 — 设置管理系统

```
创建纯 Swift 设置管理，使用 @Observable + Codable + UserDefaults。

参考旧代码:
- jitouch/Jitouch/Settings.m: CFPreferences 读写
- jitouch/Jitouch/Settings.h: 设置键名

### 1. Models/AppSettings.swift:

```swift
@Observable
final class AppSettings: Codable {
    // 通用
    var isEnabled: Bool = true
    var clickSpeed: Double = 0.5     // 0.0 (快) - 1.0 (慢)
    var sensitivity: Double = 0.5    // 0.0 (低) - 1.0 (高)
    var showMenuBarIcon: Bool = true
    var launchAtLogin: Bool = false

    // 触控板
    var trackpadEnabled: Bool = true
    var trackpadLeftHanded: Bool = false
    var trackpadBindings: [GestureBinding] = GestureBinding.defaultTrackpadBindings
    var trackpadAppBindings: [String: [GestureBinding]] = [:]  // bundleID → bindings

    // Magic Mouse
    var magicMouseEnabled: Bool = true
    var magicMouseLeftHanded: Bool = false
    var magicMouseBindings: [GestureBinding] = GestureBinding.defaultMouseBindings
    var magicMouseAppBindings: [String: [GestureBinding]] = [:]

    // 字符识别
    var charRecognitionTrackpad: Bool = false
    var charRecognitionMouse: Bool = false
    var charRecognitionBindings: [GestureBinding] = []
}
```

### 2. Services/SettingsManager.swift:

```swift
@Observable
@MainActor
final class SettingsManager {
    private(set) var settings: AppSettings

    private let defaults = UserDefaults(suiteName: "com.jitouch.Jitouch")!
    private let storageKey = "AppSettings_v3"

    init() {
        // 尝试加载已保存设置，否则尝试迁移旧版本，否则使用默认值
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            settings = Self.migrateFromLegacy() ?? AppSettings()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// 从旧版 CFPreferences 数据迁移
    private static func migrateFromLegacy() -> AppSettings? {
        let oldDefaults = UserDefaults(suiteName: "com.jitouch.Jitouch")!
        guard oldDefaults.bool(forKey: "enAll") != false ||
              oldDefaults.object(forKey: "enAll") != nil else { return nil }
        // 读取旧键值并转换为新格式...
        let settings = AppSettings()
        settings.isEnabled = oldDefaults.bool(forKey: "enAll")
        settings.clickSpeed = oldDefaults.double(forKey: "ClickSpeed")
        settings.sensitivity = oldDefaults.double(forKey: "Sensitivity")
        settings.trackpadEnabled = oldDefaults.bool(forKey: "enTPAll")
        settings.trackpadLeftHanded = oldDefaults.bool(forKey: "Handed")
        settings.magicMouseEnabled = oldDefaults.bool(forKey: "enMMAll")
        settings.magicMouseLeftHanded = oldDefaults.bool(forKey: "MMHanded")
        // ... 迁移手势绑定映射 (trackpadMap, magicMouseMap, recognitionMap)
        return settings
    }

    /// 查找手势对应的命令
    func command(for gesture: GestureEvent, app bundleID: String?) -> CommandType {
        // 1. 先查 app 特定绑定
        // 2. 再查全局绑定
        // 3. 未找到返回 .none
    }
}
```

### 3. Launch at Login:

```swift
import ServiceManagement

extension SettingsManager {
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = enabled
            save()
        } catch {
            // 处理错误
        }
    }
}
```

### 4. 默认绑定:

```swift
extension GestureBinding {
    static let defaultTrackpadBindings: [GestureBinding] = [
        .init(gesture: "threeFingerTap", command: .middleClick),
        .init(gesture: "threeFingerSwipeLeft", command: .browserBack),
        .init(gesture: "threeFingerSwipeRight", command: .browserForward),
        .init(gesture: "threeFingerSwipeUp", command: .missionControl),
        .init(gesture: "threeFingerSwipeDown", command: .appExpose),
        .init(gesture: "fourFingerTap", command: .showDesktop),
        .init(gesture: "fourFingerSwipeLeft", command: .spacesRight),
        .init(gesture: "fourFingerSwipeRight", command: .spacesLeft),
        // ...
    ]
}
```

验证: 设置能保存和恢复，旧版数据能迁移。
```

---

## Phase 4: SwiftUI 用户界面

### Task 4.1 — 菜单栏和设置主框架

```
创建完整的 SwiftUI 菜单栏应用和设置窗口框架。

### 1. 更新 App/JitouchApp.swift:

```swift
@main
struct JitouchApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(appState.isEnabled ? "MenuBarIcon" : "MenuBarIconOff")
                .renderingMode(.template)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
```

### 2. App/AppState.swift — 全局状态:

```swift
@Observable
@MainActor
final class AppState {
    let settingsManager = SettingsManager()
    let deviceManager = DeviceManager()
    let gestureEngine = GestureEngine()
    let eventTapManager = EventTapManager()
    let commandExecutor = CommandExecutor()
    let permissionManager = PermissionManager()

    var isEnabled: Bool { settingsManager.settings.isEnabled }
    var hasPermission: Bool { permissionManager.hasAccessibilityPermission }

    func startup() async { ... }  // 初始化流程
    func shutdown() { ... }
    func toggle() { ... }         // 开/关切换
}
```

### 3. Views/MenuBarView.swift:

```swift
struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        Toggle(appState.isEnabled ? "Jitouch is On" : "Jitouch is Off",
               isOn: $appState.settingsManager.settings.isEnabled)
        Divider()
        // 连接状态
        if !appState.deviceManager.trackpadDevices.isEmpty {
            Label("Trackpad Connected", systemImage: "hand.point.up.fill")
        }
        if !appState.deviceManager.magicMouseDevices.isEmpty {
            Label("Magic Mouse Connected", systemImage: "magicmouse.fill")
        }
        Divider()
        SettingsLink { Text("Settings...") }
            .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit Jitouch") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
```

### 4. Views/SettingsView.swift:

```swift
struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView(settings: appState.settingsManager)
                .tabItem { Label("General", systemImage: "gear") }
            TrackpadSettingsView(settings: appState.settingsManager)
                .tabItem { Label("Trackpad", systemImage: "hand.point.up") }
            MagicMouseSettingsView(settings: appState.settingsManager)
                .tabItem { Label("Magic Mouse", systemImage: "magicmouse") }
            CharacterSettingsView(settings: appState.settingsManager)
                .tabItem { Label("Characters", systemImage: "pencil.line") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 650, height: 500)
    }
}
```

### 5. Views/GeneralSettingsView.swift:

- 总开关、灵敏度滑块、点击速度滑块
- Launch at Login 开关
- 菜单栏图标显示/隐藏
- 辅助功能权限状态 + 授权按钮

### 6. Views/AboutView.swift:

- App 图标和版本号
- 原作者致谢
- GPL v3 许可证信息
- GitHub 仓库链接

验证: 菜单栏图标 + 菜单 + 设置窗口 (含5个Tab) 能正常显示。
```

### Task 4.2 — 手势配置界面

```
创建触控板、Magic Mouse、字符识别的详细配置界面。

### 1. Views/TrackpadSettingsView.swift:

```swift
struct TrackpadSettingsView: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Enable Trackpad Gestures", isOn: $settings.settings.trackpadEnabled)
                Picker("Hand Mode", selection: $settings.settings.trackpadLeftHanded) {
                    Text("Right-handed").tag(false)
                    Text("Left-handed").tag(true)
                }
            }

            Section("Three-Finger Gestures") {
                GestureBindingRow(name: "Three-Finger Tap", key: "threeFingerTap",
                                  bindings: $settings.settings.trackpadBindings)
                GestureBindingRow(name: "Swipe Left", key: "threeFingerSwipeLeft", ...)
                GestureBindingRow(name: "Swipe Right", key: "threeFingerSwipeRight", ...)
                GestureBindingRow(name: "Swipe Up", key: "threeFingerSwipeUp", ...)
                GestureBindingRow(name: "Swipe Down", key: "threeFingerSwipeDown", ...)
            }

            Section("Four-Finger Gestures") { ... }
            Section("Combination Gestures") { ... }
            Section("Move & Resize") { ... }

            Section("App-Specific") {
                AppSpecificBindingsEditor(bindings: $settings.settings.trackpadAppBindings)
            }
        }
    }
}
```

### 2. Views/Components/GestureBindingRow.swift:

```swift
struct GestureBindingRow: View {
    let name: String
    let key: String
    @Binding var bindings: [GestureBinding]

    var body: some View {
        HStack {
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
            Text(name)
            Spacer()
            CommandPicker(selection: commandBinding)
        }
    }
}
```

### 3. Views/Components/CommandPicker.swift:

分类命令选择器，按 CommandCategory 分组:
```swift
struct CommandPicker: View {
    @Binding var selection: CommandType

    var body: some View {
        Picker("Action", selection: $selection) {
            ForEach(CommandCategory.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(CommandType.allCases.filter { $0.category == category }) { cmd in
                        Text(cmd.displayName).tag(cmd)
                    }
                }
            }
        }
        .frame(width: 200)
    }
}
```

### 4. Views/Components/KeyboardShortcutRecorder.swift:

自定义快捷键录制器 (用于 keystroke 命令):
- 点击后进入录制模式
- 监听 NSEvent.addLocalMonitorForEvents 捕获按键
- 显示录制的快捷键组合 (如 "⌘⇧K")
- 使用 NSEvent 原生 API，纯 Swift

### 5. Views/Components/AppSpecificBindingsEditor.swift:

- 左侧: 应用列表 (NSOpenPanel 添加 .app)
- 右侧: 该应用的手势绑定覆盖
- 显示应用图标和名称

### 6. MagicMouseSettingsView.swift 和 CharacterSettingsView.swift:
- 结构类似 TrackpadSettingsView
- 手势类型不同

验证: 所有设置页面能正常显示和交互，修改后设置能自动保存。
```

### Task 4.3 — 辅助功能权限引导

```
创建权限检查和首次启动引导。

### 1. Services/PermissionManager.swift:

```swift
@Observable
@MainActor
final class PermissionManager {
    private(set) var hasAccessibilityPermission = false
    private var checkTimer: Timer?

    init() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func startPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let trusted = AXIsProcessTrusted()
                if trusted != self?.hasAccessibilityPermission {
                    self?.hasAccessibilityPermission = trusted
                    if trusted { self?.checkTimer?.invalidate() }
                }
            }
        }
    }
}
```

### 2. Views/OnboardingView.swift:

首次启动时显示的引导窗口:
- Step 1: 欢迎页，简要介绍 Jitouch
- Step 2: 辅助功能权限请求
  - 大按钮 "Grant Accessibility Permission"
  - 权限授予后自动切换到下一步
  - 动画显示设置步骤截图
- Step 3: 快速配置 (选择 Trackpad / Magic Mouse)
- Step 4: 完成，显示常用手势

使用 @AppStorage("hasCompletedOnboarding") 记录是否完成过引导。

### 3. Views/AccessibilityBanner.swift:

设置页面顶部的权限提示横幅:
```swift
struct AccessibilityBanner: View {
    @Bindable var permission: PermissionManager

    var body: some View {
        if !permission.hasAccessibilityPermission {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Accessibility permission required")
                Spacer()
                Button("Grant Access") { permission.requestPermission() }
            }
            .padding()
            .background(.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

### 4. Launch at Login (SMAppService):

```swift
import ServiceManagement

func updateLaunchAtLogin(_ enabled: Bool) throws {
    if enabled {
        try SMAppService.mainApp.register()
    } else {
        try SMAppService.mainApp.unregister()
    }
}
```

验证: 首次运行显示引导流程，权限授予后自动检测，设置页面显示权限状态。
```

---

## Phase 5: 视觉反馈系统

### Task 5.1 — 手势视觉反馈

```
创建手势视觉反馈 overlay，纯 Swift + SwiftUI。

参考旧代码:
- jitouch/Jitouch/CursorView.m / CursorWindow.m
- jitouch/Jitouch/GestureView.m / GestureWindow.m

### 1. Views/Overlay/OverlayPanel.swift:

```swift
final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: NSScreen.main!.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
```

### 2. Views/Overlay/CursorOverlayView.swift:

Move/Resize/Tab 操作时的光标反馈:
```swift
struct CursorOverlayView: View {
    let cursorType: CursorType  // .move, .resize, .tab
    let position: CGPoint

    var body: some View {
        Image(systemName: cursorType.sfSymbol)
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.7))
            .clipShape(Circle())
            .position(position)
    }
}

enum CursorType {
    case move, resize, tab
    var sfSymbol: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .tab: return "rectangle.stack"
        }
    }
}
```

### 3. Views/Overlay/GestureDrawingView.swift:

字符识别时的手指轨迹绘制:
```swift
struct GestureDrawingView: View {
    let points: [CGPoint]
    let recognizedCharacter: String?

    var body: some View {
        ZStack {
            // 半透明背景
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)

            // 轨迹路径
            Canvas { context, size in
                guard points.count >= 2 else { return }
                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.blue),
                              style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 180, height: 180)

            // 识别结果
            if let char = recognizedCharacter {
                Text(char)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
```

### 4. Services/OverlayManager.swift:

```swift
@Observable
@MainActor
final class OverlayManager {
    private var panel: OverlayPanel?
    private(set) var cursorType: CursorType?
    private(set) var cursorPosition: CGPoint = .zero
    private(set) var drawingPoints: [CGPoint] = []
    private(set) var recognizedCharacter: String?

    func showCursor(_ type: CursorType, at position: CGPoint) {
        cursorType = type
        cursorPosition = position
        showPanel()
    }

    func updateCursorPosition(_ position: CGPoint) {
        cursorPosition = position
    }

    func showDrawing(points: [CGPoint]) {
        drawingPoints = points
        showPanel()
    }

    func showRecognizedCharacter(_ char: String) {
        recognizedCharacter = char
        // 1.5 秒后自动隐藏
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            hideAll()
        }
    }

    func hideAll() {
        cursorType = nil
        drawingPoints = []
        recognizedCharacter = nil
        panel?.orderOut(nil)
    }

    private func showPanel() {
        if panel == nil { panel = OverlayPanel() }
        // 更新 panel contentView 为 NSHostingView(rootView: overlayContent)
        panel?.orderFrontRegardless()
    }
}
```

验证: 手动调用 showCursor/showDrawing 能在屏幕上显示半透明覆盖。
使用 SF Symbols 确保所有图标在 Retina 下清晰。
```

---

## Phase 6: 集成和收尾

### Task 6.1 — 端到端集成

```
将所有模块组装并处理启动流程、错误恢复、性能优化。

### 1. 启动流程 (AppState.startup):

```swift
@MainActor
func startup() async {
    // 1. 检查权限
    permissionManager.startPolling()
    guard permissionManager.hasAccessibilityPermission else {
        // 显示 onboarding
        return
    }

    // 2. 加载设置
    // (SettingsManager 在 init 中已加载)

    // 3. 设置手势引擎
    gestureEngine.onGestureEvent = { [weak self] event in
        guard let self else { return }
        let command = self.settingsManager.command(for: event, app: currentAppBundleID())
        Task { await self.commandExecutor.execute(command) }
    }

    // 4. 启动设备管理
    deviceManager.start(
        trackpadHandler: makeTrackpadCallback(),
        mouseHandler: makeMagicMouseCallback()
    )

    // 5. 启动事件拦截
    try? eventTapManager.start()
    eventTapManager.onMouseEvent = { [weak self] event, type in
        self?.gestureEngine.handleMouseEvent(event, type: type)
    }

    // 6. 监听系统事件
    setupSystemNotifications()
}
```

### 2. C 回调到 Swift 的桥接:

```swift
/// 全局 C 回调函数 → 调用 GestureEngine
private func makeTrackpadCallback() -> MTContactCallbackFunction {
    return { device, data, nFingers, timestamp, frame in
        guard let data else { return 0 }
        let touches = (0..<nFingers).map { TouchPoint(finger: data[$0]) }
        let frame = TouchFrame(touches: touches, timestamp: timestamp, deviceType: .trackpad)
        // 通过全局 AppState 引用回调
        Task { @MainActor in
            AppState.shared.gestureEngine.handleTouchFrame(frame)
        }
        return 0
    }
}
```

### 3. 错误恢复:
- EventTap 超时: tapDisabledByTimeout → 自动重启 (已在 EventTapManager 中实现)
- 设备断开: IOKit 通知 → DeviceManager 自动清理和重连
- 权限撤销: PermissionManager 轮询检测 → 停止引擎 + 显示提示
- 系统唤醒: didWakeNotification → 重新初始化设备

### 4. 日志:
```swift
import os

extension Logger {
    static let gesture = Logger(subsystem: "com.jitouch.Jitouch", category: "Gesture")
    static let device = Logger(subsystem: "com.jitouch.Jitouch", category: "Device")
    static let eventTap = Logger(subsystem: "com.jitouch.Jitouch", category: "EventTap")
    static let command = Logger(subsystem: "com.jitouch.Jitouch", category: "Command")
}
```

### 5. 性能:
- 触摸回调: 直接在回调线程处理手势状态机，仅在需要 UI 更新时 dispatch 到主线程
- 避免在热路径中使用 String 拼接或 Array append
- 使用 signpost 标记关键路径耗时

### 6. SIGHUP 重载:
```swift
func setupSignalHandler() {
    let source = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
    source.setEventHandler { [weak self] in
        Logger.gesture.info("Received SIGHUP, reloading...")
        Task { @MainActor in
            self?.shutdown()
            await self?.startup()
        }
    }
    source.resume()
    signal(SIGHUP, SIG_IGN)
}
```

验证: 完整启动→识别手势→执行命令 的端到端流程。
```

### Task 6.2 — 清理和收尾

```
完成所有功能移植后执行最终清理。

### 1. 删除旧 ObjC 代码:
   rm -rf jitouch/

### 2. 更新 README.md:

# Jitouch

Magic Trackpad and Magic Mouse gesture enhancer for macOS.

## Features
- Custom multi-touch gestures for Trackpad and Magic Mouse
- Three/four finger taps, swipes, pinches
- Character recognition (draw letters to trigger actions)
- Window move, resize, and snap
- Per-application gesture customization
- Native SwiftUI settings interface

## Requirements
- macOS 15.0 or later
- Accessibility permission required

## Installation
Download the latest release from GitHub Releases.

## Building
- Xcode 16+
- Swift 6
- `xcodebuild -project Jitouch.xcodeproj -scheme Jitouch build`

## License
GPL v3 — see [LICENSE](LICENSE)

## Credits
Originally created by Supasorn Suwajanakorn and Sukolsak Sakshuwong.
Maintained by Aaron Kollasch. Modernized Swift rewrite by lusheng.

### 3. 创建 CHANGELOG.md:

## [3.0.0] — 2026-xx-xx
### Changed
- Complete rewrite in pure Swift (from Objective-C)
- New SwiftUI settings interface (replaces System Preferences pane)
- Standalone menu bar app (no more prefPane installation)
- Retina display support with SF Symbols
- Minimum macOS 15.0 (supports up to macOS 26 Tahoe)
- Modern Swift concurrency (async/await, @Observable)
- Launch at Login via SMAppService

### Added
- Window snapping (left/right/top/bottom half)
- Notification Center gesture
- First-run onboarding with accessibility permission guide

### Removed
- System Preferences pane (replaced by standalone app)
- Legacy macOS support (< 15.0)

### 4. 更新 .gitignore (如需要)

### 5. 全面测试:
- [ ] macOS 15 测试
- [ ] macOS 26 (Tahoe) 测试
- [ ] Trackpad: 三指/四指 点击和滑动
- [ ] Trackpad: 组合手势 (固定指+操作指)
- [ ] Trackpad: Move/Resize
- [ ] Trackpad: 字符识别
- [ ] Magic Mouse: 所有手势
- [ ] 设备热插拔
- [ ] 权限授予/撤销流程
- [ ] 设置保存/恢复
- [ ] 旧版设置迁移
- [ ] Launch at Login
- [ ] 系统唤醒恢复
- [ ] 视觉反馈 overlay
- [ ] 多显示器
```

---

## 执行顺序和依赖关系

```
1.1 项目结构 → 1.2 C 头文件 → 2.1 触摸模型 → 2.2 设备管理 → 2.3 手势引擎 → 2.4 事件拦截
                                                                        ↓
                                    3.2 设置管理 ← 3.1 命令执行器 ←──────┘
                                         ↓
                           4.1 菜单栏框架 → 4.2 配置界面 → 4.3 权限引导
                                                              ↓
                                                   5.1 视觉反馈 → 6.1 集成 → 6.2 收尾
```

每个 Task 完成后必须验证编译通过。建议 Task 2.3 (手势引擎) 按手势类型逐个迭代:
先实现三指滑动/点击 → 四指手势 → 组合手势 → Move/Resize → 字符识别。
