import SwiftUI
import OrbitUI
import OrbitCore

// MARK: - Place detail sheet

struct PlaceDetailSheet: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    ZStack {
                        Circle().fill(Theme.Palette.groupedBackground).frame(width: 96, height: 96)
                        Text(place.emoji).font(Theme.Typography.display())
                    }
                    Text(place.name)
                        .font(Theme.Typography.title())
                        .foregroundStyle(Theme.Palette.ink)
                    VStack(spacing: Theme.Spacing.md) {
                        detailRow("到访次数", "\(place.visitCount) 次")
                        detailRow("最近到访", place.lastVisit.relativeShort)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                    .card()
                }
                .padding(Theme.Spacing.xl)
            }
            .navigationTitle("地点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.groupedBackground)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.callout())
                .foregroundStyle(Theme.Palette.subtle)
            Spacer()
            Text(value)
                .font(Theme.Typography.callout(.medium))
                .foregroundStyle(Theme.Palette.ink)
        }
    }
}
