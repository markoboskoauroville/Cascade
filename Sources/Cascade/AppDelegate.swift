import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    private var statusItem: NSStatusItem!
    private static let letterColor = NSColor.white
    /// Two letters, not one, so it cannot be mistaken for the C that FKeys
    /// shows when F1-F12 are in media mode.
    private static let letter = "CA"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.attributedTitle = NSAttributedString(
            string: AppDelegate.letter,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                         .foregroundColor: AppDelegate.letterColor])
        item.button?.toolTip = """
            Cascade — window arranger
            Splits the screen you are pointing at down the middle and cascades \
            its windows so every title bar stays reachable. Pairs with AutoRaise.
            Click to cascade this screen. Click again to put it back exactly \
            as it was.
            Shortcut: none. Option click re-cascades without restoring first.
            Only the screen under the pointer is touched.
            """
        item.button?.target = self
        item.button?.action = #selector(buttonClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        if !AXBridge.isTrusted { promptForTrust() }
    }

    // MARK: - Actions

    @objc private func buttonClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            // Option forces a fresh cascade. Without it the click alternates,
            // so re-cascading after moving a couple of windows by hand would
            // otherwise mean restoring first and clicking twice more.
            act(forceCascade: event?.modifierFlags.contains(.option) == true)
        }
    }

    private func act(forceCascade: Bool = false) {
        switch Arranger.toggleScreenUnderPointer(forceCascade: forceCascade) {
        case .cascaded, .restored:
            break                      // the windows moving is the feedback
        case .nothingToArrange:
            NSSound.beep()
        case .notTrusted:
            promptForTrust()
        }
    }

    private func promptForTrust() {
        let alert = NSAlert()
        alert.messageText = "Cascade needs Accessibility permission"
        alert.informativeText = """
            Moving another app's windows is exactly what macOS puts behind the \
            Accessibility permission, so there is no way around it.

            Open System Settings, Privacy & Security, Accessibility, and switch \
            Cascade on. If it is already on, switch it off and on again: after \
            an update macOS keeps the old entry but stops trusting it, and a \
            stale entry looks identical to a working one.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            AXBridge.requestTrust()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = NSMenu()
        // Without this AppKit re-enables every item that has a valid target and
        // action, which would silently undo the disabled state below.
        menu.autoenablesItems = false

        let canRestore = Arranger.canRestoreScreenUnderPointer()

        let cascadeItem = menu.addItem(withTitle: "Cascade this screen",
                                       action: #selector(menuCascade), keyEquivalent: "")
        cascadeItem.target = self

        let restoreItem = menu.addItem(withTitle: "Put this screen back",
                                       action: #selector(menuRestore), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.isEnabled = canRestore

        menu.addItem(.separator())

        let trust = menu.addItem(
            withTitle: AXBridge.isTrusted ? "Accessibility granted" : "Grant Accessibility…",
            action: #selector(menuTrust), keyEquivalent: "")
        trust.target = self
        trust.isEnabled = !AXBridge.isTrusted

        let login = menu.addItem(withTitle: "Open at login",
                                 action: #selector(menuLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        let about = menu.addItem(withTitle: "About Cascade", action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        let quit = menu.addItem(withTitle: "Quit Cascade", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuCascade() { act(forceCascade: true) }
    @objc private func menuRestore() { act() }
    @objc private func menuTrust() { promptForTrust() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuLogin() { LoginItem.set(enabled: !LoginItem.isEnabled) }

    @objc private func menuAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Cascade",
            .credits: NSAttributedString(
                string: "Splits the screen you are pointing at in two and cascades "
                      + "its windows so every title bar stays reachable.\n"
                      + "Click again to put your own arrangement back.\n"
                      + "Made to pair with AutoRaise.",
                attributes: [.font: NSFont.systemFont(ofSize: 11)])
        ])
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Cascade: login item change failed: \(error.localizedDescription)")
        }
    }
}
