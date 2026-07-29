import SwiftUI
import OrbitServices
import OrbitUI

// MARK: - 氛围地图设置面板

struct AmbientPanelView: View {
    @Binding var layers: AmbientLayers
    let ambient: AmbientState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    currentCard
                    layerToggle(title: "昼夜", subtitle: ambient.timeOfDay.title,
                                icon: ambient.timeOfDay.systemImage, color: ambient.timeOfDay.tint,
                                isOn: $layers.dayNight)
                    layerToggle(title: "天气", subtitle: ambient.weather.title,
                                icon: ambient.weather.systemImage, color: ambient.weather.tint,
                                isOn: $layers.weather)
                    layerToggle(title: "季节", subtitle: ambient.season.title,
                                icon: ambient.season.systemImage, color: ambient.season.tint,
                                isOn: $layers.season)
                    tipCard
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("氛围地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.Typography.body(.semibold))
                            .foregroundStyle(Theme.Palette.subtle)
                    }
                }
            }
        }
    }

    private var currentCard: some View {
        HStack(spacing: Theme.Spacing.md) {
                Image(systemName: ambient.timeOfDay.systemImage)
                    .font(Theme.Typography.title2(.heavy))
                .foregroundStyle(ambient.timeOfDay.tint)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(ambient.summary)
                    .font(Theme.Typography.body(.bold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("天气、昼夜与季节会作为淡色图层叠加在地图上")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.subtle)
            }
            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .card()
    }

    private func layerToggle(title: String, subtitle: String, icon: String,
                             color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(color.opacity(0.20)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(Theme.Typography.symbol(18, .bold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(Theme.Typography.headline(.semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .card()
    }

    private var tipCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "mappin.and.ellipse")
                .font(Theme.Typography.callout())
                .foregroundStyle(Theme.Palette.subtle)
            Text("地图上的好友点位会按各自所在地的当地时间显示昼夜，异地好友此刻是白天还是夜晚一目了然。")
                .font(.caption)
                .foregroundStyle(Theme.Palette.subtle)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}
