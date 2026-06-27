import SwiftUI

// MARK: - Banner

public struct ToastBanner: View {
    public let message: String
    public var icon: String

    public init(message: String, icon: String = "checkmark.circle.fill") {
        self.message = message
        self.icon = icon
    }

    public var body: some View {
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
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }

    private var iconColor: Color {
        if icon.contains("xmark") || icon.contains("exclamation") { return .red }
        if icon.contains("check") { return Color(hex: 0x2ECC71) }
        return .white
    }
}

// MARK: - Modifier

/// Wraps content in a ZStack and floats the toast on top,
/// within the safe-area region so it clears the status bar.
public struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var icon: String

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let msg = message {
                ToastBanner(message: msg, icon: icon)
                    .padding(.top, 8)
                    .zIndex(9999)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: message != nil)
    }
}

// MARK: - View helper

public extension View {
    func autoToast(
        _ message: Binding<String?>,
        duration: Double = 2.2,
        icon: String = "checkmark.circle.fill"
    ) -> some View {
        modifier(ToastModifier(message: message, icon: icon))
            .onChange(of: message.wrappedValue) { val in
                guard val != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation { message.wrappedValue = nil }
                }
            }
    }
}
