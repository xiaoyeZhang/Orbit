import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

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

// MARK: - 主界面（3-Tab 深色浮动栏）
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter
    @State private var selection = 0
    @Namespace private var tabNS

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Pages ──
            ZStack {
                MapHomeView()
                    .opacity(selection == 0 ? 1 : 0)
                    .allowsHitTesting(selection == 0)

                NotificationCenterView()
                    .opacity(selection == 1 ? 1 : 0)
                    .allowsHitTesting(selection == 1)

                ProfileView()
                    .opacity(selection == 2 ? 1 : 0)
                    .allowsHitTesting(selection == 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }

            // ── Floating dark tab bar ──
            darkTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { reporter.start() }
        .onDisappear { reporter.stop() }
    }

    // MARK: - Tab bar
    private var darkTabBar: some View {
        HStack(spacing: 0) {
            // Left: Map
            tabBtn(index: 0) {
                VStack(spacing: 3) {
                    ZStack {
                        if selection == 0 {
                            Circle()
                                .fill(Theme.Palette.sky.opacity(0.18))
                                .frame(width: 40, height: 40)
                        }
                        Image(systemName: selection == 0 ? "map.fill" : "map")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selection == 0 ? Theme.Palette.sky : Theme.Palette.textSecondary)
                    }
                }
            }

            Spacer()

            // Center: Messages count pill
            tabBtn(index: 1) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selection == 1
                              ? Theme.Palette.primary
                              : Theme.Palette.card2)
                        .frame(width: 64, height: 38)

                    if session.totalUnread > 0 {
                        Text(session.totalUnread > 99 ? "99+" : "\(session.totalUnread)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selection == 1 ? .white : Theme.Palette.textSecondary)
                    }
                }
            }

            Spacer()

            // Right: Profile
            tabBtn(index: 2) {
                VStack(spacing: 3) {
                    ZStack {
                        if selection == 2 {
                            Circle()
                                .fill(Theme.Palette.accent.opacity(0.18))
                                .frame(width: 40, height: 40)
                        }
                        Image(systemName: selection == 2 ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selection == 2 ? Theme.Palette.accent : Theme.Palette.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.Palette.card.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.55), radius: 32, y: 12)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private func tabBtn<Label: View>(index: Int, @ViewBuilder label: () -> Label) -> some View {
        Button {
            guard selection != index else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selection = index
            }
        } label: {
            label()
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.pressable(scale: 0.86))
    }
}

// MARK: - Notification Center (消息 tab)
private struct NotificationCenterView: View {
    var body: some View {
        ConversationsView()
    }
}
