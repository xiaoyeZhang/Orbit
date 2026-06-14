import SwiftUI

/// 添加好友：展示自己的邀请码，或输入对方邀请码添加。
struct AddFriendView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                // 我的邀请码
                VStack(spacing: 10) {
                    Text("我的邀请码")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text(session.currentUser?.inviteCode ?? "—")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Button {
                        UIPasteboard.general.string = session.currentUser?.inviteCode
                        toast = "已复制邀请码"
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Palette.primary)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(Capsule().fill(.white))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.brandGradient))

                // 输入对方邀请码
                VStack(alignment: .leading, spacing: 10) {
                    Text("输入对方邀请码")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Palette.subtle)
                    HStack {
                        TextField("如 JAGAT-XXXX", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        if !code.isEmpty {
                            Button { code = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(Theme.Palette.subtle)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.groupedBackground))
                }

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
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.primary))
                    .foregroundColor(.white)
                }
                .disabled(code.count < 4 || session.isBusy)
                .opacity(code.count < 4 ? 0.6 : 1)

                if let toast {
                    Text(toast).font(.footnote).foregroundColor(Theme.Palette.mint)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
