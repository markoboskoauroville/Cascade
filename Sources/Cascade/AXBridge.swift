import AppKit
import ApplicationServices

/// A window belonging to some other application, reachable through the
/// Accessibility API.
struct ManagedWindow {
    let element: AXUIElement
    let appName: String
    let frame: CGRect          // in AX coordinates: origin top left, y grows downward
}

enum AXBridge {

    // MARK: - Permission

    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    // MARK: - Coordinates
    //
    // Cocoa puts the origin at the bottom left of the primary screen with y
    // growing upward. The Accessibility API puts it at the top left with y
    // growing downward. Every frame crossing that boundary must be flipped or
    // windows land on the wrong screen, or off screen entirely.

    private static var globalTop: CGFloat {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main!).frame.maxY
    }

    static func axRect(fromCocoa rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: globalTop - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cocoaRect(fromAX rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: globalTop - rect.maxY, width: rect.width, height: rect.height)
    }

    // MARK: - Reading windows

    /// Every ordinary, movable window currently on screen.
    static func allWindows() -> [ManagedWindow] {
        var result: [ManagedWindow] = []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != ownPID && !app.isHidden {

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            // An unresponsive app would otherwise block the whole pass.
            AXUIElementSetMessagingTimeout(axApp, 0.4)

            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement]
            else { continue }

            for window in windows {
                guard isArrangeable(window), let frame = frame(of: window) else { continue }
                guard frame.width > 80, frame.height > 80 else { continue }
                result.append(ManagedWindow(element: window,
                                            appName: app.localizedName ?? "",
                                            frame: frame))
            }
        }
        return result
    }

    private static func isArrangeable(_ window: AXUIElement) -> Bool {
        if boolAttribute(window, kAXMinimizedAttribute) == true { return false }
        // A full screen window cannot be moved or resized, and trying makes the
        // Accessibility API hang for a moment.
        if boolAttribute(window, "AXFullScreen") == true { return false }

        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String, subrole != kAXStandardWindowSubrole as String {
            return false
        }

        // Panels, pickers and some utility windows report a position but refuse
        // to move. Asking first avoids leaving them half arranged.
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        guard AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        return true
    }

    private static func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &ref) == .success else { return nil }
        return (ref as? Bool)
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: point, size: size)
    }

    // MARK: - Writing windows

    /// Position is set, then size, then position again. Many apps clamp the
    /// position against their current size, so a single pass leaves the window
    /// in the wrong place whenever it is growing.
    static func setFrame(_ frame: CGRect, on window: AXUIElement) {
        var point = frame.origin
        var size = frame.size

        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
}
