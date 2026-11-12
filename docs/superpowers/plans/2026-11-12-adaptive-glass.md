# Orbit 新系统界面与自适应布局

目标：保留 iOS 16 部署下限，在 iOS 26 及以后使用原生 Liquid Glass，整理地图、消息、聊天和个人页，并验证 iOS 27.1 iPhone Duo。

用户已确认：保留 iOS 16，新系统增强。实现沿用 SwiftUI、现有业务服务与品牌颜色。

## 实施顺序

- [x] 为窗口布局决策添加可运行的边界测试，覆盖窄屏、宽屏、横屏短窗口、大字体、窗口尺寸变化。
- [x] 在 OrbitUI 增加独立布局策略与玻璃修饰器；iOS 16–25 回退系统材质，降低透明度时使用实色。
- [x] 整理 MainTabView：依据当前容器布局，移除 UIScreen.main；导航栏采用安全区插入；宽屏地图与消息/个人页并排；变化窗口大小不重建面板内容。
- [x] 地图控件使用公共玻璃效果和安全区布局；消息搜索栏改为原生安全区插入；聊天表情横向滚动；个人页限制阅读宽度。
- [x] 开放手机横屏；保留所有部署版本设置；分别用 Xcode 26.6 / 27.1 构建。
- [ ] 在模拟器检查手机、Duo、消息、个人页、键盘、大字体与低透明度；复核差异并记录实际验证限制。

## 验收

布局测试运行：`swiftc Packages/OrbitUI/Sources/OrbitUI/AdaptiveLayout.swift Scripts/Tests/AdaptiveLayoutTests.swift -o /tmp/orbit-layout-tests && /tmp/orbit-layout-tests`。
构建：`DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer xcodebuild -project Orbit.xcodeproj -scheme Orbit -sdk iphonesimulator -derivedDataPath /tmp/orbit-ios27-build CODE_SIGNING_ALLOWED=NO build`。

宽屏至少保留 360pt 地图，侧面板 320–420pt；高度不足 500pt 或辅助功能字号时采用单列；消息面板不超过容器高度。
不依赖机型字符串或杜撰设备尺寸；使用真实模拟器窗口与安全区。不得把 iOS 16 编译兼容等同于 iOS 16 真机运行验证。
本轮不自动提交、推送，不处理已有 Xcode 个人状态或 backend/dist。

## 实际验证记录

- 285 组窗口尺寸及手机、宽屏、短横屏、辅助功能字号场景的布局策略检查通过。
- Xcode 27.1 / iOS 27.1 SDK 与 Xcode 26.6 / iOS 26.5 SDK 最终构建均为 BUILD SUCCEEDED，保持 iOS 16 部署目标。
- Info.plist 校验、git diff --check 通过。
- 独立代码复核发现地图侧栏隐身人数标签在 56pt 列中被挤压，已简化为图标加人数，保留完整辅助朗读标签。
- Duo 模拟器成功启动应用并取得地图页截图；模拟器界面读取反复超时，因此消息／个人页运行交互、展开折叠、键盘、大字体及降低透明度操作仍待人工验收。未声称 iOS 16 真机运行通过。
- 未提交或推送本轮修改。已有 UserInterfaceState.xcuserstate 与 backend/dist 保持原状。
