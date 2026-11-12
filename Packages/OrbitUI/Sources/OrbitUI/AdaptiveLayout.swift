import Foundation

/// Layout depends on the live window, never a device name or UIScreen.main.
public struct OrbitAdaptiveLayout {
    public let usesSidePanel: Bool
    public let panelWidth: CGFloat
    public let messagePanelHeight: CGFloat

    public init(size: CGSize, accessibilityText: Bool = false) {
        let width = max(0, size.width)
        let height = max(0, size.height)
        usesSidePanel = width >= 760 && height >= 500 && !accessibilityText
        panelWidth = usesSidePanel ? min(420, max(320, width * 0.4)) : width
        messagePanelHeight = usesSidePanel || accessibilityText || height < 500
            ? height
            : min(height, max(360, height * 0.78))
    }
}
