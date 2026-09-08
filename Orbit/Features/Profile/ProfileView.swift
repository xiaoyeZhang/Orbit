import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter

    @ObservedObject private var langMgr = LanguageManager.shared

    @State private var showAvatarEditor  = false
    @State private var showReporting     = false
    @State private var showHistory       = false
    @State private var showMembership    = false
    @State private var showLangPicker    = false
    @State private var showOnboarding     = false
    @State private var selectedPlace: Place?
    @State private var loadingProfile = true

    @AppStorage("orbit_appearance") private var appearance = AppearanceMode.system

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    heroHeader
                        .popIn(delay: 0)

                    statsRow
                        .popIn(delay: 0.06)

                    intimateSection
                        .popIn(delay: 0.09)

                    placesSection
                        .popIn(delay: 0.12)

                    settingsSection
                        .popIn(delay: 0.18)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("我的")
            .accessibilityLabel("个人中心")
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
                    .environmentObject(session)
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
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
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onFinish: { showOnboarding = false })
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["JAGAT_OPEN"] == "reporting" {
                    showReporting = true
                }
                Task {
                    await session.loadIntimateRelation()
                    await session.loadMembershipStatus()
                    loadingProfile = false
                }
            }
        }
    }

    // MARK: - 英雄头部

    private var heroHeader: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Palette.surface)
                .shadowElevated()

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(height: 116)
                    Circle().fill(Theme.Palette.onGradient.opacity(0.08)).frame(width: 140)
                        .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 40, y: -30)
                    Circle().fill(Theme.Palette.onGradient.opacity(0.05)).frame(width: 80)
                        .frame(maxWidth: .infinity, alignment: .leading).offset(x: -20, y: 20)
                }
                .clipped()

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

                    HStack(spacing: Theme.Spacing.sm) {
                        BatteryBadge(presence: reporter.currentPresence)
                        MovementChip(presence: reporter.currentPresence)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 54)
                .padding(.bottom, 22)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxWidth: .infinity)
            }

            Button { showAvatarEditor = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(config: session.currentUser?.avatar ?? .default,
                               size: 88, showsRing: true, ringColor: Theme.Palette.onGradient)
                        .themedShadow(.glow(Theme.Palette.primary))
                        .breathing(scale: 1.028, duration: 3.5)

                    ZStack {
                        Circle().fill(Theme.Palette.primary).frame(width: 26, height: 26)
                        Image(systemName: "camera.fill")
                            .font(Theme.Typography.symbol(11, .bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .themedShadow(.floating)
                }
            }
            .buttonStyle(.pressable(scale: 0.92))
            .accessibilityLabel("编辑头像")
            .offset(y: 116 - 44)
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
                .font(Theme.Typography.title(.heavy, design: .rounded))
                .foregroundStyle(AnyShapeStyle(gradient))
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .card()
    }

    // MARK: - 亲密关系

    private var intimateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .font(Theme.Typography.callout(.bold))
                    .foregroundStyle(Theme.Palette.danger)
                Text("亲密关系")
                    .font(Theme.Typography.body(.bold))
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                if let rel = session.intimateRelation {
                    BadgeChip(text: "\(rel.status.emoji) \(rel.status.rawValue)",
                              textColor: Theme.Palette.danger,
                              bgColor: Theme.Palette.danger.opacity(0.12))
                }
            }
            .accessibilityLabel("亲密关系板块")

            if let rel = session.intimateRelation {
                intimateCard(rel)
            } else if loadingProfile {
                intimateSkeletonCard
            } else {
                EmptyStateView(
                    icon: "heart.circle",
                    title: "和最重要的人建立专属空间",
                    subtitle: "绑定密友或情侣，记录在一起的每一天",
                    actionLabel: "建立亲密关系",
                    action: {
                        Haptics.light()
                        Toast.show("演示版：亲密关系需在真实后端绑定密友 / 情侣")
                    },
                    tint: Theme.Palette.danger
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var intimateSkeletonCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 0) {
                SkeletonBlock(height: 56, shape: .circle)
                SkeletonBlock(height: 56, shape: .circle)
                    .offset(x: -30)
            }
            SkeletonBlock(width: 140, height: 10, shape: .line(height: 10))
            SkeletonBlock(width: 80, height: 28, shape: .line(height: 28))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func intimateCard(_ rel: IntimateRelation) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 0) {
                AvatarView(config: session.currentUser?.avatar ?? .default,
                           size: 56, showsRing: true, ringColor: Theme.Palette.primary)
                ZStack {
                    Circle().fill(Theme.Palette.surface).frame(width: 22, height: 22)
                    Image(systemName: "heart.fill")
                        .font(Theme.Typography.symbol(11, .bold))
                        .foregroundStyle(Theme.Palette.danger)
                }
                .offset(x: -10)
                AvatarView(config: rel.partnerAvatar, size: 56, showsRing: true, ringColor: Theme.Palette.danger)
                    .offset(x: -20)
            }
            .padding(.top, Theme.Spacing.xs)

            Text("你和 \(rel.partnerName) 已经在一起")
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)

            HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.xs) {
                Text("\(rel.daysTogether)")
                    .font(Theme.Typography.title(.heavy, design: .rounded))
                    .foregroundStyle(Theme.Palette.danger)
                Text("天")
                    .font(Theme.Typography.body(.bold))
                    .foregroundStyle(Theme.Palette.subtle)
            }
            .padding(.top, -6)

            if let next = rel.nextAnniversary {
                HStack(spacing: Theme.Spacing.md) {
                    Text(next.emoji).font(Theme.Typography.title2(.heavy))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.title)
                            .font(Theme.Typography.callout(.semibold))
                            .foregroundStyle(Theme.Palette.ink)
                        Text("还有 \(rel.nextAnniversaryCountdown) 天")
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    Spacer()
                    Text(next.date.relativeShort)
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.subtle)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.danger.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }

            VStack(spacing: 0) {
                ForEach(Array(rel.anniversaries.enumerated()), id: \.element.id) { idx, a in
                    HStack(spacing: Theme.Spacing.md) {
                        Text(a.emoji).font(Theme.Typography.headline())
                        Text(a.title)
                            .font(Theme.Typography.callout(.medium))
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Text(a.date.relativeShort)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    if idx < rel.anniversaries.count - 1 {
                        ListDivider(leadingPadding: 30)
                    }
                }
            }
        }
    }

    // MARK: - 足迹

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("我的足迹", systemImage: "mappin.and.ellipse")
                .font(Theme.Typography.body(.bold))
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityLabel("我的足迹板块")

            if session.places.isEmpty {
                EmptyStateView(
                    icon: "mappin.slash",
                    title: "还没有足迹，出去走走吧",
                    subtitle: "打开位置共享后，你常去的地方会自动出现在这里",
                    tint: Theme.Palette.sky
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                ForEach(Array(session.places.enumerated()), id: \.element.id) { idx, place in
                    placeRow(place)
                        .staggeredAppear(index: idx)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func placeRow(_ place: Place) -> some View {
        Button { selectedPlace = place } label: {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.groupedBackground)
                        .frame(width: 40, height: 40)
                    Text(place.emoji)
                        .font(Theme.Typography.title3())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(Theme.Typography.callout(.semibold))
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
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.96))
        .accessibilityLabel("地点: \(place.name), 到访\(place.visitCount)次")
    }

    // MARK: - 设置区

    private var settingsSection: some View {
        VStack(spacing: 0) {
            Group {
                // 外观（深浅模式）
                HStack(spacing: Theme.Spacing.md) {
                    SettingsIcon(systemName: "paintbrush.fill", gradient: AnyShapeStyle(Theme.brandGradient))
                    Text("外观")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Picker("", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Palette.primary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.listRowV)
                .accessibilityLabel("外观模式")

                ListDivider()

                // 隐身模式
                HStack(spacing: Theme.Spacing.md) {
                    SettingsIcon(systemName: "moon.zzz.fill", gradient: AnyShapeStyle(Theme.brandGradient))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("隐身模式")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Palette.ink)
                        Text("开启后好友看不到你的实时位置")
                            .font(Theme.Typography.caption2())
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    Spacer()
                    Toggle("", isOn: ghostModeBinding)
                        .labelsHidden()
                        .tint(Theme.Palette.primary)
                        .accessibilityLabel("隐身模式开关")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.listRowV)

                ListDivider()

                // 邀请码
                SettingsRow(
                    icon: "qrcode",
                    gradient: AnyShapeStyle(Theme.oceanGradient),
                    title: "邀请码",
                    showChevron: false,
                    action: nil
                )
                .overlay(alignment: .trailing) {
                    Text(session.currentUser?.inviteCode ?? "—")
                        .font(Theme.Typography.subheadline(.bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.subtle)
                        .padding(.trailing, Theme.Spacing.lg)
                }

                ListDivider()

                // 历史状态
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    gradient: AnyShapeStyle(Theme.skyGradient),
                    title: "我的历史状态"
                ) { showHistory = true }

                ListDivider()

                // 语言
                SettingsRow(
                    icon: "globe",
                    gradient: AnyShapeStyle(Theme.oceanGradient),
                    title: "语言"
                )
                .overlay(alignment: .trailing) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("\(langMgr.current.flag) \(langMgr.current.displayName)")
                            .font(Theme.Typography.subheadline(.medium))
                            .foregroundStyle(Theme.Palette.subtle)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                    .padding(.trailing, Theme.Spacing.lg)
                }
                .onTapGesture { showLangPicker = true }

                ListDivider()

                // 会员中心
                Button { showMembership = true } label: {
                    membershipRow
                }
                .buttonStyle(.pressable(scale: 0.94))
                .accessibilityLabel("会员中心")
            }

            Group {
                ListDivider()

                // 重新看引导
                SettingsRow(
                    icon: "sparkles",
                    gradient: AnyShapeStyle(Theme.brandGradient),
                    title: "重新看引导"
                ) {
                    Haptics.light()
                    showOnboarding = true
                }
                .accessibilityLabel("重新看新手引导")

                ListDivider()

                // 上报与隐私
                SettingsRow(
                    icon: "dot.radiowaves.left.and.right",
                    gradient: AnyShapeStyle(Theme.sunsetGradient),
                    title: "上报与隐私"
                ) { showReporting = true }

                ListDivider()

                // 退出登录
                Button {
                    Haptics.medium()
                    session.signOut()
                } label: {
                    signOutRow
                }
                .buttonStyle(.pressable(scale: 0.94))
                .accessibilityLabel("退出登录")
            }
        }
        .card()
    }

    private var signOutRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            SettingsIcon(systemName: "rectangle.portrait.and.arrow.right",
                         gradient: AnyShapeStyle(Theme.sunsetGradient))
            Text("退出登录")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.danger)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.listRowV)
        .contentShape(Rectangle())
    }

    private var membershipRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(Theme.Typography.headline(.semibold))
                .foregroundStyle(Theme.Palette.gold)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

            Text("会员中心")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.ink)
            Spacer()
            if session.isMember {
                BadgeChip(text: "已开通", textColor: Theme.Palette.mint,
                          bgColor: Theme.Palette.mint.opacity(0.15))
            } else {
                BadgeChip(text: "解锁10+权益", textColor: Theme.Palette.gold,
                          bgColor: Theme.Palette.gold.opacity(0.15))
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.Palette.subtle)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.listRowV)
        .contentShape(Rectangle())
    }

    // MARK: - Ghost mode binding

    private var ghostModeBinding: Binding<Bool> {
        Binding(
            get: { session.currentUser?.isGhostMode ?? false },
            set: { newValue in
                Haptics.light()
                if var u = session.currentUser {
                    u.isGhostMode = newValue
                    session.currentUser = u
                }
                Task { try? await session.backend.setGhostMode(newValue) }
            }
        )
    }
}

