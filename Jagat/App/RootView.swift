import SwiftUI

// MARK: - 根视图
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
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
}

// MARK: - 主界面（ZStack + 自定义悬浮标签栏，完全绕过系统 TabBar）
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter
    @State private var selection = MainTabView.initialTab
    @Namespace private var tabNS

    private struct TabItem {
        let icon: String
        let activeIcon: String
        let label: String
    }

    private let tabs: [TabItem] = [
        TabItem(icon: "map",                          activeIcon: "map.fill",                          label: "地图"),
        TabItem(icon: "person.2",                     activeIcon: "person.2.fill",                     label: "好友"),
        TabItem(icon: "bubble.left.and.bubble.right", activeIcon: "bubble.left.and.bubble.right.fill", label: "消息"),
        TabItem(icon: "person.crop.circle",           activeIcon: "person.crop.circle.fill",           label: "我的"),
    ]

    // 悬浮栏高度（Capsule 高度 + 底部 safe area padding）
    private let tabBarVisualHeight: CGFloat = 68

    var body: some View {
        ZStack(alignment: .bottom) {
            // 四个页面常驻内存，用 opacity + allowsHitTesting 切换，避免系统 TabBar
            ZStack {
                MapHomeView()
                    .opacity(selection == 0 ? 1 : 0)
                    .allowsHitTesting(selection == 0)

                FriendsView()
                    .opacity(selection == 1 ? 1 : 0)
                    .allowsHitTesting(selection == 1)

                ConversationsView()
                    .opacity(selection == 2 ? 1 : 0)
                    .allowsHitTesting(selection == 2)

                ProfileView()
                    .opacity(selection == 3 ? 1 : 0)
                    .allowsHitTesting(selection == 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 为标签栏留出底部空间（MapHomeView 自己处理 padding，其余靠 safeAreaInset）
            .safeAreaInset(edge: .bottom) {
                // Tab 栏胶囊高度 68 + 底部 padding 24 + 安全余量 12 = 104
                Color.clear.frame(height: tabBarVisualHeight + 36)
            }

            floatingTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(Theme.Palette.primary)
        .onAppear { reporter.start() }
        .onDisappear { reporter.stop() }
    }

    // MARK: - 悬浮标签栏
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                tabButton(index: idx, item: tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(0.20), radius: 28, y: 12)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: selection)
    }

    private func tabButton(index: Int, item: TabItem) -> some View {
        let active = selection == index

        return Button {
            guard selection != index else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                selection = index
            }
        } label: {
            HStack(spacing: active ? 6 : 0) {
                Image(systemName: active ? item.activeIcon : item.icon)
                    .font(.system(size: 16, weight: active ? .bold : .regular))
                    .frame(width: 20)
                    .scaleEffect(active ? 1.05 : 1.0)

                if active {
                    Text(item.label)
                        .font(.system(size: 13, weight: .bold))
                        .fixedSize()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .leading).combined(with: .opacity),
                            removal:   .scale(scale: 0.55, anchor: .leading).combined(with: .opacity)
                        ))
                }
            }
            .foregroundStyle(active ? .white : Theme.Palette.subtle)
            .padding(.horizontal, active ? 16 : 0)
            .padding(.vertical, 10)
            .frame(maxWidth: active ? nil : .infinity)
            .background {
                if active {
                    Capsule()
                        .fill(Theme.brandGradient)
                        .matchedGeometryEffect(id: "activeTab", in: tabNS)
                        .shadow(color: Theme.Palette.primary.opacity(0.50), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.88))
        .overlay(alignment: .topTrailing) {
            if index == 2 && session.totalUnread > 0 {
                Text(session.totalUnread > 9 ? "9+" : "\(session.totalUnread)")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Palette.accent))
                    .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 4, y: 2)
                    .offset(x: active ? 10 : 4, y: -2)
                    .popIn()
            }
        }
    }

    private static var initialTab: Int {
        switch ProcessInfo.processInfo.environment["JAGAT_TAB"] {
        case "friends": return 1
        case "chat":    return 2
        case "profile": return 3
        default:        return 0
        }
    }
}
