import Foundation

/// Runs the same layout policy used by MainTabView without an iOS test host.
@main
enum AdaptiveLayoutTests {
    static func main() {
        let phone = OrbitAdaptiveLayout(size: CGSize(width: 390, height: 760))
        precondition(!phone.usesSidePanel, "A portrait phone must retain a bottom panel")
        precondition(phone.panelWidth == 390)
        precondition(phone.messagePanelHeight <= 760)

        let expanded = OrbitAdaptiveLayout(size: CGSize(width: 900, height: 700))
        precondition(expanded.usesSidePanel, "An expanded window must show map and panel together")
        precondition(expanded.panelWidth >= 320 && expanded.panelWidth <= 420)
        precondition(900 - expanded.panelWidth >= 360, "Map controls need usable width")
        precondition(expanded.messagePanelHeight == 700)

        let narrow = OrbitAdaptiveLayout(size: CGSize(width: 620, height: 700))
        precondition(!narrow.usesSidePanel, "A narrow split window must not squeeze two columns")
        let landscape = OrbitAdaptiveLayout(size: CGSize(width: 844, height: 340))
        precondition(!landscape.usesSidePanel)
        precondition(landscape.messagePanelHeight == 340, "Short windows need a full-height list")

        let accessible = OrbitAdaptiveLayout(size: CGSize(width: 900, height: 700), accessibilityText: true)
        precondition(!accessible.usesSidePanel, "Accessibility text needs a full-width panel")
        precondition(accessible.messagePanelHeight == 700)

        for width in stride(from: 0.0, through: 1400, by: 25) {
            for height in [0.0, 200, 499, 500, 900] {
                let layout = OrbitAdaptiveLayout(size: CGSize(width: width, height: height))
                precondition(layout.panelWidth >= 0 && layout.panelWidth <= width)
                precondition(layout.messagePanelHeight >= 0 && layout.messagePanelHeight <= height)
                if layout.usesSidePanel {
                    precondition(width - layout.panelWidth >= 360)
                }
            }
        }
        print("PASS: portrait, expanded, narrow, short, accessibility and 285 window-size cases")
    }
}
