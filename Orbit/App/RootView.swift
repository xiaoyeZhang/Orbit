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

// MARK: - 主界面（3-Tab 深色浮动栏）
struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var reporter: PresenceReporter
    @State private var selection = 0
    @State private var sheetDragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map is always the background ──
            MapHomeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Profile slides in (full replace) ──
            if selection == 2 {
                ProfileView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)
                    ))
            }

            // ── Messages slides up as bottom sheet ──
            if selection == 1 {
                // Tap-outside dismiss overlay
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            selection = 0
                        }
                    }
                    .transition(.opacity)

                ConversationsView()
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.72)
                    .background(Theme.Palette.bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.6), radius: 40, y: -8)
                    .offset(y: max(0, sheetDragOffset))
                    .gesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .local)
                            .onChanged { value in
                                // 只允许向下拖
                                if value.translation.height > 0 {
                                    sheetDragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                let velocity = value.predictedEndTranslation.height
                                if value.translation.height > 80 || velocity > 300 {
                                    // 超过阈值 → 收起
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        sheetDragOffset = 0
                                        selection = 0
                                    }
                                } else {
                                    // 弹回原位
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                                        sheetDragOffset = 0
                                    }
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .ignoresSafeArea(edges: .bottom)
                    .onChange(of: selection) { _ in sheetDragOffset = 0 }
            }

            // ── Floating dark tab bar (always on top) ──
            darkTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.40, dampingFraction: 0.82), value: selection)
        .onAppear { reporter.start() }
        .onDisappear { reporter.stop() }
    }

    // MARK: - Tab bar
    private var darkTabBar: some View {
        HStack(spacing: 0) {
            // Left: Pulse/radar icon (map & discover)
            tabBtn(index: 0) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(selection == 0
                                     ? Theme.Palette.sky
                                     : Theme.Palette.textSecondary)
            }

            Spacer()

            // Center: Friend/message count pill
            tabBtn(index: 1) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selection == 1 ? Theme.Palette.primary : Theme.Palette.card2)
                        .frame(width: 64, height: 42)
                    let count = session.friends.count > 0 ? session.friends.count : session.totalUnread
                    if count > 0 {
                        Text("\(min(count, 99))")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selection == 1 ? .white : Theme.Palette.textSecondary)
                    }
                }
            }

            Spacer()

            // Right: Location pin
            tabBtn(index: 2) {
                Image(systemName: selection == 2 ? "mappin.circle.fill" : "mappin.circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(selection == 2
                                     ? Theme.Palette.accent
                                     : Theme.Palette.textSecondary)
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
            // Tapping the messages tab again collapses it back to map
            if index == 1 && selection == 1 {
                Haptics.selection()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    selection = 0
                }
                return
            }
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
