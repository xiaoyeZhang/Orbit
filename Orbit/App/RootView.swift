import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

// MARK: - 根视图
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    @AppStorage("orbit_hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
                    .onAppear { if !hasSeenOnboarding { showOnboarding = true } }
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(onFinish: finishOnboarding)
                    }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isAuthenticated)
        .task(id: session.isAuthenticated) {
            if session.isAuthenticated && session.friends.isEmpty {
                await session.bootstrap()
            }
        }
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
        showOnboarding = false
    }
}

// MARK: - 主界面（窄屏底部面板 / 宽屏地图与面板并排）
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 0

    var body: some View {
        GeometryReader { geometry in
            let layout = OrbitAdaptiveLayout(
                size: geometry.size,
                accessibilityText: dynamicTypeSize.isAccessibilitySize
            )
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 0) {
                    MapHomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if layout.usesSidePanel && selection != 0 {
                        Color.clear.frame(width: layout.panelWidth)
                    }
                }
                .accessibilityHidden(selection != 0 && !layout.usesSidePanel)

                if selection == 1 && !layout.usesSidePanel {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { selectTab(0) }
                        .accessibilityLabel("关闭消息面板")
                        .accessibilityAddTraits(.isButton)
                }

                // One panel subtree preserves search, navigation and scroll state on resize.
                if selection != 0 {
                    VStack(spacing: 0) {
                        if selection == 1 {
                            HStack {
                                Text("消息").font(.headline)
                                Spacer()
                                Button { selectTab(0) } label: {
                                    Image(systemName: "xmark")
                                        .font(.body.weight(.semibold))
                                        .frame(width: 44, height: 44)
                                        .orbitGlass(in: Circle(), interactive: true)
                                }
                                .accessibilityLabel("关闭消息面板")
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.sm)
                            ConversationsView()
                        } else {
                            ProfileView()
                        }
                    }
                    .frame(width: layout.panelWidth,
                           height: selection == 1 ? layout.messagePanelHeight : geometry.size.height)
                    .background(Theme.Palette.bg)
                    .clipShape(RoundedRectangle(cornerRadius: layout.usesSidePanel ? 0 : 24,
                                                style: .continuous))
                    .overlay(alignment: .leading) {
                        if layout.usesSidePanel { Divider() }
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingTabBar
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .onAppear { reporter.start() }
        .onDisappear { reporter.stop() }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 4) {
            tabButton(index: 0, title: "地图", icon: "map.fill", tint: Theme.Palette.sky)
            tabButton(index: 1, title: "消息", icon: "bubble.left.and.bubble.right.fill", tint: Theme.Palette.primary)
            tabButton(index: 2, title: "我的", icon: "person.crop.circle.fill", tint: Theme.Palette.accent)
        }
        .padding(6)
        .frame(maxWidth: 520)
        .orbitGlass(in: Capsule())
    }

    private func tabButton(index: Int, title: String, icon: String, tint: Color) -> some View {
        Button { selectTab(index == 1 && selection == 1 ? 0 : index) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .overlay(alignment: .topTrailing) {
                        if index == 1 && session.totalUnread > 0 {
                            Circle().fill(Theme.Palette.danger)
                                .frame(width: 8, height: 8)
                                .offset(x: 5, y: -2)
                        }
                    }
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(selection == index ? tint : Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(selection == index ? tint.opacity(0.14) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityValue(index == 1 && session.totalUnread > 0 ? "\(session.totalUnread) 条未读消息" : "")
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }

    private func selectTab(_ index: Int) {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) {
            selection = index
        }
    }
}
