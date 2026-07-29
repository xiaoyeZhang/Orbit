import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct AvatarEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var avatar: AvatarConfig
    @State private var name: String
    @State private var bio: String

    init(initial: UserProfile) {
        _avatar = State(initialValue: initial.avatar)
        _name   = State(initialValue: initial.displayName)
        _bio    = State(initialValue: initial.bio)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // 实时预览
                    ZStack {
                        Circle()
                            .fill(Theme.brandGradient.opacity(0.12))
                            .frame(width: 170, height: 170)
                        PulseRing(color: Theme.Palette.primary, size: 148, lineWidth: 2, maxScale: 1.4, dual: true)
                        AvatarView(config: avatar, size: 130, showsRing: true)
                            .shadow(color: Theme.Palette.primary.opacity(0.25), radius: 18, y: 8)
                            .animation(.spring(response: 0.32, dampingFraction: 0.70), value: avatar)
                    }
                    .padding(.top, 14)

                    // 昵称 / 签名
                    VStack(spacing: 10) {
                        labeledField("昵称", systemIcon: "person", text: $name)
                        labeledField("签名", systemIcon: "quote.bubble", text: $bio)
                    }

                    // 各项选择器
                    selectorSection("背景色",
                                    items: AvatarConfig.BackgroundStyle.allCases,
                                    selected: avatar.background,
                                    onSelect: { avatar.background = $0 },
                                    swatch: { AnyView(RoundedRectangle(cornerRadius: 10, style: .continuous).fill($0.gradient)) },
                                    title: { $0.title })

                    selectorSection("肤色",
                                    items: AvatarConfig.SkinTone.allCases,
                                    selected: avatar.skinTone,
                                    onSelect: { avatar.skinTone = $0 },
                                    swatch: { AnyView(Circle().fill($0.color)) },
                                    title: { $0.title })

                    selectorSection("发型",
                                    items: AvatarConfig.HairStyle.allCases,
                                    selected: avatar.hair,
                                    onSelect: { avatar.hair = $0 },
                                    swatch: { _ in AnyView(Image(systemName: "scissors").font(.title3).foregroundStyle(Theme.Palette.ink)) },
                                    title: { $0.title })

                    selectorSection("发色",
                                    items: AvatarConfig.HairColor.allCases,
                                    selected: avatar.hairColor,
                                    onSelect: { avatar.hairColor = $0 },
                                    swatch: { AnyView(Circle().fill($0.color)) },
                                    title: { $0.title })

                    selectorSection("配饰",
                                    items: AvatarConfig.Accessory.allCases,
                                    selected: avatar.accessory,
                                    onSelect: { avatar.accessory = $0 },
                                    swatch: { _ in AnyView(Image(systemName: "sparkles").font(.title3).foregroundStyle(Theme.Palette.primary)) },
                                    title: { $0.title })
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Palette.groupedBackground.ignoresSafeArea())
            .navigationTitle("编辑形象")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAndDismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - 输入行
    private func labeledField(_ label: String, systemIcon: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.brandGradient.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: systemIcon)
                    .font(Theme.Typography.callout(.semibold))
                    .foregroundStyle(Theme.Palette.primary)
            }
            TextField(label, text: text)
                .font(Theme.Typography.body())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Theme.Spacing.md)
        .card()
    }

    // MARK: - 通用横向选择器
    private func selectorSection<T: Identifiable & Equatable>(
        _ title: String,
        items: [T],
        selected: T,
        onSelect: @escaping (T) -> Void,
        swatch: @escaping (T) -> AnyView,
        title titleFor: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Typography.callout(.bold))
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(spacing: 7) {
                            ZStack {
                                swatch(item)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                // 选中态：渐变边框 + 勾号
                                if item == selected {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(Theme.brandGradient, lineWidth: 3)
                                        .frame(width: 50, height: 50)

                                    ZStack {
                                        Circle()
                                            .fill(Theme.brandGradient)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(Theme.Typography.micro())
                                            .foregroundStyle(Theme.Palette.textPrimary)
                                    }
                                    .offset(x: 18, y: -18)
                                    .popIn()
                                }
                            }
                            Text(titleFor(item))
                                .font(Theme.Typography.caption2(item == selected ? .bold : .medium))
                                .foregroundStyle(item == selected ? Theme.Palette.primary : Theme.Palette.subtle)
                        }
                        .scaleEffect(item == selected ? 1.06 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: selected)
                        .onTapGesture {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.68)) {
                                onSelect(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .card()
    }

    private func saveAndDismiss() {
        Haptics.success()
        Task {
            guard var user = session.currentUser else { return }
            user.avatar       = avatar
            user.displayName  = name
            user.bio          = bio
            await session.updateProfile(user)
            dismiss()
        }
    }
}
