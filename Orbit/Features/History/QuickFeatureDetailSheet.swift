import SwiftUI
import OrbitUI

// MARK: - Feature detail sheet

struct QuickFeatureDetailSheet: View {
    let feature: QuickFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(feature.color.opacity(0.15)).frame(width: 88, height: 88)
                        Image(systemName: feature.icon)
                            .font(Theme.Typography.symbol(36, .semibold))
                            .foregroundStyle(feature.color)
                    }
                    Text(feature.label)
                        .font(Theme.Typography.title3())
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(feature.detail)
                        .font(Theme.Typography.callout())
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle("功能详情")
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
