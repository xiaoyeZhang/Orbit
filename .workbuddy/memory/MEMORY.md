# Orbit 项目长期记忆

## 项目背景
- Orbit 是一款 iOS(SwiftUI,iOS 16)实时位置社交 App,产品灵感来自 Jagat(果汁儿)/ Zenly。
- 2026-07-23 由原名 Jagat 全局改名为 Orbit(commit 6f1479e,46 文件)。
- 市场 Jagat 定位:情侣/家人/密友的实时位置共享 + 情感连接 + 安全守护,成都米法屋科技开发,500万+ 下载,免费 + Super Jagat 订阅。
- 核心模块:实时位置共享、安全守护(自动报备/一键SOS)、社交互动(聊天/emoji轰炸/星球)、个人世界(迷雾地图/足迹/时光足迹)、亲密关系专属(纪念日/情侣组件)。
- 隐私优先(幽灵模式/隐身/双向授权)是 Jagat 的核心信任卖点。

## 架构约定
- 多后端:BackendService 协议 + Mock/Firebase/Supabase 实现。
- 三 Tab 架构:地图主页 / 好友 / 我的。
- 工程:Orbit.xcodeproj,scheme Orbit,bundle com.orbit.app。
- 设计系统(OrbitUI/Theme.swift):颜色走「深浅自适应」路线——文本用 `Color(.label)`/`.secondaryLabel` 等系统语义色;表面色(bg/card/card2/separator)用 `Color(UIColor(dynamicProvider: { t in t.userInterfaceStyle == .dark ? 深色 : 浅色 }))`(**注意:必须用 `dynamicProvider:` 形式,iOS 13+ 可用**;`UIColor { }` 尾随闭包初始化器是 **iOS 17 专属**,本工程部署目标 iOS 16,用了会编译卡死报 "unable to type-check this expression")按 trait 返回两色,自动跟随生效的 colorScheme。品牌色(primary/accent/sky...)为固定鲜艳色,两模式通用。新增 `AppearanceMode` 枚举(跟随系统/深色/浅色)经 `@AppStorage("orbit_appearance")` 由 OrbitApp 的 `.preferredColorScheme()` 控制,ProfileView 设置区有「外观」选择器。CTA 等品牌色按钮文字用固定 `onPrimary = .white` 保证浅色模式对比度。

## 已知环境限制
- 本会话沙箱禁止 xcodebuild/swift 重编译(sandbox-exec 绝对路径被 SIP 拒绝),只能截图验证已装 app。改名/纯文案改动需用户在 Xcode 打开 Orbit.xcodeproj 自行 Cmd+R 验证。

## 产品对齐策略（不侵权前提下对齐 Jagat）
- 原则:对齐 Jagat 的「能力域」(实时位置/安全守护/社交互动/个人世界/亲密关系),但全部用自有命名与自有视觉,不复制文案/界面/特定交互。
- Orbit 自有模块命名:实时连接 / 安心守护 / 亲密互动(含双人专属) / 我的世界。
- 独有差异化功能(Jagat 弱或没有):
  1. 氛围地图:天气·昼夜·季节作为地图图层叠加,异地氛围同步(与现有天气按钮天然衔接)。
  2. AI 轨迹日记:轨迹自动摘要生成可分享故事。
  3. 城市脉搏(可选·泛社交):附近好友热力·同城活动,隐私可控。
