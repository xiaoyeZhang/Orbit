# 接入 Firebase 实时后端

把 Orbit 从本地 Mock 切换到 **Firebase Auth + Cloud Firestore**（实时位置 / 聊天）。
代码已写好（`Orbit/Services/FirebaseBackendService.swift`），整份用 `#if JAGAT_FIREBASE`
守护（该编译标志由生成器在 `ENABLE_FIREBASE=1` 时注入）——未启用时不影响现有工程编译。
按下面步骤启用即可。

> 已验证：在 **未启用** Firebase 时，工程仍以 Mock 正常编译运行。Firebase 路径需要你自己的
> Firebase 项目与配置文件，下载依赖与配置后在你的机器上即可跑通。

---

## 1. 创建 Firebase 项目
1. 打开 <https://console.firebase.google.com> → 新建项目。
2. 「添加应用」→ iOS，**Bundle ID 填 `com.example.jagat`**（与本工程一致，可在 `Scripts/generate_xcodeproj.py` 里改）。
3. 下载 **`GoogleService-Info.plist`**。

## 2. 放入配置文件
把下载的 `GoogleService-Info.plist` 放到：
```
Orbit/Resources/GoogleService-Info.plist
```
（仓库里有 `GoogleService-Info.plist.sample` 示例可对照。⚠️ 真实文件含密钥，建议加入 .gitignore。）

## 3. 开启 Authentication（手机号登录）
1. Console → Authentication → 开始使用 → 启用 **Phone** 登录方式。
2. 开发期免真机短信：在 Phone 设置里添加 **测试手机号 + 固定验证码**
   （如 `+86 13800000000` / `123456`），即可在模拟器直接登录。
3. 真机短信需配置 APNs 鉴权密钥（Console → 项目设置 → Cloud Messaging）。

## 4. 创建 Firestore 数据库
1. Console → Firestore Database → 创建数据库（生产或测试模式均可）。
2. 部署安全规则（仓库根目录 `firestore.rules`）：
   ```bash
   npm i -g firebase-tools && firebase login
   firebase deploy --only firestore:rules
   ```

## 5. 生成带 Firebase 依赖的工程
```bash
ENABLE_FIREBASE=1 python3 Scripts/generate_xcodeproj.py
```
该命令会把 `firebase-ios-sdk`（SwiftPM，锁定 10.x 以兼容 Xcode 14）写入工程，
并链接 `FirebaseAuth`、`FirebaseFirestore`。首次打开 Xcode 会自动拉取依赖（较大，请耐心）。

## 6. 切换后端开关
编辑 `Orbit/App/AppEnvironment.swift`：
```swift
static let backendKind: BackendKind = .firebase   // 由 .mock 改为 .firebase
```

## 7. 运行
```bash
open Orbit.xcodeproj      # 选模拟器 Cmd+R
```
用测试手机号 + 验证码登录。首次登录会自动建资料并生成邀请码。

---

## 📦 Firestore 数据结构

```
users/{uid}
  displayName, bio, inviteCode, phoneNumber, ghostMode
  avatar:   { skinTone, hair, hairColor, accessory, background }
  location: { lat, lng, locationName, updatedAt }     ← 实时位置
  presence: { batteryLevel, isCharging, movement, speedKmh }
  friends/{friendUid}:  { isFavorite, since }          ← 好友边（双向各一条）
  places/{placeId}:     { name, emoji, location:{lat,lng}, visitCount, lastVisit }

inviteCodes/{CODE}:     { uid }                         ← 邀请码 → 用户

conversations/{cid}     (cid = 双方 uid 排序拼接，如 uidA_uidB)
  members: [uidA, uidB]
  names:   { uid: 昵称 }      avatars: { uid: {...} }
  lastMessage, lastMessageDate, unread:{ uid: 数量 }
  messages/{mid}: { senderId, type(text|location|ping), text?, lat?, lng?, locationName?, date }
```

### 实时机制
- **好友位置**：`friendsStream()` 监听 `users/{me}/friends`，再对每位好友的 `users/{uid}` 文档
  建快照监听；任一好友 `location` 变化即实时推送到地图。
- **聊天**：`messagesStream(cid)` 监听 `conversations/{cid}/messages`（按时间排序）。
- 客户端定位变化时调用 `updateMyLocation()` 写回 `users/{me}.location`（建议节流，如 ≥10s 一次）。

---

## ⚠️ 说明
- 位置上报已做**节流**（距离+时间双阈值）与**省电/后台上传**：进入后台改用「显著位置变更」，
  开启「应用关闭后仍上传」后被系统终止也会被唤醒续传（写入 `users/{me}.location`）。
  相关代码：`PresenceReporter` / `LocationManager` / `AppDelegate`，参数可在 App 内「我的 → 上报与隐私」调整。
- `presence`（电量/移动/速度）已**自动采集**并写入 `users/{me}.presence`
  （`UIDevice` 取电量、`CMMotionActivityManager` 取运动状态、GPS 取速度）。
- 安全规则为示例，上线前请按隐私需求复核（尤其是位置可见范围）。
- 如需回到本地演示：`backendKind = .mock` 即可（无需移除 Firebase）。
