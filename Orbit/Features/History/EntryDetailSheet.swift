import SwiftUI
import OrbitUI
import OrbitCore

// MARK: - Entry detail sheet

struct EntryDetailSheet: View {
    let entry: StatusEntry
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: entry.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: entry.activityIcon)
                            .font(Theme.Typography.symbol(20, .semibold))
                            .foregroundStyle(Theme.Palette.primary)
                        Text(entry.activityLabel)
                            .font(Theme.Typography.headline(.bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }

                    detailRow("时间", dateText)
                    if !entry.locationName.isEmpty { detailRow("地点", entry.locationName) }
                    detailRow("停留时长", entry.duration)
                    if entry.systemTag {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Theme.Palette.danger)
                            Text("系统识别，仅供参考")
                                .font(Theme.Typography.subheadline())
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .navigationTitle("状态详情")
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

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.callout(.medium))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }
}
