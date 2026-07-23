import SwiftUI
import OrbitUI

struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscribe = false
    @State private var selectedBenefit: Benefit?

    private let benefits: [Benefit] = [
        Benefit(icon: "nosign", title: "免广告特权", sub: "畅享丝滑社交，告别广告打扰",
                detail: "开通会员后，App 内所有横幅与插屏广告将自动隐藏，给你纯净的社交体验。",
                color: Theme.Palette.danger),
        Benefit(icon: "bell.and.waveform.fill", title: "地点提醒", sub: "在TA离开/到达某地时提醒我",
                detail: "为你在意的好友设置常用地点（家、公司、学校），当 TA 到达或离开这些地点时，你会第一时间收到通知。",
                color: Color(hex: 0xFF9F43)),
        Benefit(icon: "location.fill.viewfinder", title: "实时动态精确定位", sub: "多重定位方式，让位置更准确",
                detail: "会员可使用卫星 + 基站 + WiFi 多重定位融合，显著提升定位精度与稳定性。",
                color: Theme.Palette.mint),
        Benefit(icon: "clock.arrow.circlepath", title: "查看TA的历史动态", sub: "你在意的TA，每一个状态不容错过",
                detail: "回放好友近 7 天的位置轨迹与时间线，不错过 TA 的每一个重要时刻。",
                color: Color(hex: 0x5352ED)),
        Benefit(icon: "chart.bar.doc.horizontal", title: "每日报告", sub: "每天生成今日行动报告",
                detail: "每日清晨为你生成专属行动报告，汇总昨日足迹、常去地点与互动概况。",
                color: Theme.Palette.gold),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.Palette.gold)
                            .font(.system(size: 16))
                        Text("单人会员")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("查看实时定位、分享自己今日轨迹，尊享10+权益")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                // Decorative icons
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill([Theme.Palette.danger, Theme.Palette.gold, Theme.Palette.mint][i].opacity(0.25))
                            .frame(width: CGFloat(50 - i * 8), height: CGFloat(50 - i * 8))
                            .offset(x: CGFloat(i * 4), y: CGFloat(-i * 6))
                    }
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.Palette.gold)
                        .font(.system(size: 20))
                }
            }

            Button { showSubscribe = true } label: {
                Text("订阅")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1A1A))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Theme.Palette.gold, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x2D2D44), Color(hex: 0x1A1A2E)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Benefits
    private var benefitsSection: some View {
        VStack(spacing: 4) {
            Text("享受10+会员权益")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(Array(benefits.enumerated()), id: \.element.id) { idx, b in
                    benefitRow(benefit: b, last: idx == benefits.count - 1)
                }
            }
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
    }

    private func benefitRow(benefit: Benefit, last: Bool) -> some View {
        Button { selectedBenefit = benefit } label: {
            HStack(spacing: 14) {
                Image(systemName: benefit.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(benefit.color)
                    .frame(width: 44, height: 44)
                    .background(benefit.color.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(benefit.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(benefit.sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle().fill(Theme.Palette.separator).frame(height: 0.5).padding(.leading, 74)
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
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(benefit.color)
                    }
                    Text(benefit.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(benefit.detail)
                        .font(.system(size: 14))
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Theme.Palette.gold.opacity(0.15)).frame(width: 96, height: 96)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.Palette.gold)
                }

                VStack(spacing: 8) {
                    Text("开通单人会员")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("连续包月 ¥18/月，随时可在设置中取消")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Button {
                    Toast.show("已开通会员（演示）🎉")
                    dismiss()
                } label: {
                    Text("确认开通")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: 0x1A1A1A))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Theme.Palette.gold, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Text("开通即代表同意《自动续订服务协议》")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            }
            .padding(.top, 32)
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
