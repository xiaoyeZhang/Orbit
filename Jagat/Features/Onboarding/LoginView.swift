import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var logoShown = false

    var body: some View {
        ZStack {
            // 流动极光底
            AuroraBackground()

            VStack(spacing: 0) {
                Spacer()
                logoSection
                Spacer()
                formSection
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: codeSent)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.15)) {
                logoShown = true
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 22) {
            ZStack {
                // 外光晕
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 140, height: 140)
                    .blur(radius: 4)
                    .floating(amount: 5, duration: 3.8)

                // 扩散脉冲环（双环）
                PulseRing(color: .white, size: 106, lineWidth: 1.8, maxScale: 2.0, dual: true)

                // 图标背景圆
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.38), lineWidth: 1)
                    )

                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(logoShown ? 1 : 0.55)
            .opacity(logoShown ? 1 : 0)
            .floating(amount: 8, duration: 4.0)

            VStack(spacing: 10) {
                Text("Orbit")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("实时分享，随时同在")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .opacity(logoShown ? 1 : 0)
            .offset(y: logoShown ? 0 : 20)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 表单

    private var formSection: some View {
        VStack(spacing: 13) {
            // 手机号栏
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("🇨🇳")
                        .font(.system(size: 18))
                    Text("+86")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 1, height: 20)
                TextField("", text: $phone, prompt:
                    Text("手机号码").foregroundColor(.white.opacity(0.45)))
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                    }
            }

            // 验证码栏
            if codeSent {
                TextField("", text: $code, prompt:
                    Text("输入 6 位验证码").foregroundColor(.white.opacity(0.45)))
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .multilineTextAlignment(.center)
                    .tracking(6)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                            }
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal:   .opacity
                    ))
            }

            // 错误提示
            if let err = session.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // 主按钮
            Button(action: primaryAction) {
                ZStack {
                    if session.isBusy {
                        ProgressView().tint(Theme.Palette.primary)
                    } else {
                        HStack(spacing: 8) {
                            Text(codeSent ? "进入 Orbit" : "获取验证码")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: codeSent ? "arrow.right.circle.fill" : "envelope.fill")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(Theme.Palette.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: Theme.Palette.primary.opacity(0.25), radius: 14, y: 6)
                }
            }
            .buttonStyle(.pressable)
            .disabled(session.isBusy || !canSubmit)
            .opacity(canSubmit ? 1 : 0.52)

            // Mock 提示
            Text("演示模式：任意手机号 + 4 位以上验证码即可登录")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 52)
        .opacity(logoShown ? 1 : 0)
        .offset(y: logoShown ? 0 : 28)
    }

    private var canSubmit: Bool {
        codeSent ? code.count >= 4 : phone.count >= 6
    }

    private func primaryAction() {
        Haptics.medium()
        if codeSent {
            Task { await session.signIn(phone: phone, code: code) }
        } else {
            Task {
                if await session.requestCode(phone: phone) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                        codeSent = true
                    }
                }
            }
        }
    }
}
