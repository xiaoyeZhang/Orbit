import SwiftUI
import OrbitUI
import OrbitCore

// MARK: - 轨迹日记详情 sheet

struct DiaryDetailSheet: View {
    let diary: TrajectoryDiary
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy 年 M 月 d 日"
        return fmt.string(from: diary.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle().fill(Theme.Palette.primary.opacity(0.14))
                                .frame(width: 72, height: 72)
                            Text(diary.coverEmoji).font(Theme.Typography.titleLarge(.bold))
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(diary.title)
                                .font(Theme.Typography.title3())
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(dateText)
                                .font(Theme.Typography.subheadline(.medium))
                                .foregroundStyle(Theme.Palette.textSecondary)
                            HStack(spacing: 6) {
                                Image(systemName: "face.smiling").font(Theme.Typography.caption())
                                Text("今日心情 · \(diary.mood)")
                                    .font(Theme.Typography.caption(.medium))
                            }
                            .foregroundStyle(Theme.Palette.primary)
                        }
                    }

                    Text(diary.story)
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineSpacing(6)

                    HStack(spacing: Theme.Spacing.md) {
                        statBlock("📍", "\(diary.placesVisited)", "途经地方")
                        statBlock("🚶", String(format: "%.1f", diary.distanceKm), "漫游 km")
                        statBlock("⏱️", diary.durationLabel.replacingOccurrences(of: "活跃 ", with: ""), "活跃")
                    }

                    Text("途经的点")
                        .font(Theme.Typography.body(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    VStack(spacing: 10) {
                        ForEach(diary.highlights) { h in
                            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                Text(h.emoji).font(Theme.Typography.title2(.heavy))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(h.placeName)
                                            .font(Theme.Typography.callout(.semibold))
                                            .foregroundStyle(Theme.Palette.textPrimary)
                                        Spacer()
                                        Text(h.time)
                                            .font(Theme.Typography.caption())
                                            .foregroundStyle(Theme.Palette.textSecondary)
                                    }
                                    Text(h.note)
                                        .font(Theme.Typography.subheadline())
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        }
                    }

                    ShareLink(item: diary.shareText) {
                        Label("分享这段日记", systemImage: "square.and.arrow.up")
                            .font(Theme.Typography.body(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.listRowV)
                            .background(Theme.Palette.primary, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.pressable(scale: 0.96))
                }
                .padding(Theme.Spacing.xl)
            }
            .navigationTitle("轨迹日记")
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

    private func statBlock(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(icon).font(Theme.Typography.subheadline())
                Text(value).font(Theme.Typography.headline(.bold)).foregroundStyle(Theme.Palette.textPrimary)
            }
            Text(label).font(Theme.Typography.caption2()).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}
