import SwiftUI
import OrbitUI

/// 首次启动引导：讲解地图实时位置、隐身保护、一键求助三件核心事。
/// 仅在用户首次进入主界面且未看过时，由 RootView 以 fullScreenCover 呈现。
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "location.circle.fill", color: Theme.Palette.sky,
                       title: "欢迎使用 Orbit",
                       subtitle: "和重要的人的位置，一直在一起。下面三件事，帮你更安心地连接。"),
        OnboardingPage(icon: "location.fill", color: Theme.Palette.sky,
                       title: "实时看见彼此",
                       subtitle: "打开地图，就能看到在线的好友此刻在哪，像一直陪在身边。"),
        OnboardingPage(icon: "moon.zzz.fill", color: Theme.Palette.accent,
                       title: "想静静？开启隐身",
                       subtitle: "不想被看到时，一键隐身。你也看不到谁隐身，互相尊重彼此隐私。"),
        OnboardingPage(icon: "exclamationmark.shield.fill", color: Theme.Palette.danger,
                       title: "遇到情况，一键求助",
                       subtitle: "点红色按钮，立刻把你的位置和状态发给所有好友。"),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Theme.Palette.bg
                .ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                    pageContent(p)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: page)

            VStack(spacing: 0) {
                // 顶部跳过
                HStack {
                    Spacer()
                    Button {
                        Haptics.selection()
                        onFinish()
                    } label: {
                        Text("跳过")
                            .font(Theme.Typography.subheadline())
                            .foregroundStyle(Theme.Palette.subtle)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    .accessibilityLabel("跳过引导")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)

                Spacer()

                // 底部进度圆点 + 主按钮
                VStack(spacing: Theme.Spacing.lg) {
                    pageDots

                    Button {
                        Haptics.light()
                        if isLast {
                            onFinish()
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                page += 1
                            }
                        }
                    } label: {
                        Text(isLast ? "开始使用" : "下一步")
                            .font(Theme.Typography.headline(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.Palette.primary, in: Capsule())
                    }
                    .buttonStyle(.pressable(scale: 0.96))
                    .accessibilityLabel(isLast ? "开始使用" : "下一页")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.Palette.primary : Theme.Palette.separator)
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
            }
        }
        .accessibilityHidden(true)
    }

    private func pageContent(_ p: OnboardingPage) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(p.color.opacity(0.15))
                    .frame(width: 132, height: 132)
                Circle()
                    .fill(Theme.Palette.card2)
                    .frame(width: 104, height: 104)
                Image(systemName: p.icon)
                    .font(Theme.Typography.symbol(48))
                    .foregroundStyle(p.color)
            }
            .padding(.top, 40)

            VStack(spacing: Theme.Spacing.sm) {
                Text(p.title)
                    .font(Theme.Typography.titleLarge(.bold))
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.center)

                Text(p.subtitle)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.subtle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingPage {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
}
