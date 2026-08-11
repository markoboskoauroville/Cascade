import AppKit

/// One window's state before Cascade touched it.
struct WindowSnapshot {
    let element: AXUIElement
    let frame: CGRect
    /// Position in the front to back stacking order at snapshot time.
    /// nil when it could not be matched, which only costs stacking accuracy.
    let stackRank: Int?
}

/// Remembers what each screen looked like before it was cascaded.
///
/// Kept per display rather than globally, so cascading the laptop screen never
/// discards the way to get the external screen back.
@MainActor
enum Snapshots {
    private static var stored: [CGDirectDisplayID: [WindowSnapshot]] = [:]

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func has(_ id: CGDirectDisplayID) -> Bool {
        guard let entries = stored[id] else { return false }
        // A snapshot whose windows have all been closed is not worth offering.
        return entries.contains { AXBridge.stillExists($0.element) }
    }

    static func save(_ entries: [WindowSnapshot], for id: CGDirectDisplayID) {
        stored[id] = entries
    }

    /// Hands back the snapshot and forgets it, so the button alternates:
    /// cascade, restore, cascade, restore.
    static func take(_ id: CGDirectDisplayID) -> [WindowSnapshot]? {
        defer { stored[id] = nil }
        return stored[id]
    }

    static func clear(_ id: CGDirectDisplayID) {
        stored[id] = nil
    }
}
