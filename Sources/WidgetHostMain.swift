import AppKit
import WidgetKit

@MainActor
private final class WidgetHostDelegate: NSObject, NSApplicationDelegate {
    private static let installGuideShownKey = "installGuideShown"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 从未移动的下载位置打开时，系统会把应用随机挪到临时路径运行，组件注册到该路径后会失效成灰色占位。
        if Bundle.main.bundlePath.contains("/AppTranslocation/") {
            showAlert(
                title: "请先移动到「应用程序」文件夹",
                message: "请将“桌面日历”拖到「应用程序」文件夹后再打开，否则桌面小组件无法正常显示。"
            )
            NSApplication.shared.terminate(nil)
            return
        }

        WidgetCenter.shared.reloadAllTimelines()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.installGuideShownKey) {
            defaults.set(true, forKey: Self.installGuideShownKey)
            showAlert(
                title: "桌面日历已安装",
                message: "在桌面空白处右键，选择“编辑小组件…”，搜索“桌面日历”，把中号或大号组件拖到桌面即可。\n\n本应用没有窗口，之后无需再打开。"
            )
        }
        NSApplication.shared.setActivationPolicy(.prohibited)
    }

    private func showAlert(title: String, message: String) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
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
