# Orbit（果汁风格）位置社交 App

一款用 **SwiftUI（iOS 16）** 实现的、功能参照 Zenly 的实时位置社交 App。
核心体验：在地图上实时看到好友的头像气泡、位置、移动状态与电量，并能添加好友、聊天、自定义卡通头像。

> 数据层采用「**后端服务协议 + Mock 实现**」：现在用内置假数据即可离线编译运行、看到完整效果；
> 将来接入真实服务器时，只改一处开关即可，UI 代码零改动。

---

## ✨ 功能清单（对应 Orbit）

| 模块 | 功能 |
|------|------|
| 🗺️ 地图主页 | 全屏地图、好友头像气泡、自己的位置、移动状态描边、低电量红点、隐身标记；底部好友横滑栏；点击好友弹出详情卡（距离 / 电量 / 速度 / 小地图 / 聊天·戳一下·关注）；好友位置每 3 秒模拟实时移动 |
| 👥 好友管理 | 好友列表（关注置顶 + 全部）、搜索、左滑关注 / 右滑删除、邀请码、通过邀请码添加好友 |
| 💬 聊天 | 会话列表 + 未读角标、一对一聊天、文本 / 位置 / 「戳一下」三种气泡、发送后好友自动回复（演示用） |
| 🙂 个人资料 | 个人主页、足迹、隐身开关、退出登录；**纯代码绘制的卡通头像编辑器**（肤色 / 发型 / 发色 / 配饰 / 背景，实时预览） |

---

## 🏗️ 技术架构

```
SwiftUI 视图  ──观察──▶  SessionStore（@MainActor 状态中枢）
                              │ 只依赖
                              ▼
                       BackendService（协议 / 契约）
                          ┌────────┴─────────┐
                   MockBackendService   LiveBackendService
                   （内置假数据+模拟流）   （真实 REST/WebSocket 骨架）
```

- **MVVM + 服务协议层**：视图只观察 `SessionStore`，所有后端调用都走 `BackendService` 协议。
- **实时数据**用 `AsyncStream` 推送（好友位置、聊天消息），对应真实实现里的 WebSocket / SSE / Firebase 监听。
- **`@MainActor` 全程主线程**：SwiftUI 状态更新无需切线程，天然无数据竞争。
- **定位**：`LocationManager` 封装 CoreLocation；无定位时回退到默认坐标，保证地图始终有内容。
- **头像**：`AvatarView` 完全用 SwiftUI 形状绘制，矢量、可缩放、无图片素材。

### 目录结构
```
Orbit/
├── App/            OrbitApp(@main)、RootView、AppEnvironment(后端开关)
├── Theme/          配色、渐变、卡片样式
├── Models/         Geo / User / Avatar / Friend / Chat / Place
├── Services/       BackendService(协议) / Mock / Live / SampleData / LocationManager / SessionStore
├── Components/     AvatarView / StatusBadges / FriendMapBubble
├── Features/       Onboarding / Map / Friends / Chat / Profile
└── Resources/      Info.plist、Assets.xcassets（含生成的 App 图标）
Scripts/
├── generate_xcodeproj.py   离线生成 .xcodeproj（无需 xcodegen）
└── make_icon.py            生成渐变定位针 App 图标
```

---

## 🚀 构建与运行

> 已在 **Xcode 14.2 / iOS 16.2 模拟器** 上验证：编译 0 错误、运行正常。

```bash
# 1) 生成 Xcode 工程（新增/删除源文件后重跑即可）
python3 Scripts/generate_xcodeproj.py

# 2a) 用 Xcode 打开（推荐）
open Orbit.xcodeproj          # 选 iPhone 模拟器，Cmd+R 运行

# 2b) 或命令行编译
xcodebuild -project Orbit.xcodeproj -scheme Orbit \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.2' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

登录页输入任意手机号 + **任意 4 位以上验证码**即可进入。

### 演示 / UI 测试自动登录
设环境变量 `JAGAT_AUTOLOGIN=1` 可跳过登录直达主界面：
```bash
SIMCTL_CHILD_JAGAT_AUTOLOGIN=1 xcrun simctl launch booted com.example.jagat
# 让示例好友与你同处一地，便于查看地图：
xcrun simctl location booted set 39.9042,116.4074
```

---

## 🔌 接入真实后端

后端来源由 `Orbit/App/AppEnvironment.swift` 里的 `backendKind` 一处开关决定，
三选一，**UI 与业务代码无需任何改动**：

```swift
static let backendKind: BackendKind = .mock   // .mock / .firebase / .rest
```

- **`.firebase`** —— Firebase Auth + Firestore 实时位置/聊天。实现见
  `Orbit/Services/FirebaseBackendService.swift`，接入步骤见 **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)**
  （需 `ENABLE_FIREBASE=1` 重新生成工程以注入 SwiftPM 依赖）。
- **`.rest`** —— 自定义 REST/WebSocket 后端。在 `Orbit/Services/LiveBackendService.swift`
  中按各方法上标注的接入点填好请求与实时通道即可。
- **`.mock`** —— 本地假数据（默认，离线可跑）。

---

## 📝 说明与可扩展点

- 当前为离线 Mock 演示：好友移动、聊天回复均为本地模拟。
- 可继续扩展：真实推送、好友请求审批、群组、位置历史轨迹回放、地图聚合（marker clustering）、深色地图样式等。
- Bundle ID：`com.example.jagat`；最低系统：iOS 16.0。
