import SwiftUI
import OrbitUI

struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, title: String, sub: String, color: Color)] = [
        ("nosign",                  "免广告特权",       "畅享丝滑社交，告别广告打扰",       Color(hex: 0xFF6B6B)),
        ("bell.and.waveform.fill",  "地点提醒",         "在TA离开/到达某地时提醒我",        Color(hex: 0xFF9F43)),
        ("location.fill.viewfinder","实时动态精确定位", "多重定位方式，让位置更准确",       Color(hex: 0x2BCB96)),
        ("clock.arrow.circlepath",  "查看TA的历史动态", "你在意的TA，每一个状态不容错过",   Color(hex: 0x5352ED)),
        ("chart.bar.doc.horizontal","每日报告",         "每天生成今日行动报告",             Color(hex: 0xFFC312)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // ── Hero card ──
                        heroCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // ── Benefits ──
                        VStack(spacing: 4) {
                            Text("享受10+会员权益")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 1) {
                                ForEach(Array(benefits.enumerated()), id: \.offset) { idx, b in
                                    benefitRow(icon: b.icon, title: b.title, sub: b.sub,
                                               color: b.color, last: idx == benefits.count - 1)
                                }
                            }
                            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }

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
        }
    }

    // MARK: - Hero card
    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color(hex: 0xFFC312))
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
                            .fill([Color(hex: 0xFF6B6B), Color(hex: 0xFFC312), Color(hex: 0x2BCB96)][i].opacity(0.25))
                            .frame(width: CGFloat(50 - i * 8), height: CGFloat(50 - i * 8))
                            .offset(x: CGFloat(i * 4), y: CGFloat(-i * 6))
                    }
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(hex: 0xFFC312))
                        .font(.system(size: 20))
                }
            }

            Button { } label: {
                Text("订阅")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1A1A))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color(hex: 0xFFC312), in: RoundedRectangle(cornerRadius: 14))
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

    // MARK: - Benefit row
    private func benefitRow(icon: String, title: String, sub: String,
                            color: Color, last: Bool) -> some View {
        Button {
            // Premium feature detail (future)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sub)
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
        .buttonStyle(.pressable(scale: 0.97))
    }
}
