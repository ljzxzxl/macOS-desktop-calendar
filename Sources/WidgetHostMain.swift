import AppKit
import SwiftUI
import WidgetKit

private enum HostConstants {
    static let widgetKind = "com.allen.desktopcalendar.widget"
    /// 小组件扩展容器内的设置文件；扩展侧读取逻辑见 CalendarData.swift 的 WidgetSettings。
    static var settingsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(widgetKind)/Data/Library/Application Support/DesktopCalendar", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func readWeatherCity() -> String {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let city = json["weatherCity"] as? String
        else {
            return ""
        }
        return city
    }

    static func writeWeatherCity(_ city: String) {
        let url = settingsURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: ["weatherCity": city]) {
            try? data.write(to: url, options: .atomic)
        }
    }
    static let readmeURL = URL(string: "https://github.com/ljzxzxl/macOS-desktop-calendar#readme")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/ljzxzxl/macOS-desktop-calendar/releases/latest")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

private struct ReleaseInfo: Equatable {
    let version: String
    let url: URL
}

private enum UpdateState: Equatable {
    case checking
    case upToDate
    case available(ReleaseInfo)
    case failed
}

@MainActor
private final class GuideModel: ObservableObject {
    /// nil 表示尚未查询到结果。
    @Published var addedFamilies: [WidgetFamily]?
    @Published var updateState: UpdateState = .checking
    @Published var refreshed = false
    @Published var weatherCity = HostConstants.readWeatherCity()

    let isTranslocated = Bundle.main.bundlePath.contains("/AppTranslocation/")
    private var pollTask: Task<Void, Never>?

    func start() {
        guard !isTranslocated else {
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        // 用户按引导添加组件时窗口仍开着，轮询可以让状态即时变成“已添加”。
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateWidgetStatus()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        checkForUpdate()
    }

    func stop() {
        pollTask?.cancel()
    }

    /// 城市留空则由天气接口按出口 IP 判断。
    func saveWeatherCity() {
        let city = weatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        weatherCity = city
        HostConstants.writeWeatherCity(city)
        WidgetCenter.shared.reloadTimelines(ofKind: HostConstants.widgetKind)
    }

    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        refreshed = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            refreshed = false
        }
    }

    private func updateWidgetStatus() async {
        let families: [WidgetFamily]? = await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                let infos = try? result.get()
                continuation.resume(returning: infos?.filter { $0.kind == HostConstants.widgetKind }.map(\.family))
            }
        }
        if let families, families != addedFamilies {
            addedFamilies = families
        }
    }

    func checkForUpdate() {
        guard !isTranslocated, updateTask == nil else {
            return
        }
        updateState = .checking
        updateTask = Task {
            let started = Date()
            let result = await Self.fetchLatestRelease()
            // 请求很快时稍作停留，让手动检查能看到“正在检查”的反馈。
            let remaining = 0.6 - Date().timeIntervalSince(started)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            if let release = result {
                updateState = release.version.compare(HostConstants.version, options: .numeric) == .orderedDescending
                    ? .available(release)
                    : .upToDate
            } else {
                updateState = .failed
            }
            updateTask = nil
        }
    }

    private var updateTask: Task<Void, Never>?

    private static func fetchLatestRelease() async -> ReleaseInfo? {
        var request = URLRequest(url: HostConstants.latestReleaseAPI, timeoutInterval: 8)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else {
            return nil
        }
        return ReleaseInfo(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url: page)
    }
}

private struct GuideView: View {
    @ObservedObject var model: GuideModel

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                Text("桌面日历")
                    .font(.system(size: 20, weight: .semibold))
                Text("版本 \(HostConstants.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if model.isTranslocated {
                translocationNotice
            } else {
                statusCard
                steps
                weatherRow
                updateRow
            }

            buttons
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .frame(width: 420)
    }

    private var translocationNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("请先移动到「应用程序」文件夹", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
            Text("当前是直接从安装包或“下载”文件夹运行的，桌面小组件无法正常显示。请退出后把“桌面日历”拖到「应用程序」文件夹，再从那里打开。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var statusCard: some View {
        let families = model.addedFamilies
        let added = !(families ?? []).isEmpty
        HStack(spacing: 10) {
            if families == nil {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(added ? Color.green : Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle(families))
                    .font(.system(size: 13, weight: .semibold))
                Text(added ? "小组件会自动同步节假日安排，本应用无需保持打开。" : "按下面的步骤把小组件添加到桌面。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            (added ? Color.green : Color.accentColor).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func statusTitle(_ families: [WidgetFamily]?) -> String {
        guard let families else {
            return "正在检查桌面小组件…"
        }
        guard !families.isEmpty else {
            return "还没有添加到桌面"
        }
        let names = Set(families.map(familyName)).sorted().joined(separator: "、")
        return "已在桌面添加 \(families.count) 个小组件（\(names)）"
    }

    private func familyName(_ family: WidgetFamily) -> String {
        switch family {
        case .systemMedium: return "中号"
        case .systemLarge: return "大号"
        default: return "其他尺寸"
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("添加方法")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            step(1, "cursorarrow.rays", "在桌面空白处点右键，选择“编辑小组件…”")
            step(2, "magnifyingglass", "在小组件库中搜索“桌面日历”")
            step(3, "hand.draw", "把中号或大号组件拖到桌面上")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(_ number: Int, _ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
        }
    }

    private var weatherRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .foregroundStyle(.secondary)
            Text("天气城市")
                .font(.system(size: 12))
            TextField("自动", text: $model.weatherCity)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(width: 110)
                .onSubmit { model.saveWeatherCity() }
            Text("留空自动判断")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("保存") {
                model.saveWeatherCity()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var updateRow: some View {
        HStack(spacing: 8) {
            switch model.updateState {
            case .checking:
                ProgressView().controlSize(.small)
                Text("正在检查更新…")
                    .foregroundStyle(.secondary)
            case .upToDate:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("已是最新版本")
            case .available(let release):
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("有新版本 \(release.version)")
                    .fontWeight(.medium)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("检查更新失败，请检查网络")
            }
            Spacer(minLength: 0)
            if case .available(let release) = model.updateState {
                Link("前往下载", destination: release.url)
            } else {
                Button("检查更新") {
                    model.checkForUpdate()
                }
                .buttonStyle(.link)
                .disabled(model.updateState == .checking)
            }
        }
        .font(.system(size: 12))
        .frame(height: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var buttons: some View {
        HStack {
            Link("使用说明", destination: HostConstants.readmeURL)
                .font(.system(size: 12))
            Spacer()
            if !model.isTranslocated, !(model.addedFamilies ?? []).isEmpty {
                Button(model.refreshed ? "已刷新" : "刷新小组件") {
                    model.refreshWidgets()
                }
                .disabled(model.refreshed)
            }
            Button(model.isTranslocated ? "退出" : "完成") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

@MainActor
private final class WidgetHostDelegate: NSObject, NSApplicationDelegate {
    private let model = GuideModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.mainMenu = makeMainMenu()

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: GuideView(model: model))
        window.setContentSize(window.contentView?.fittingSize ?? NSSize(width: 420, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApplication.shared.activate(ignoringOtherApps: true)
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    @objc private func checkForUpdate(_ sender: Any?) {
        model.checkForUpdate()
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于桌面日历", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let updateItem = appMenu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdate(_:)), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏桌面日历", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出桌面日历", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}

@main
@MainActor
private struct WidgetHostMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = WidgetHostDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
