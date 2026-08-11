import AppKit

@main
struct CascadeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate.shared
        app.delegate = delegate
        app.run()
    }
}
