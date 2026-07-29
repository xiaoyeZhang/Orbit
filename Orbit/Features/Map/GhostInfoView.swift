import SwiftUI
import OrbitUI
import OrbitCore
import OrbitServices

/// 解释隐身模式，并提供一键开启自身隐身。
/// 地图右侧栏「N 隐身」标签与好友列表顶部入口共用同一说明。
struct GhostInfoView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let hiddenCount = session.friends.filter { $0.isGhostMode }.count
        return VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.card2)
                    .frame(width: 64, height: 64)
                Image(systemName: "moon.zzz.fill")
                    .font(Theme.Typography.symbol(28))
                    .foregroundStyle(Theme.Palette.subtle)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("隐身模式")
                    .font(Theme.Typography.title3(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text("有 \(hiddenCount) 位好友暂时选择隐身，不分享实时位置给你。")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.subtle)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Text("出于隐私保护，你不会看到具体是谁在隐身——就像你也能随时对好友隐身一样。")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Palette.subtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    enableGhostMode()
                    Toast.show("已开启隐身 🌙")
                    dismiss()
                } label: {
                    Text("我也要隐身")
                        .font(Theme.Typography.headline(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Palette.primary, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.96))

                Button {
                    dismiss()
                } label: {
                    Text("知道了")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Palette.subtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private func enableGhostMode() {
        Haptics.light()
        if var u = session.currentUser {
            u.isGhostMode = true
            session.currentUser = u
        }
        Task { try? await session.backend.setGhostMode(true) }
    }
}
