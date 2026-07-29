import SwiftUI
import OrbitServices
import OrbitUI

struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var showSubscribe = false
    @State private var selectedBenefit: Benefit?

    private let benefits: [Benefit] = [
        Benefit(icon: "nosign", title: "免广告特权", sub: "畅享丝滑社交，告别广告打扰",
                detail: "开通会员后，App 内所有横幅与插屏广告将自动隐藏，给你纯净的社交体验。",
                color: Theme.Palette.danger),
        Benefit(icon: "bell.and.waveform.fill", title: "地点提醒", sub: "在TA离开/到达某地时提醒我",
                detail: "为你在意的好友设置常用地点（家、公司、学校），当 TA 到达或离开这些地点时，你会第一时间收到通知。",
                color: Theme.Palette.tangerine),
        Benefit(icon: "location.fill.viewfinder", title: "实时动态精确定位", sub: "多重定位方式，让位置更准确",
                detail: "会员可使用卫星 + 基站 + WiFi 多重定位融合，显著提升定位精度与稳定性。",
                color: Theme.Palette.mint),
        Benefit(icon: "clock.arrow.circlepath", title: "查看TA的历史动态", sub: "你在意的TA，每一个状态不容错过",
                detail: "回放好友近 7 天的位置轨迹与时间线，不错过 TA 的每一个重要时刻。",
                color: Theme.Palette.indigo),
        Benefit(icon: "chart.bar.doc.horizontal", title: "每日报告", sub: "每天生成今日行动报告",
                detail: "每日清晨为你生成专属行动报告，汇总昨日足迹、常去地点与互动概况。",
                color: Theme.Palette.gold),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        heroCard
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.sm)

                        benefitsSection

                        Color.clear.frame(height: 60)
                    }
                }
            }
            .navigationTitle("会员中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .sheet(isPresented: $showSubscribe) { SubscribeSheet() }
            .sheet(item: $selectedBenefit) { b in BenefitDetailSheet(benefit: b) }
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.Palette.gold)
                            .font(Theme.Typography.symbol(16))
                        Text("单人会员")
                            .font(Theme.Typography.headline(.bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    Text("查看实时定位、分享自己今日轨迹，尊享10+权益")
                        .font(Theme.Typography.subheadline())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill([Theme.Palette.danger, Theme.Palette.gold, Theme.Palette.mint][i].opacity(0.25))
                            .frame(width: CGFloat(50 - i * 8), height: CGFloat(50 - i * 8))
                            .offset(x: CGFloat(i * 4), y: CGFloat(-i * 6))
                    }
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.Palette.gold)
                        .font(Theme.Typography.symbol(20))
                }
            }

            if session.isMember {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(Theme.Typography.symbol(16, .bold))
                        .foregroundStyle(Theme.Palette.mint)
                    Text("您已是会员，尊享全部权益")
                        .font(Theme.Typography.body(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.Palette.mint.opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                Button { showSubscribe = true } label: {
                    Text("订阅")
                        .font(Theme.Typography.headline(.bold))
                        .foregroundStyle(Theme.Palette.darkInk)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Theme.Palette.gold, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .accessibilityLabel("订阅会员")
            }
        }
        .padding(18)
        .background(
            Theme.memberGradient,
            in: RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
        )
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("享受10+会员权益")
                .font(Theme.Typography.headline(.bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)

            VStack(spacing: 1) {
                ForEach(Array(benefits.enumerated()), id: \.element.id) { idx, b in
                    benefitRow(benefit: b, last: idx == benefits.count - 1)
                }
            }
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private func benefitRow(benefit: Benefit, last: Bool) -> some View {
        Button { selectedBenefit = benefit } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: benefit.icon)
                    .font(Theme.Typography.symbol(20, .semibold))
                    .foregroundStyle(benefit.color)
                    .frame(width: 44, height: 44)
                    .background(benefit.color.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(benefit.title)
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(benefit.sub)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                if session.isMember {
                    Label("已享有", systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.caption(.semibold))
                        .foregroundStyle(Theme.Palette.mint)
                } else {
                    Image(systemName: "chevron.right")
                        .font(Theme.Typography.caption(.semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.listRowV)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, Theme.Spacing.listDividerLeading)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.94))
    }
}

// MARK: - Models

private struct Benefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let sub: String
    let detail: String
    let color: Color
}

// MARK: - Benefit detail sheet

private struct BenefitDetailSheet: View {
    let benefit: Benefit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(benefit.color.opacity(0.15)).frame(width: 88, height: 88)
                        Image(systemName: benefit.icon)
                            .font(Theme.Typography.symbol(36, .semibold))
                            .foregroundStyle(benefit.color)
                    }
                    Text(benefit.title)
                        .font(Theme.Typography.title3())
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(benefit.detail)
                        .font(Theme.Typography.callout())
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle("会员权益")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
    }
}

// MARK: - Subscribe sheet

private struct SubscribeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Theme.Palette.gold.opacity(0.15)).frame(width: 96, height: 96)
                    Image(systemName: "crown.fill")
                        .font(Theme.Typography.display(.bold))
                        .foregroundStyle(Theme.Palette.gold)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text("开通单人会员")
                        .font(Theme.Typography.title())
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("连续包月 ¥18/月，随时可在设置中取消")
                        .font(Theme.Typography.callout())
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Button {
                    Haptics.light()
                    Task {
                        let ok = await session.subscribeMembership(planId: "single")
                        if ok {
                            Haptics.success()
                            Toast.show("已开通会员 🎉")
                            dismiss()
                        } else {
                            Toast.show(session.errorMessage ?? "开通失败，请稍后再试")
                        }
                    }
                } label: {
                    if session.isBusy {
                        ProgressView()
                            .tint(Theme.Palette.darkInk)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    } else {
                        Text("确认开通")
                            .font(Theme.Typography.headline(.bold))
                            .foregroundStyle(Theme.Palette.darkInk)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                }
                .disabled(session.isBusy)
                .background(Theme.Palette.gold, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .padding(.horizontal, 24)
                .accessibilityLabel("确认开通会员")

                Text("开通即代表同意《自动续订服务协议》")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            }
            .padding(.top, Theme.Spacing.xxl)
            .navigationTitle("订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
        .presentationDetents([.medium])
    }
}
