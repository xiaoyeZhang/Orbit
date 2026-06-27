import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Animation presets
public extension Animation {
    static var jelly: Animation        { .spring(response: 0.42, dampingFraction: 0.55) }
    static var smoothSpring: Animation { .spring(response: 0.45, dampingFraction: 0.86) }
    static var snappy: Animation       { .spring(response: 0.30, dampingFraction: 0.72) }
    static var bouncy: Animation       { .spring(response: 0.50, dampingFraction: 0.60) }
}

// MARK: - Haptics
public enum Haptics {
    public static func light()     { impact(.light) }
    public static func medium()    { impact(.medium) }
    public static func rigid()     { impact(.rigid) }
    public static func soft()      { impact(.soft) }
    public static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

// MARK: - PressableButtonStyle
public struct PressableStyle: ButtonStyle {
    public var scale: CGFloat = 0.94
    public var haptic: Bool = true
    public init(scale: CGFloat = 0.94, haptic: Bool = true) {
        self.scale = scale; self.haptic = haptic
    }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { Haptics.light() }
            }
    }
}
public extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
    static func pressable(scale: CGFloat) -> PressableStyle { PressableStyle(scale: scale) }
}

// MARK: - Breathing
public struct Breathing: ViewModifier {
    @State private var on = false
    public var scale: CGFloat; public var duration: Double
    public init(scale: CGFloat = 1.04, duration: Double = 2.0) {
        self.scale = scale; self.duration = duration
    }
    public func body(content: Content) -> some View {
        content.scaleEffect(on ? scale : 1).onAppear {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { on = true }
        }
    }
}
public extension View {
    func breathing(scale: CGFloat = 1.04, duration: Double = 2.0) -> some View {
        modifier(Breathing(scale: scale, duration: duration))
    }
}

// MARK: - PulseRing
public struct PulseRing: View {
    public var color: Color; public var size: CGFloat
    public var lineWidth: CGFloat = 2.5; public var maxScale: CGFloat = 2.4; public var dual: Bool = false
    @State private var a1 = false; @State private var a2 = false
    public init(color: Color, size: CGFloat, lineWidth: CGFloat = 2.5,
                maxScale: CGFloat = 2.4, dual: Bool = false) {
        self.color = color; self.size = size; self.lineWidth = lineWidth
        self.maxScale = maxScale; self.dual = dual
    }
    public var body: some View {
        ZStack {
            ring(animating: a1)
            if dual { ring(animating: a2) }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) { a1 = true }
            if dual {
                withAnimation(.easeOut(duration: 2.0).delay(1.0).repeatForever(autoreverses: false)) { a2 = true }
            }
        }
    }
    private func ring(animating: Bool) -> some View {
        Circle().stroke(color.opacity(0.55), lineWidth: lineWidth)
            .frame(width: size, height: size)
            .scaleEffect(animating ? maxScale : 0.9).opacity(animating ? 0 : 0.8)
    }
}

// MARK: - OnlineDot (pulse version)
public struct OnlineDot: View {
    public var size: CGFloat; public var color: Color
    @State private var pulsing = false
    public init(size: CGFloat = 10, color: Color = Theme.Palette.online) {
        self.size = size; self.color = color
    }
    public var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.35)).frame(width: size * 2.2)
                .scaleEffect(pulsing ? 1 : 0.5).opacity(pulsing ? 0 : 0.9)
            Circle().fill(color).frame(width: size)
            Circle().strokeBorder(.white, lineWidth: 1.5).frame(width: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) { pulsing = true }
        }
    }
}

// MARK: - AuroraBackground
public struct AuroraBackground: View {
    public var colors: [Color]
    @State private var t = false
    public init(colors: [Color] = [Theme.Palette.primary, Theme.Palette.accent,
                                    Theme.Palette.sky, Theme.Palette.sunshine]) {
        self.colors = colors
    }
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Theme.Palette.primaryDark
                blob(colors[0],               pos: t ? .init(x:0.2,y:0.2)  : .init(x:0.75,y:0.15), size: w*1.1, in: geo.size)
                blob(colors[1 % colors.count],pos: t ? .init(x:0.85,y:0.55): .init(x:0.2,y:0.45),  size: w*0.95,in: geo.size)
                blob(colors[2 % colors.count],pos: t ? .init(x:0.3,y:0.85) : .init(x:0.7,y:0.9),   size: w*1.0, in: geo.size)
                blob(colors[3 % colors.count],pos: t ? .init(x:0.6,y:0.4)  : .init(x:0.4,y:0.6),   size: w*0.8, in: geo.size)
            }
            .onAppear { withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { t.toggle() } }
        }
        .ignoresSafeArea()
    }
    private func blob(_ c: Color, pos: CGPoint, size: CGFloat, in container: CGSize) -> some View {
        Circle().fill(c).frame(width: size, height: size)
            .position(x: container.width * pos.x, y: container.height * pos.y)
            .blur(radius: 70).opacity(0.85)
    }
}

// MARK: - PopIn
public struct PopIn: ViewModifier {
    @State private var shown = false
    public var delay: Double
    public init(delay: Double = 0) { self.delay = delay }
    public func body(content: Content) -> some View {
        content.scaleEffect(shown ? 1 : 0.75).opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.jelly.delay(delay)) { shown = true } }
    }
}
public extension View {
    func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
}

// MARK: - StaggeredAppear
public struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var shown = false
    public init(index: Int) { self.index = index }
    public func body(content: Content) -> some View {
        content.offset(y: shown ? 0 : 22).opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.82)
                    .delay(Double(index) * 0.055)) { shown = true }
            }
    }
}
public extension View {
    func staggeredAppear(index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
}

// MARK: - FloatEffect
public struct FloatEffect: ViewModifier {
    @State private var up = false
    public var amount: CGFloat; public var duration: Double
    public init(amount: CGFloat = 7, duration: Double = 3.2) {
        self.amount = amount; self.duration = duration
    }
    public func body(content: Content) -> some View {
        content.offset(y: up ? -amount : 0)
            .onAppear { withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { up = true } }
    }
}
public extension View {
    func floating(amount: CGFloat = 7, duration: Double = 3.2) -> some View {
        modifier(FloatEffect(amount: amount, duration: duration))
    }
}

// MARK: - MessageAppear
public struct MessageAppear: ViewModifier {
    let isMine: Bool
    @State private var shown = false
    public init(isMine: Bool) { self.isMine = isMine }
    public func body(content: Content) -> some View {
        content
            .offset(x: shown ? 0 : (isMine ? 30 : -30))
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.88, anchor: isMine ? .trailing : .leading)
            .onAppear { withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { shown = true } }
    }
}
public extension View {
    func messageAppear(isMine: Bool) -> some View { modifier(MessageAppear(isMine: isMine)) }
}

// MARK: - Shimmer
public struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1
    public var color: Color
    public init(color: Color = .white.opacity(0.4)) { self.color = color }
    public func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                let w = geo.size.width
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: color,  location: 0.4),
                    .init(color: .clear, location: 0.8),
                ], startPoint: .init(x: phase, y: 0.5), endPoint: .init(x: phase + 1, y: 0.5))
                .frame(width: w * 2.5).offset(x: -w * 0.75)
            }
            .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { phase = 1.5 }
        }
    }
}
public extension View {
    func shimmer(_ color: Color = .white.opacity(0.4)) -> some View { modifier(ShimmerEffect(color: color)) }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
