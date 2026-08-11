import AppKit

enum ArrangeResult {
    case arranged(count: Int, screen: String)
    case nothingToArrange
    case notTrusted
}

@MainActor
enum Arranger {

    /// Arranges only the screen the pointer is on. The pointer is on the menu
    /// bar you just clicked, so clicking the button on a given screen arranges
    /// that screen and leaves the other one untouched.
    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    @discardableResult
    static func arrangeScreenUnderPointer() -> ArrangeResult {
        guard AXBridge.isTrusted else { return .notTrusted }
        guard let screen = screenUnderPointer() else { return .nothingToArrange }

        // visibleFrame already excludes the menu bar and the Dock.
        let area = AXBridge.axRect(fromCocoa: screen.visibleFrame)

        // A window belongs to the screen its centre sits on. Using a corner
        // would claim windows that merely overlap the edge.
        let windows = AXBridge.allWindows().filter { area.contains(CGPoint(x: $0.frame.midX,
                                                                          y: $0.frame.midY)) }
        guard !windows.isEmpty else { return .nothingToArrange }

        // Left to right by current position, so windows broadly stay on the
        // side of the screen you already had them on.
        let ordered = windows.sorted { $0.frame.minX < $1.frame.minX }
        let frames = CascadeLayout.frames(count: ordered.count, in: area)

        for (window, frame) in zip(ordered, frames) {
            AXBridge.setFrame(frame, on: window.element)
        }

        // Raising in order makes the visual stack match the cascade: each
        // window sits above the one up and to its left, leaving that one's
        // title strip exposed. Setting a frame does not change z-order, so
        // without this pass the cascade looks shuffled.
        for window in ordered {
            AXBridge.raise(window.element)
        }

        let name = screen.localizedName
        return .arranged(count: ordered.count, screen: name)
    }
}
