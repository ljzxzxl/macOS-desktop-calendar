import AppKit
import WidgetKit

@MainActor
private final class WidgetHostDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@main
@MainActor
private struct WidgetHostMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = WidgetHostDelegate()
        application.delegate = delegate
        application.run()
    }
}
