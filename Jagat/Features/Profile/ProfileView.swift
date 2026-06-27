import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter

    @EnvironmentObject private var langMgr: LanguageManager

    @State private var showAvatarEditor  = false
    @State private var showReporting     = false
    @State private var showHistory       = false
    @State private var showMembership    = false
    @State private var showLangPicker    = false
    @State private var ghostMode         = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroHeader
                        .popIn(delay: 0)

                    statsRow
                        .popIn(delay: 0.06)

                    placesSection
                        .popIn(delay: 0.12)

                    settingsSection
                        .popIn(delay: 0.18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("我的")
            .sheet(isPresented: $showAvatarEditor) {
                if let user = session.currentUser {
                    AvatarEditorView(initial: user)
                }
            }
            .sheet(isPresented: $showReporting) {
                ReportingSettingsView()
                    .environmentObject(AppServices.shared.location)
            }
            .sheet(isPresented: $showHistory) {
                StatusHistoryView()
            }
            .sheet(isPresented: $showMembership) {
                MembershipView()
            }
            .confirmationDialog(Text("语言"), isPresented: $showLangPicker, titleVisibility: .visible) {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        withAnimation { langMgr.current = lang }
                    } label: {
                        Text("\(lang.flag) \(lang.displayName)")
                    }
                }
                Button("取消 / Cancel", role: .cancel) {}
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["JAGAT_OPEN"] == "reporting" {
                    showReporting = true
                }
            }
        }
    }

    // MARK: - 英雄头部（渐变条 + 头像骑缝 + 名字区）
    private var heroHeader: some View {
        ZStack(alignment: .top) {
            // 白色卡片整体（含顶部渐变区 + 底部文字区）
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Palette.surface)
                .shadow(color: .black.opacity(0.07), radius: 16, y: 6)

            VStack(spacing: 0) {
                // 渐变顶部带
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(height: 116)
                    // 装饰圆
                    Circle().fill(.white.opacity(0.08)).frame(width: 140)
                        .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 40, y: -30)
                    Circle().fill(.white.opacity(0.05)).frame(width: 80)
                        .frame(maxWidth: .infinity, alignment: .leading).offset(x: -20, y: 20)
                }
                .clipped()

                // 文字区
                VStack(spacing: 6) {
                    Text(session.currentUser?.displayName ?? "—")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Palette.ink)

                    if let bio = session.currentUser?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.subtle)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 8) {
                        BatteryBadge(presence: reporter.currentPresence)
                        MovementChip(presence: reporter.currentPresence)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 54)   // 为头像悬浮留空
                .padding(.bottom, 22)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }

            // 头像骑在渐变条和文字区的接缝上
            Button { showAvatarEditor = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(config: session.currentUser?.avatar ?? .default,
                               size: 88, showsRing: true, ringColor: .white)
                        .shadow(color: Theme.Palette.primary.opacity(0.35), radius: 14, y: 6)
                        .breathing(scale: 1.028, duration: 3.5)

                    ZStack {
                        Circle().fill(Theme.Palette.primary).frame(width: 26, height: 26)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
            }
            .buttonStyle(.pressable(scale: 0.92))
            .offset(y: 116 - 44)   // 接缝处：渐变高度 - 头像半径
        }
    }

    // MARK: - 统计行
    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(value: "\(session.friends.count)",       label: "好友",  gradient: Theme.brandGradient)
            statPill(value: "\(session.favoriteFriends.count)", label: "关注", gradient: Theme.sunsetGradient)
            statPill(value: "\(session.places.count)",        label: "足迹",  gradient: Theme.oceanGradient)
        }
    }

    private func statPill<G: ShapeStyle>(value: String, label: String, gradient: G) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AnyShapeStyle(gradient))
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card()
    }

    // MARK: - 足迹
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("我的足迹", systemImage: "mappin.and.ellipse")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Palette.ink)

            if session.places.isEmpty {
                Text("还没有足迹，出去走走吧 🗺")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.subtle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(session.places.enumerated()), id: \.element.id) { idx, place in
                    placeRow(place)
                        .staggeredAppear(index: idx)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func placeRow(_ place: Place) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.groupedBackground)
                    .frame(width: 40, height: 40)
                Text(place.emoji)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("到访 \(place.visitCount) 次 · \(place.lastVisit.relativeShort)")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.subtle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.subtle.opacity(0.6))
        }
        .padding(.vertical, 4)
    }

    // MARK: - 设置区
    private var settingsSection: some View {
        VStack(spacing: 0) {
            Group {
                // 隐身模式
                HStack(spacing: 14) {
                    settingIcon(systemName: "moon.zzz.fill", gradient: Theme.brandGradient)
                    Text("隐身模式")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Toggle("", isOn: $ghostMode)
                        .labelsHidden()
                        .tint(Theme.Palette.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .onChange(of: ghostMode) { on in
                    Haptics.light()
                    Task { try? await session.backend.setGhostMode(on) }
                }

                divider

                // 邀请码
                HStack(spacing: 14) {
                    settingIcon(systemName: "qrcode", gradient: Theme.oceanGradient)
                    Text("邀请码")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Text(session.currentUser?.inviteCode ?? "—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.subtle)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                divider

                // 历史状态
                Button { showHistory = true } label: {
                    HStack(spacing: 14) {
                        settingIcon(systemName: "clock.arrow.circlepath", gradient: Theme.skyGradient)
                        Text("我的历史状态")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.97))

                divider

                // 语言
                Button { showLangPicker = true } label: {
                    HStack(spacing: 14) {
                        settingIcon(systemName: "globe", gradient: Theme.oceanGradient)
                        Text("语言")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Text("\(langMgr.current.flag) \(langMgr.current.displayName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Palette.subtle)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.97))

                divider

                // 会员中心
                Button { showMembership = true } label: {
                    membershipRow
                }
                .buttonStyle(.pressable(scale: 0.97))
            }

            Group {
                divider

                // 上报与隐私
                Button { showReporting = true } label: {
                    HStack(spacing: 14) {
                        settingIcon(systemName: "dot.radiowaves.left.and.right", gradient: Theme.sunsetGradient)
                        Text("上报与隐私")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.subtle.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.97))

                divider

                // 退出登录
                Button {
                    Haptics.medium()
                    session.signOut()
                } label: {
                    signOutRow
                }
                .buttonStyle(.pressable(scale: 0.97))
            }
        }
        .card()
    }

    private var divider: some View {
        Divider().padding(.leading, 54)
    }

    private func settingIcon<G: ShapeStyle>(systemName: String, gradient: G) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AnyShapeStyle(gradient))
                .frame(width: 30, height: 30)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var signOutRow: some View {
        HStack(spacing: 14) {
            settingIcon(systemName: "rectangle.portrait.and.arrow.right", gradient: Theme.sunsetGradient)
            Text("退出登录")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Palette.danger)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var membershipRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFFC312))
                .frame(width: 36, height: 36)
                .background(Color(hex: 0xFFC312).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

            Text("会员中心")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text("解锁10+权益")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFFC312))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(hex: 0xFFC312).opacity(0.15), in: Capsule())
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.subtle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