- 侵权护栏:禁用 Jagat/果汁儿/Super Jagat 商标词;文案原创;图标插画动效原创(Zenly 风≠Jagat 风);实现用行业通用范式;不抓取 Jagat 内容/数据。
- 落地优先级:MVP=实时连接+安心守护(隐身/一键求助)+亲密互动(聊天);氛围地图作首个差异化亮点;AI轨迹日记第二阶段;城市脉搏视冷启动决定。
- 进度:
  - 氛围地图 v1 已于 2026-07-24 实现(Ambient.swift + MapHomeView 叠层/面板 + FriendMapBubble 异地当地时间 + FriendDetailSheet 对方氛围)。
  - 隐身/幽灵模式 v1 已于 2026-07-24 做实:隐身语义=对方看不到我,地图上不渲染隐身好友位置(MapHomeView.entities 过滤 + rightSidebar 过滤 + 侧栏「N 隐身」提示);自己隐身有 UI 反馈(SelfMapBubble 灰+月亮 + 底部 ghostBanner)。设置开关在 ProfileView,SampleData 的 Coco(f5) 默认隐身可演示。
  - SOS 一键求助 v1 已完成:Message.Kind.sos(Coordinate, note:) + BackendService.sendSOS(协议扩展默认空实现) + Mock 广播所有好友(自动建会话+模拟回应) + SessionStore.sendSOS + 地图右侧红色 SOS 按钮(确认弹窗防误触+发送中+成功 toast) + ChatView 红色求助气泡(点击看位置)。
  - 聊天增强 v1 已于 2026-07-27 完成:Message.Kind.burst(emoji) + 输入栏快捷条(6 emoji + 👋戳一下) + BurstBubble 气泡 + EmojiBurstOverlay 全屏粒子动效(收发都播,首次加载历史不播) + Mock 智能回复(收到轰炸半几率轰炸回来)。同时补齐 Supabase/Firebase 对 sos/burst 的序列化/解码(4 处穷举 switch,此前 SOS 遗漏)。
  - AI 轨迹日记 v1 已于 2026-07-27 完成(第二阶段首功能):OrbitCore/TrajectoryDiary.swift(模型+sample) + BackendService.generateTrajectoryDiary(协议+默认.sample实现) + Mock 模板化生成(基于 SampleData.places 拼故事) + SessionStore 包装 + StatusHistoryView 顶部 hero(横滑日记卡+「写今天」按钮+骨架卡+查看sheet+ShareLink分享)。全部内联,SPM path 自动收录新模型文件。
  - 城市脉搏 v1 已于 2026-07-27 完成(差异化第三件·泛社交):OrbitCore/CityPulse.swift(CityPulseVisibility/NearbyPerson/CityEvent+sample) + BackendService.generateCityPulse/setCityPulseVisibility(协议+默认) + Mock 合成附近的人/同城活动(off 返回空列表演示隐私) + SessionStore 暴露 + FriendsView 顶部发现模块(隐私分段开关+附近的人横滑卡+同城活动卡+关闭空态)。全部内联。
  - 亲密关系专属组件 v1 已于 2026-07-27 完成(对齐 Jagat 情侣/密友情感连接):OrbitCore/IntimateRelation.swift(BondStatus/Anniversary/IntimateRelation+计算属性 daysTogether/nextAnniversary/nextAnniversaryCountdown+sample 用 AvatarConfig.default 防循环依赖) + BackendService.fetchIntimateRelation(协议+默认 nil) + Mock 返回.sample + SessionStore.intimateRelation 暴露 + loadIntimateRelation + ProfileView 内联双人卡(在一起天数+纪念日倒数+纪念日列表)/空态CTA。
  - 会员体系 v1 已于 2026-07-27 完成(对齐 Super Jagat 订阅,自有命名「单人会员」):BackendService.fetchMembershipStatus/subscribeMembership(协议+默认实现) + Mock(fetch 默认 false / subscribe 0.8s 空实现) + SessionStore.isMember/loadMembershipStatus/subscribeMembership + MembershipView 状态闭环(hero 订阅按钮/权益行「已享有」/SubscribeSheet 真实开通流程) + ProfileView 入口随状态切换 + WeatherDetailView 会员入口补 session 注入。
  - ⚠️ 教训:① 给 Message.Kind 加 case 必须全工程 grep `Message.Kind|message.kind` 检查穷举 switch(Supabase/Firebase 的 encode/preview/decode)。② `Toast.show` 首参是位置参数 `_ message:`(非 `message:` 标签),全工程统一。③ ForEach 多行分隔符用 `enumerated()` 索引判断,避免 `String != String?` 不可比。④ OrbitCore 新模型 sample 不得引用 OrbitServices 的 SampleData(会循环依赖),用 `AvatarConfig.default`。⑤ 视图改为依赖 `@EnvironmentObject` 后,必须 grep 全工程所有该视图的 `.sheet` 呈现处补 `.environmentObject(session)`,否则运行时崩溃(WeatherDetailView 曾漏)。⑥ 视图内部新引用某 `@EnvironmentObject`(如 session)前,必须先在该视图顶部加 `@EnvironmentObject private var x: T` 声明;只加 `import` 不加声明会编译报 `Cannot find 'x' in scope`(MembershipView 曾漏声明)。
  - 至此 MVP 五大模块(实时连接/氛围地图/隐身/安心守护SOS/亲密互动聊天增强) + 差异化三件套(氛围地图/AI轨迹日记/城市脉搏) + 亲密关系专属 + 会员体系 全部落地。
  - 2026-07-28 完成设计系统迁移(P0-P2):Typography(67处)/Spacing(18处)/Color(60处)/Shadow(1处)全量替换 + 骨架屏组件(SkeletonView) + 骨架屏接入3视图 + MapHomeView 魔法值抽象(MapLayout)。
  - 2026-07-28 完成大文件拆分:StatusHistoryView(736→515)、MapHomeView(615→515)、ProfileView(586→535)、ChatView(547→456),提取了7个新子文件,全工程最大单文件从736行降到535行。
  - 2026-07-28 新增文件:Chat/ChatViewModel.swift、Chat/EmojiBurstOverlay.swift、Map/AmbientPanelView.swift、History/DiaryDetailSheet.swift、History/EntryDetailSheet.swift、History/QuickFeatureDetailSheet.swift、Profile/PlaceDetailSheet.swift。需在 Xcode pbxproj 中手动 Add Files 注册。
  - 82 个任务全部完成,Orbit MVP 收尾打磨阶段结束。
  - 后续可选项:城��脉搏冷启动真实化、会员真实支付接入。
  - 沙箱无法编译,以上均需用户在 Xcode 打开 Orbit.xcodeproj(scheme Orbit) Cmd+R 验证。
  - 2026-07-30 完成:① 浅色模式(设计系统层自适应 Palette + AppearanceMode「外观」设置替代原强制深色,ProfileView 加外观选择器);② 引导页/空态动态字体(改系统 Font 文本样式)+无障碍(VoiceOver 合并朗读、减弱动态、onPrimary 按钮对比度)。详见当日日志。
