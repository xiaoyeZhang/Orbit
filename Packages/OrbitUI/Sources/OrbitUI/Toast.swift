import SwiftUI

// MARK: - Toast modifier

public struct ToastModifier: ViewModifier {
    @Binding public var message: String?
    public var icon: String
    public var position: Alignment

    public init(message: Binding<String?>, icon: String = "checkmark.circle.fill", position: Alignment = .top) {
        self._message = message
        self.icon = icon
        self.position = position
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: position) {
                if let msg = message {
                    ToastBanner(message: msg, icon: icon)
                        .padding(.top, position == .top ? 56 : 0)
                        .padding(.bottom, position == .bottom ? 100 : 0)
                        .transition(.move(edge: position == .top ? .top : .bottom).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: message != nil)
    }
}

struct ToastBanner: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }

    private var iconColor: Color {
        if icon.contains("xmark") || icon.contains("exclamation") { return .red }
        if icon.contains("check") { return Color(hex: 0x2ECC71) }
        return .white
    }
}

// MARK: - View helpers

public extension View {
    func toast(_ message: Binding<String?>, icon: String = "checkmark.circle.fill", position: Alignment = .top) -> some View {
        modifier(ToastModifier(message: message, icon: icon, position: position))
    }
}

// MARK: - Auto-dismiss helper

public extension View {
    /// Show a toast for `duration` seconds, then auto-dismiss.
    func autoToast(_ message: Binding<String?>, duration: Double = 2.0, icon: String = "checkmark.circle.fill") -> some View {
        self.toast(message, icon: icon)
            .onChange(of: message.wrappedValue) { val in
                guard val != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation { message.wrappedValue = nil }
                }
            }
    }
}
