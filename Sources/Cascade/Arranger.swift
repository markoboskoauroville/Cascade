import AppKit

enum ArrangeResult {
    case cascaded(count: Int)
    case restored(count: Int)
    case nothingToArrange
    case notTrusted
}

@MainActor
enum Arranger {

    /// Arranges only the screen the pointer is on. The pointer is on the menu
    /// bar you just clicked, so clicking the button on a given screen acts on
    /// that screen and leaves the other one untouched.
    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    /// True when the next plain click on this screen would restore rather than
    /// cascade. Used to label the menu honestly.
    static func canRestoreScreenUnderPointer() -> Bool {
        guard let screen = screenUnderPointer(),
              let id = Snapshots.displayID(of: screen) else { return false }
        return Snapshots.has(id)
    }

    /// The button alternates. First click cascades and remembers what was
    /// there; second click puts it all back and forgets. Pass `forceCascade`
    /// to re-cascade without restoring first.
    @discardableResult
    static func toggleScreenUnderPointer(forceCascade: Bool = false) -> ArrangeResult {
        guard AXBridge.isTrusted else { return .notTrusted }
        guard let screen = screenUnderPointer(),
              let id = Snapshots.displayID(of: screen) else { return .nothingToArrange }

        if !forceCascade, Snapshots.has(id) {
            return restore(id)
        }
        return cascade(screen: screen, id: id)
    }

    // MARK: - Cascade

    private static func cascade(screen: NSScreen, id: CGDirectDisplayID) -> ArrangeResult {
        // visibleFrame already excludes the menu bar and the Dock.
        let area = AXBridge.axRect(fromCocoa: screen.visibleFrame)

        // A window belongs to the screen its centre sits on. Using a corner
        // would claim windows that merely overlap the edge.
        let windows = AXBridge.allWindows().filter {
            area.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
        }
        guard !windows.isEmpty else { return .nothingToArrange }

        // Left to right by current position, so windows broadly stay on the
        // side of the screen you already had them on.
        let ordered = windows.sorted { $0.frame.minX < $1.frame.minX }

        // Record everything BEFORE moving anything. Reading afterwards would
        // capture the cascade itself and undo would become a no-op.
        let stacking = AXBridge.frontToBackOrder()
        let snapshot = ordered.map { window in
            WindowSnapshot(element: window.element,
                           frame: window.frame,
                           stackRank: AXBridge.stackRank(pid: window.pid,
                                                         frame: window.frame,
                                                         in: stacking))
        }
        Snapshots.save(snapshot, for: id)

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

        return .cascaded(count: ordered.count)
    }

    // MARK: - Restore

    private static func restore(_ id: CGDirectDisplayID) -> ArrangeResult {
        guard let snapshot = Snapshots.take(id) else { return .nothingToArrange }

        // Windows closed since the cascade are skipped rather than treated as
        // an error. Anything opened since is left alone: it was never ours.
        let living = snapshot.filter { AXBridge.stillExists($0.element) }
        guard !living.isEmpty else { return .nothingToArrange }

        for entry in living {
            AXBridge.setFrame(entry.frame, on: entry.element)
        }

        // Raise back to front, so the window that was frontmost ends up
        // frontmost again. Windows that could not be ranked are raised first,
        // which leaves them behind everything that was ranked.
        let ranked = living.filter { $0.stackRank != nil }
                           .sorted { ($0.stackRank ?? 0) > ($1.stackRank ?? 0) }
        let unranked = living.filter { $0.stackRank == nil }
        for entry in unranked + ranked {
            AXBridge.raise(entry.element)
        }

        return .restored(count: living.count)
    }
}
