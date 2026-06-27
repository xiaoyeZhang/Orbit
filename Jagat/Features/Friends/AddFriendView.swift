import SwiftUI
import OrbitCore
import OrbitUI
import OrbitServices

struct AddFriendView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var code    = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Search by ID ──
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .font(.system(size: 15))
                        TextField("通过用户ID搜索", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .tint(Theme.Palette.primary)
                        if !code.isEmpty {
                            Button { code = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Theme.Palette.card2, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        code.isEmpty ? Theme.Palette.separator : Theme.Palette.primary.opacity(0.5),
                        lineWidth: 0.8
                    ))

                    if !code.isEmpty {
                        Button {
                            Task {
                                let ok = await session.addFriend(code: code)
                                if ok { toast = "已添加好友 🎉"; code = "" }
                            }
                        } label: {
                            Group {
                                if session.isBusy { ProgressView().tint(.white) }
                                else { Text("添加好友").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Theme.Palette.primary, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                        .disabled(code.count < 4 || session.isBusy)
                        .opacity(code.count < 4 ? 0.55 : 1)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Options ──
                    VStack(spacing: 1) {
                        optionRow(icon: "qrcode", iconColor: Theme.Palette.primary,   label: "我的二维码",   sub: "让好友扫码添加你")
                        optionRow(icon: "person.crop.circle.badge.plus", iconColor: Theme.Palette.mint, label: "通过通讯录",   sub: "同步手机联系人")
                        optionRow(icon: "qrcode.viewfinder", iconColor: Theme.Palette.sky, label: "扫一扫",       sub: "扫好友二维码", last: true)
                    }
                    .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))

                    // ── My invite code ──
                    myCodeCard

                    // ── Sync contacts ──
                    syncCard

                    if let toast {
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.mint)
                            .padding(.top, 4)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.80), value: code.isEmpty)
        }
    }

    // MARK: - Option row
    private func optionRow(icon: String, iconColor: Color, label: String,
                           sub: String, last: Bool = false, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
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
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, 74)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.97))
    }

    // MARK: - My invite code
    private var myCodeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("我的邀请码")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
            }

            Text(session.currentUser?.inviteCode ?? "—")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = session.currentUser?.inviteCode
                toast = "已复制邀请码"
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Theme.Palette.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.Palette.primary.opacity(0.4), lineWidth: 0.8)
                    )
            }
        }
        .padding(16)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sync contacts
    private var syncCard: some View {
        VStack(spacing: 10) {
            Text("同步你的联系人")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text("给应用开启通讯录权限，我们可以帮助你找到已在应用上的朋友")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button("去同步") {}
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Theme.Palette.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
