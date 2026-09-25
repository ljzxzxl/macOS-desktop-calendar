import SwiftUI
import WidgetKit
import AppIntents
import Foundation
import os

private let performanceLog = Logger(subsystem: "com.allen.desktopcalendar.widget", category: "performance")

private struct WidgetTheme {
    let background: Color
    let border: Color
    let ink: Color
    let mutedInk: Color
    let accent: Color
    let selection: Color
    let holiday: Color
    let workBadge: Color
    let headerBackground: Color
    let headerBorder: Color
    let tagText: Color
    let tagBackground: Color
    let controlBackground: Color
    let controlBorder: Color
    let panelBackground: Color
    let infoText: Color
    let infoBackground: Color
    let infoBorder: Color
    let appearanceIcon: Color
    /// 实心标签（休、班、宜、忌、今天）上的文字颜色。
    let onBadge: Color
    let todayFill: Color
    let restFill: Color
    let outsideMonthOpacity: Double

    static let light = WidgetTheme(
        background: .white,
        border: Color(red: 0.85, green: 0.89, blue: 0.91),
        ink: Color(red: 0.15, green: 0.17, blue: 0.20),
        mutedInk: Color(red: 0.40, green: 0.43, blue: 0.47),
        accent: Color(red: 0.29, green: 0.43, blue: 0.88),
        selection: Color(red: 0.32, green: 0.46, blue: 0.91),
        holiday: Color.red.opacity(0.88),
        workBadge: .gray,
        headerBackground: Color(red: 0.93, green: 0.97, blue: 0.99),
        headerBorder: Color(red: 0.82, green: 0.88, blue: 0.92),
        tagText: Color(red: 0.78, green: 0.22, blue: 0.20),
        tagBackground: Color.red.opacity(0.07),
        controlBackground: Color.white.opacity(0.94),
        controlBorder: Color(red: 0.83, green: 0.87, blue: 0.90),
        panelBackground: Color(red: 0.97, green: 0.97, blue: 0.99),
        infoText: Color.blue.opacity(0.84),
        infoBackground: Color.blue.opacity(0.06),
        infoBorder: Color.blue.opacity(0.20),
        appearanceIcon: Color(red: 0.38, green: 0.42, blue: 0.86),
        onBadge: .white,
        todayFill: Color(red: 0.29, green: 0.43, blue: 0.88).opacity(0.10),
        restFill: Color.red.opacity(0.06),
        outsideMonthOpacity: 0.28
    )

    static let dark = WidgetTheme(
        background: Color(red: 0.12, green: 0.12, blue: 0.13),
        border: Color.white.opacity(0.10),
        ink: Color(red: 0.92, green: 0.93, blue: 0.95),
        mutedInk: Color(red: 0.60, green: 0.63, blue: 0.68),
        accent: Color(red: 0.49, green: 0.62, blue: 1.00),
        selection: Color(red: 0.52, green: 0.65, blue: 1.00),
        holiday: Color(red: 1.00, green: 0.43, blue: 0.41),
        workBadge: Color(red: 0.45, green: 0.47, blue: 0.51),
        headerBackground: Color(red: 0.16, green: 0.19, blue: 0.23),
        headerBorder: Color.white.opacity(0.08),
        tagText: Color(red: 1.00, green: 0.52, blue: 0.49),
        tagBackground: Color.red.opacity(0.18),
        controlBackground: Color.white.opacity(0.08),
        controlBorder: Color.white.opacity(0.12),
        panelBackground: Color(red: 0.16, green: 0.16, blue: 0.18),
        infoText: Color(red: 0.52, green: 0.70, blue: 1.00),
        infoBackground: Color(red: 0.35, green: 0.55, blue: 1.00).opacity(0.18),
        infoBorder: Color(red: 0.52, green: 0.70, blue: 1.00).opacity(0.30),
        appearanceIcon: Color(red: 1.00, green: 0.78, blue: 0.30),
        onBadge: .white,
        todayFill: Color(red: 0.49, green: 0.62, blue: 1.00).opacity(0.20),
        restFill: Color(red: 1.00, green: 0.35, blue: 0.33).opacity(0.14),
        outsideMonthOpacity: 0.35
    )

    /// 桌面被窗口遮挡等情况下，系统会去掉背景并按亮度决定透明度来单色显示组件：
    /// 颜色只保留明暗，纯黑会变成镂空，所以这里只用白色的不同透明度，标签文字用黑色。
    static let monochrome = WidgetTheme(
        background: .clear,
        border: Color.white.opacity(0.18),
        ink: .white,
        mutedInk: Color.white.opacity(0.60),
        accent: .white,
        selection: .white,
        holiday: .white,
        workBadge: Color.white.opacity(0.55),
        headerBackground: Color.white.opacity(0.08),
        headerBorder: Color.white.opacity(0.14),
        tagText: .white,
        tagBackground: Color.white.opacity(0.18),
        controlBackground: Color.white.opacity(0.10),
        controlBorder: Color.white.opacity(0.20),
        panelBackground: Color.white.opacity(0.08),
        infoText: .white,
        infoBackground: Color.white.opacity(0.16),
        infoBorder: Color.white.opacity(0.30),
        appearanceIcon: .white,
        onBadge: .black,
        todayFill: Color.white.opacity(0.28),
        restFill: Color.white.opacity(0.14),
        outsideMonthOpacity: 0.35
    )

    static func resolve(_ colorScheme: ColorScheme, renderingMode: WidgetRenderingMode) -> WidgetTheme {
        guard renderingMode == .fullColor else {
            return monochrome
        }
        return colorScheme == .dark ? dark : light
    }
}

private enum CalendarWidgetConstants {
    static let kind = "com.allen.desktopcalendar.widget"
    static let calendarURL = URL(string: "https://www.baidu.com/s?wd=%E6%97%A5%E5%8E%86")!
}

/// 月份与选中日期只在当天有效，跨天后自动回到今天。
private enum CalendarWidgetState {
    private static let displayedMonthKey = "displayedMonth"
    private static let selectedDateKey = "selectedDate"
    private static let anchorDayKey = "stateAnchorDay"
    private static let legacySelectedMonthKey = "selectedCalendarMonth"
    private static let appearanceKey = "appearanceOverride"

    struct Snapshot {
        let displayedMonth: WidgetDateKey
        let selectedDate: WidgetDateKey
    }

    static func snapshot(today: Date) -> Snapshot {
        let todayKey = WidgetDateKey(today, calendar: .widgetGregorian)
        let defaults = UserDefaults.standard
        guard
            defaults.string(forKey: anchorDayKey) == todayKey.stringValue,
            let month = defaults.string(forKey: displayedMonthKey).flatMap(WidgetDateKey.init(string:)),
            let selected = defaults.string(forKey: selectedDateKey).flatMap(WidgetDateKey.init(string:))
        else {
            return Snapshot(displayedMonth: todayKey.monthStart, selectedDate: todayKey)
        }
        return Snapshot(displayedMonth: month, selectedDate: selected)
    }

    static func move(by monthCount: Int) {
        let calendar = Calendar.widgetGregorian
        let todayKey = WidgetDateKey(Date(), calendar: calendar)
        let current = snapshot(today: Date())
        let month = current.displayedMonth.addingMonths(monthCount)
        let selected: WidgetDateKey
        if month == todayKey.monthStart {
            selected = todayKey
        } else {
            let monthDate = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1, hour: 12))
            let dayCount = monthDate.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 28
            selected = WidgetDateKey(month.year, month.month, min(current.selectedDate.day, dayCount))
        }
        save(displayedMonth: month, selectedDate: selected, today: todayKey)
    }

    static func select(_ date: WidgetDateKey) {
        let todayKey = WidgetDateKey(Date(), calendar: .widgetGregorian)
        save(displayedMonth: date.monthStart, selectedDate: date, today: todayKey)
    }

    static func showToday() {
        let defaults = UserDefaults.standard
        for key in [displayedMonthKey, selectedDateKey, anchorDayKey, legacySelectedMonthKey] {
            defaults.removeObject(forKey: key)
        }
        performanceLog.debug("intent: today")
    }

    /// 手动选择的外观，nil 表示跟随系统；不随日期重置。
    static var appearance: ColorScheme? {
        switch UserDefaults.standard.string(forKey: appearanceKey) {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    static func setAppearance(dark: Bool, systemDark: Bool) {
        let defaults = UserDefaults.standard
        if dark == systemDark {
            defaults.removeObject(forKey: appearanceKey)
        } else {
            defaults.set(dark ? "dark" : "light", forKey: appearanceKey)
        }
        performanceLog.debug("intent: appearance dark=\(dark) system=\(systemDark)")
    }

    private static func save(displayedMonth: WidgetDateKey, selectedDate: WidgetDateKey, today: WidgetDateKey) {
        let defaults = UserDefaults.standard
        defaults.set(displayedMonth.stringValue, forKey: displayedMonthKey)
        defaults.set(selectedDate.stringValue, forKey: selectedDateKey)
        defaults.set(today.stringValue, forKey: anchorDayKey)
        defaults.removeObject(forKey: legacySelectedMonthKey)
        performanceLog.debug("intent: month \(displayedMonth.monthKey, privacy: .public) selected \(selectedDate.stringValue, privacy: .public)")
    }
}

struct PreviousMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "上一个月"
    static let description = IntentDescription("在桌面日历中显示上一个月")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetState.move(by: -1)
        return .result()
    }
}

struct NextMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "下一个月"
    static let description = IntentDescription("在桌面日历中显示下一个月")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetState.move(by: 1)
        return .result()
    }
}

struct TodayIntent: AppIntent {
    static let title: LocalizedStringResource = "回到今天"
    static let description = IntentDescription("让桌面日历重新显示当前月份")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetState.showToday()
        return .result()
    }
}

struct SelectDateIntent: AppIntent {
    static let title: LocalizedStringResource = "选择日期"
    static let description = IntentDescription("在桌面日历中选中某一天并查看当日农历详情")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "日期")
    var date: Int

    init() {}

    init(date: WidgetDateKey) {
        self.date = date.number
    }

    func perform() async throws -> some IntentResult {
        if let key = WidgetDateKey(number: date) {
            CalendarWidgetState.select(key)
        }
        return .result()
    }
}

struct ToggleAppearanceIntent: AppIntent {
    static let title: LocalizedStringResource = "切换浅色或深色"
    static let description = IntentDescription("在浅色与深色之间切换桌面日历，切回与系统一致时恢复跟随系统")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "深色")
    var dark: Bool

    @Parameter(title: "系统为深色")
    var systemDark: Bool

    init() {}

    init(dark: Bool, systemDark: Bool) {
        self.dark = dark
        self.systemDark = systemDark
    }

    func perform() async throws -> some IntentResult {
        CalendarWidgetState.setAppearance(dark: dark, systemDark: systemDark)
        return .result()
    }
}

struct WeatherDay: Codable, Equatable {
    let condition: String
    let iconKey: String
    let high: Int
    let low: Int
}

/// 百度天气（与日历同源的 opendata 接口，resource_id=4982）的精简快照。
struct WeatherSnapshot: Codable, Equatable {
    let location: String
    let temperature: Int
    let condition: String
    let iconKey: String
    let aqi: Int?
    let aqiLevel: String?
    /// 以 yyyymmdd 为键的逐日预报，覆盖今天起约 15 天。
    let forecast: [Int: WeatherDay]

    /// 百度的天气代号为拼音（如 yin、zhenyu_ye），映射为系统天气符号。
    static func symbol(for iconKey: String) -> String {
        let night = iconKey.hasSuffix("_ye")
        let key = iconKey.replacingOccurrences(of: "_ye", with: "")
        // “duoyun”里也含有“yu”，晴与多云必须先判断，否则会被当成雨。
        if key.contains("qing") { return night ? "moon.stars.fill" : "sun.max.fill" }
        if key.contains("duoyun") { return night ? "cloud.moon.fill" : "cloud.sun.fill" }
        if key.contains("lei") { return "cloud.bolt.rain.fill" }
        if key.contains("yujiaxue") || (key.contains("xue") && key.contains("yu")) { return "cloud.sleet.fill" }
        if key.contains("xue") { return "cloud.snow.fill" }
        if key.contains("baoyu") || key.contains("dayu") { return "cloud.heavyrain.fill" }
        if key.contains("zhenyu") { return night ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill" }
        if key.contains("xiaoyu") { return "cloud.drizzle.fill" }
        if key.contains("yu") { return "cloud.rain.fill" }
        if key.contains("wu") { return "cloud.fog.fill" }
        if key.contains("mai") { return "sun.haze.fill" }
        if key.contains("sha") || key.contains("chen") { return "sun.dust.fill" }
        return "cloud.fill"
    }
}

/// 下一个法定假期；dayIndex 不为 nil 表示今天正处于该假期中的第几天。
private struct HolidayInfo {
    let name: String
    let year: Int
    let daysUntil: Int
    let length: Int
    let dayIndex: Int?
}

private enum WorkReminder: Equatable {
    case today
    case tomorrow(weekday: String)

    var title: String {
        switch self {
        case .today: return "今天补班"
        case .tomorrow: return "明天补班"
        }
    }
}

private struct DayDetail {
    let dateTitle: String
    /// 例如“9月 · 周四 · 今天”，用于中号左侧详情。
    let shortTitle: String
    let hasFestival: Bool
    let festivals: String
    let lunarTitle: String
    let ganzhi: String
    let suit: String
    let avoid: String
}

private struct WidgetCalendarModel {
    static let shared = WidgetCalendarModel()

    let gregorian = Calendar.widgetGregorian
    let chinese: Calendar = {
        var chinese = Calendar(identifier: .chinese)
        chinese.locale = Locale(identifier: "zh_CN")
        chinese.timeZone = .autoupdatingCurrent
        return chinese
    }()

    private let officialHolidays = ["元旦", "春节", "清明", "劳动节", "端午节", "中秋节", "国庆节"]

    func date(for key: WidgetDateKey) -> Date {
        gregorian.date(from: DateComponents(year: key.year, month: key.month, day: key.day, hour: 12)) ?? Date()
    }

    func key(for date: Date) -> WidgetDateKey {
        WidgetDateKey(date, calendar: gregorian)
    }

    func shifted(_ key: WidgetDateKey, by days: Int) -> WidgetDateKey {
        self.key(for: gregorian.date(byAdding: .day, value: days, to: date(for: key)) ?? date(for: key))
    }

    func distance(from start: WidgetDateKey, to end: WidgetDateKey) -> Int {
        gregorian.dateComponents([.day], from: date(for: start), to: date(for: end)).day ?? 0
    }

    func isWeekend(_ key: WidgetDateKey) -> Bool {
        let weekday = gregorian.component(.weekday, from: date(for: key))
        return weekday == 1 || weekday == 7
    }

    func visibleDays(for month: WidgetDateKey) -> [WidgetDateKey] {
        let firstDay = month.monthStart
        let weekday = gregorian.component(.weekday, from: date(for: firstDay))
        let daysFromMonday = (weekday + 5) % 7
        let start = shifted(firstDay, by: -daysFromMonday)
        return (0..<42).map { shifted(start, by: $0) }
    }

    func dayLabel(for key: WidgetDateKey, day: CalendarDay?) -> String {
        if let day, !day.lunarDay.isEmpty {
            if let term = day.terms.first {
                return term
            }
            return day.lunarDay == "初一" ? day.lunarMonthTitle : day.lunarDay
        }
        let lunar = lunarComponents(for: key)
        return lunar.day == 1
            ? lunarMonthName(lunar.month, isLeap: lunar.isLeap)
            : lunarDayName(lunar.day)
    }

    func detail(for key: WidgetDateKey, day: CalendarDay?, today: WidgetDateKey) -> DayDetail {
        let offset = distance(from: today, to: key)
        let relative: String
        switch offset {
        case 0: relative = "今天"
        case 1: relative = "明天"
        case -1: relative = "昨天"
        case let value where value > 0: relative = "\(value)天后"
        default: relative = "\(-offset)天前"
        }
        let dateTitle = "\(key.month)月\(key.day)日 \(weekdayName(for: key)) · \(relative)"
        let shortTitle = "\(key.month)月 · \(shortWeekdayName(for: key)) · \(relative)"

        guard let day, !day.lunarDay.isEmpty else {
            let lunar = lunarComponents(for: key)
            return DayDetail(
                dateTitle: dateTitle,
                shortTitle: shortTitle,
                hasFestival: false,
                festivals: "暂无节日",
                lunarTitle: "\(lunarMonthName(lunar.month, isLeap: lunar.isLeap))\(lunarDayName(lunar.day))",
                ganzhi: fallbackYearTitle(for: key),
                suit: "—",
                avoid: "—"
            )
        }

        var festivals = day.festivals
        for term in day.terms where !festivals.contains(term) {
            festivals.insert(term, at: 0)
        }
        return DayDetail(
            dateTitle: dateTitle,
            shortTitle: shortTitle,
            hasFestival: !festivals.isEmpty,
            festivals: festivals.isEmpty ? "暂无节日" : festivals.prefix(3).joined(separator: " · "),
            lunarTitle: "\(day.lunarMonthTitle)\(day.lunarDay)",
            ganzhi: "\(day.ganzhiYear)\(day.animal)年 \(day.ganzhiMonth)月 \(day.ganzhiDay)日",
            suit: day.suit.isEmpty ? "—" : day.suit.prefix(6).joined(separator: "·"),
            avoid: day.avoid.isEmpty ? "—" : day.avoid.prefix(6).joined(separator: "·")
        )
    }

    func countdown(today: WidgetDateKey, days: [WidgetDateKey: CalendarDay]) -> String {
        guard let info = holidayInfo(today: today, days: days) else {
            return "后续假期安排待官方公布"
        }
        if info.dayIndex != nil {
            return "今天是\(info.name)假期 · 共放假\(info.length)天"
        }
        return "距离 \(info.year)年\(info.name) 还有\(info.daysUntil)天 · 放假\(info.length)天"
    }

    func workReminder(today: WidgetDateKey, days: [WidgetDateKey: CalendarDay]) -> WorkReminder? {
        if days[today]?.status == .work {
            return .today
        }
        let tomorrow = shifted(today, by: 1)
        if days[tomorrow]?.status == .work {
            return .tomorrow(weekday: shortWeekdayName(for: tomorrow))
        }
        return nil
    }

    func holidayInfo(today: WidgetDateKey, days: [WidgetDateKey: CalendarDay]) -> HolidayInfo? {
        guard let first = days.values
            .filter({ $0.key >= today && $0.status == .rest })
            .min(by: { $0.key < $1.key })
        else {
            return nil
        }

        var block = [first]
        var cursor = first.key
        while let previous = days[shifted(cursor, by: -1)], previous.status == .rest {
            block.insert(previous, at: 0)
            cursor = previous.key
        }
        cursor = first.key
        while let next = days[shifted(cursor, by: 1)], next.status == .rest {
            block.append(next)
            cursor = next.key
        }

        let start = block[0].key
        return HolidayInfo(
            name: holidayName(in: block),
            year: start.year,
            daysUntil: max(0, distance(from: today, to: start)),
            length: block.count,
            dayIndex: first.key == today ? distance(from: start, to: today) + 1 : nil
        )
    }

    private func holidayName(in block: [CalendarDay]) -> String {
        for day in block {
            for name in day.terms + day.festivals {
                if let official = officialHolidays.first(where: { name.hasPrefix($0) }) {
                    return official == "清明" ? "清明节" : official
                }
            }
        }
        return "法定节假日"
    }

    func shortWeekdayName(for key: WidgetDateKey) -> String {
        "周" + weekdayName(for: key).suffix(1)
    }

    private func weekdayName(for key: WidgetDateKey) -> String {
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let index = max(1, min(7, gregorian.component(.weekday, from: date(for: key)))) - 1
        return names[index]
    }

    private func fallbackYearTitle(for key: WidgetDateKey) -> String {
        let year = chinese.dateComponents([.year], from: date(for: key)).year ?? 1
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        let animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
        let branchIndex = (year - 1) % branches.count
        return "\(stems[(year - 1) % stems.count])\(branches[branchIndex])\(animals[branchIndex])年"
    }

    private func lunarComponents(for key: WidgetDateKey) -> (month: Int, day: Int, isLeap: Bool) {
        let components = chinese.dateComponents([.month, .day, .isLeapMonth], from: date(for: key))
        return (
            max(1, min(12, components.month ?? 1)),
            max(1, min(30, components.day ?? 1)),
            components.isLeapMonth ?? false
        )
    }

    private func lunarMonthName(_ month: Int, isLeap: Bool) -> String {
        let names = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "腊月"]
        let name = names[max(1, min(12, month)) - 1]
        return isLeap ? "闰\(name)" : name
    }

    private func lunarDayName(_ day: Int) -> String {
        let names = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        return names[max(1, min(30, day)) - 1]
    }
}

private struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let today: WidgetDateKey
    let displayedMonth: WidgetDateKey
    let selectedDate: WidgetDateKey
    let days: [WidgetDateKey: CalendarDay]
    let countdown: String
    let holiday: HolidayInfo?
    let workReminder: WorkReminder?
    let weather: WeatherSnapshot?
    let appearance: ColorScheme?
}

private struct CalendarWidgetProvider: TimelineProvider {
    private let model = WidgetCalendarModel.shared

    func placeholder(in context: Context) -> CalendarWidgetEntry {
        makeEntry(for: Date(), days: [:], weather: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let now = Date()
        completion(makeEntry(
            for: now,
            days: CalendarDataStore.cachedDays(),
            weather: WeatherStore.cached(city: WidgetSettings.weatherCity, now: now)
        ))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void
    ) {
        Task {
            let started = Date()
            let now = Date()
            let city = WidgetSettings.weatherCity
            let calendar = Calendar.widgetGregorian
            let startOfToday = calendar.startOfDay(for: now)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
            let refreshDate = min(nextDay, now.addingTimeInterval(WeatherStore.refreshInterval))

            // 扩展在返回时间线后很快被系统挂起，后台任务可能来不及完成，
            // 因此完全没有可用数据时先等一次联网，之后各次点击都直接命中缓存。
            var days = CalendarDataStore.cachedDays()
            if days.isEmpty {
                await CalendarDataStore.refreshIfNeeded(centers: [model.key(for: now).monthStart], now: now)
                days = CalendarDataStore.cachedDays()
            }
            if WeatherStore.cached(city: city, now: now) == nil {
                await WeatherStore.refreshIfNeeded(city: city, now: now)
            }

            // 每个条目都要按多种外观各渲染一遍，只放一个条目以缩短点击后的渲染时间；跨天由到期刷新完成。
            let entry = makeEntry(
                for: now,
                days: days,
                weather: WeatherStore.cached(city: city, now: now)
            )
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
            performanceLog.debug("timeline built in \(Int(Date().timeIntervalSince(started) * 1000)) ms city=\(city, privacy: .public)")

            // 已有缓存时立即响应点击，联网更新放到后台，数据有变化时再刷新一次。
            let displayed = entry.displayedMonth
            let todayMonth = entry.today.monthStart
            async let calendarChanged = CalendarDataStore.refreshIfNeeded(
                centers: [
                    todayMonth.addingMonths(1),
                    displayed,
                    displayed.addingMonths(3),
                    displayed.addingMonths(-3)
                ],
                now: now
            )
            async let weatherChanged = WeatherStore.refreshIfNeeded(city: city, now: now)
            let calendarDidChange = await calendarChanged
            let weatherDidChange = await weatherChanged
            if calendarDidChange || weatherDidChange {
                WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetConstants.kind)
            }
        }
    }

    private func makeEntry(
        for date: Date,
        days: [WidgetDateKey: CalendarDay],
        weather: WeatherSnapshot?
    ) -> CalendarWidgetEntry {
        let today = model.key(for: date)
        let state = CalendarWidgetState.snapshot(today: date)
        return CalendarWidgetEntry(
            date: date,
            today: today,
            displayedMonth: state.displayedMonth,
            selectedDate: state.selectedDate,
            days: days,
            countdown: model.countdown(today: today, days: days),
            holiday: model.holidayInfo(today: today, days: days),
            workReminder: model.workReminder(today: today, days: days),
            weather: weather,
            appearance: CalendarWidgetState.appearance
        )
    }
}

private struct CalendarWidgetView: View {
    let entry: CalendarWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private let model = WidgetCalendarModel.shared
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    /// 系统会按浅色、深色各渲染一份，手动选择外观时两份都使用同一套配色。
    private var effectiveScheme: ColorScheme {
        entry.appearance ?? colorScheme
    }

    private var theme: WidgetTheme {
        .resolve(effectiveScheme, renderingMode: renderingMode)
    }

    var body: some View {
        content
            .environment(\.colorScheme, effectiveScheme)
            .widgetURL(CalendarWidgetConstants.calendarURL)
            .containerBackground(for: .widget) {
                theme.background
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            framed(smallContent)
        case .systemMedium:
            framed(mediumContent)
        default:
            framed(largeContent)
        }
    }

    private func framed<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.background)
            .clipShape(ContainerRelativeShape())
            .overlay(
                ContainerRelativeShape()
                    .inset(by: 0.5)
                    .stroke(theme.border, lineWidth: 1)
            )
    }

    // MARK: - 大号

    private var largeContent: some View {
        let month = entry.displayedMonth
        return VStack(spacing: 0) {
            header(year: month.year, month: month.month)
            weekdayHeader(fontSize: 9)
                .frame(height: 12)
                .padding(.horizontal, 4)
                .padding(.top, 2)
            calendarGrid(days: model.visibleDays(for: month), month: month)
                .padding(.horizontal, 4)
                .padding(.top, 2)
            largeDetails
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
    }

    private var largeDetails: some View {
        let detail = model.detail(
            for: entry.selectedDate,
            day: entry.days[entry.selectedDate],
            today: entry.today
        )
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("节日百科")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.infoText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.infoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(detail.festivals)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.ink.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 4)
                Text(detail.dateTitle)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.mutedInk)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(height: 18)

            Divider()

            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(detail.lunarTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(detail.ganzhi)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 84, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    almanacLine(tag: "宜", text: detail.suit, color: theme.holiday)
                    almanacLine(tag: "忌", text: detail.avoid, color: theme.workBadge)
                }
                Spacer(minLength: 4)
                if let weather = weatherLine(for: entry.selectedDate) {
                    weatherLink {
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 3) {
                                weatherSymbol(weather.symbol, size: 12)
                                Text(weather.current.map { "\($0)°" } ?? weather.condition)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.ink)
                            }
                            Text(weather.current == nil ? weather.range : "\(weather.condition) \(weather.range)")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.mutedInk)
                        }
                        .lineLimit(1)
                        .fixedSize()
                    }
                }
            }
            .frame(height: 34)

            Divider()

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(entry.countdown)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
                appearanceToggle
                webLink
            }
            .foregroundStyle(theme.ink.opacity(0.72))
            .frame(height: 18)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: 80)
        .background(theme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func header(year: Int, month: Int) -> some View {
        HStack(spacing: 3) {
            if let reminder = entry.workReminder {
                headerTag(reminder.title, textColor: theme.onBadge, background: theme.workBadge)
            } else {
                headerTag("假期", textColor: theme.tagText, background: theme.tagBackground)
                    .widgetAccentable()
            }
            Spacer(minLength: 1)
            monthNavigator(year: year, month: month)
            Spacer(minLength: 1)
            todayButton
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .background(theme.headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.headerBorder, lineWidth: 0.75)
        )
    }

    private func headerTag(_ title: String, textColor: Color, background: Color) -> some View {
        Text(verbatim: title)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 5)
            .frame(height: 20)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func calendarGrid(days: [WidgetDateKey], month: WidgetDateKey) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<days.count / 7, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(days[(row * 7)..<(row * 7 + 7)], id: \.self) { key in
                        dayCell(key: key, month: month)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(key: WidgetDateKey, month: WidgetDateKey) -> some View {
        if key.year == month.year && key.month == month.month {
            currentMonthDayCell(key: key)
        } else {
            adjacentMonthDayCell(key: key)
        }
    }

    /// 上下月的日期也可点击，为控制渲染耗时省掉农历小字，只保留数字与休/班角标。
    private func adjacentMonthDayCell(key: WidgetDateKey) -> some View {
        let theme = self.theme
        let status = entry.days[key]?.status
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        let numberColor = key == entry.today ? theme.accent : (isRedDay ? theme.holiday : theme.ink)
        let fill: Color? = status == .rest ? theme.restFill : nil

        return selectable(
            Text("\(key.day)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(numberColor.opacity(theme.outsideMonthOpacity))
                .frame(maxWidth: .infinity)
                .frame(height: 30, alignment: .top)
                .padding(.vertical, 1)
                .background {
                    if let fill {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let status {
                        Text(status == .rest ? "休" : "班")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundStyle(theme.onBadge)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 1)
                            .background(status == .rest ? theme.holiday : theme.workBadge)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .opacity(0.5)
                            .offset(x: 2, y: -2)
                    }
                }
                .contentShape(Rectangle()),
            key: key
        )
    }

    private func currentMonthDayCell(key: WidgetDateKey) -> some View {
        let theme = self.theme
        let day = entry.days[key]
        let status = day?.status
        let isToday = key == entry.today
        let isSelected = key == entry.selectedDate
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        let numberColor = isToday ? theme.accent : (isRedDay ? theme.holiday : theme.ink)
        let label = model.dayLabel(for: key, day: day)
        let fill: Color? = isToday
            ? theme.todayFill
            : (status == .rest ? theme.restFill : nil)

        let cell = VStack(spacing: 1) {
            Text("\(key.day)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(numberColor)
                .frame(maxWidth: .infinity)
                .widgetAccentable(status == .rest)
            Text(label)
                .font(.system(size: 8, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(label.count > 4 ? 0.65 : 1)
                .foregroundStyle(status == .rest || isToday ? numberColor : theme.mutedInk)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 30)
        .padding(.vertical, 1)
        .background {
            if let fill {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(theme.selection, lineWidth: 1.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let status {
                Text(status == .rest ? "休" : "班")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(theme.onBadge)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(status == .rest ? theme.holiday : theme.workBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .offset(x: 2, y: -2)
                    .widgetAccentable(status == .rest)
            }
        }
        .contentShape(Rectangle())

        return selectable(cell, key: key)
    }

    // MARK: - 中号

    private var mediumContent: some View {
        let month = entry.displayedMonth
        return HStack(spacing: 10) {
            mediumDetailPanel
                .frame(width: 108)
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    monthNavigator(year: month.year, month: month.month)
                    Spacer(minLength: 2)
                    todayButton
                }
                .frame(height: 20)
                weekdayHeader(fontSize: 8)
                    .frame(height: 11)
                    .padding(.top, 3)
                miniGrid(days: model.visibleDays(for: month), month: month)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var mediumDetailPanel: some View {
        let key = entry.selectedDate
        let day = entry.days[key]
        let detail = model.detail(for: key, day: day, today: entry.today)
        let status = day?.status
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        let suit = detail.suit.split(separator: "·").prefix(3).joined(separator: "·")
        let summary = holidaySummary
        return VStack(alignment: .leading, spacing: 0) {
            Text(detail.shortTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.holiday)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(key.day)")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(isRedDay ? theme.holiday : theme.ink)
                if let status {
                    statusBadge(status, size: 9)
                }
            }
            .frame(height: 38)
            Text(detail.lunarTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Text(detail.hasFestival ? detail.festivals : detail.ganzhi)
                .font(.system(size: 8, weight: detail.hasFestival ? .medium : .regular))
                .foregroundStyle(detail.hasFestival ? theme.holiday : theme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 1)
            if let weather = weatherLine(for: key) {
                weatherLink {
                    HStack(spacing: 3) {
                        weatherSymbol(weather.symbol, size: 9)
                        Text(weather.current.map { "\(weather.condition) \($0)°" } ?? weather.condition)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text(weather.range)
                            .font(.system(size: 8))
                            .foregroundStyle(theme.mutedInk)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 3)
            almanacLine(tag: "宜", text: suit, color: theme.holiday)
            Spacer(minLength: 3)
            if let reminder = entry.workReminder {
                HStack(spacing: 4) {
                    statusBadge(.work, size: 8)
                    Text(reminderText(reminder))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Text("\(summary.title) · \(summary.subtitle)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.ink.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 4) {
                appearanceToggle
                webLink
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func miniGrid(days: [WidgetDateKey], month: WidgetDateKey) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<days.count / 7, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(days[(row * 7)..<(row * 7 + 7)], id: \.self) { key in
                        miniDayCell(key: key, month: month)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func miniDayCell(key: WidgetDateKey, month: WidgetDateKey) -> some View {
        let theme = self.theme
        let status = entry.days[key]?.status
        let inCurrentMonth = key.year == month.year && key.month == month.month
        let isToday = key == entry.today
        let isSelected = key == entry.selectedDate
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        let fadedOpacity = inCurrentMonth ? 1.0 : theme.outsideMonthOpacity
        let numberColor: Color = isToday ? theme.onBadge : (isRedDay ? theme.holiday : theme.ink)
        let fill: Color? = isToday
            ? theme.accent
            : (status == .rest ? theme.holiday.opacity(0.16) : (status == .work ? theme.workBadge.opacity(0.20) : nil))

        let cell = Text("\(key.day)")
            .font(.system(size: 10, weight: isToday ? .bold : .medium))
            .foregroundStyle(numberColor.opacity(fadedOpacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if let fill {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill)
                        .opacity(inCurrentMonth ? 1 : 0.6)
                }
            }
            .overlay {
                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(theme.selection, lineWidth: 1.2)
                }
            }
            .widgetAccentable(status == .rest && !isToday)
            .contentShape(Rectangle())

        return selectable(cell, key: key)
    }

    // MARK: - 小号

    private var smallContent: some View {
        let key = entry.today
        let day = entry.days[key]
        let detail = model.detail(for: key, day: day, today: key)
        let status = day?.status
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(key.month)月")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.holiday)
                Spacer(minLength: 4)
                Text(model.shortWeekdayName(for: key))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedInk)
            }
            HStack(alignment: .center, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(key.day)")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(isRedDay ? theme.holiday : theme.ink)
                    if let status {
                        statusBadge(status, size: 10)
                    }
                }
                Spacer(minLength: 4)
                if let weather = weatherLine(for: key) {
                    weatherLink {
                        VStack(alignment: .trailing, spacing: 1) {
                            weatherSymbol(weather.symbol, size: 26)
                                .frame(height: 28)
                            Text("\(weather.current ?? 0)°")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.ink)
                        }
                    }
                }
            }
            .frame(height: 50)
            HStack(spacing: 4) {
                Text(detail.hasFestival ? "\(detail.lunarTitle) · \(detail.festivals)" : detail.lunarTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.ink.opacity(0.85))
                    .layoutPriority(1)
                if let weather = weatherLine(for: key) {
                    Spacer(minLength: 2)
                    Text("\(weather.condition) \(weather.range)")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedInk)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)
            smallFooter(status: status)
                .padding(.top, 7)
        }
        .padding(14)
    }

    private func smallFooter(status: HolidayStatus?) -> some View {
        let summary = holidaySummary
        let reminder = entry.workReminder
        let isWorkDay = reminder != nil
        let title = reminder?.title ?? summary.title
        let subtitle = isWorkDay ? summary.title : summary.subtitle
        return HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isWorkDay ? theme.workBadge : theme.holiday)
                .frame(width: 3, height: 26)
                .widgetAccentable(!isWorkDay)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.mutedInk)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }

    // MARK: - 共用组件

    private var holidaySummary: (title: String, subtitle: String, isOngoing: Bool) {
        guard let info = entry.holiday else {
            return ("后续假期", "待官方公布", false)
        }
        if let index = info.dayIndex {
            return ("\(info.name)假期", "第\(index)天 · 共\(info.length)天", true)
        }
        return ("\(info.name) 还有\(info.daysUntil)天", "放假\(info.length)天", false)
    }

    private struct WeatherLine {
        let symbol: String
        let condition: String
        /// 仅今天有实况温度。
        let current: Int?
        let range: String
    }

    /// 今天显示实况，其余日期显示逐日预报；超出预报范围时返回 nil。
    private func weatherLine(for key: WidgetDateKey) -> WeatherLine? {
        guard let weather = entry.weather else {
            return nil
        }
        let day = weather.forecast[key.number]
        let range = day.map { "\($0.low)~\($0.high)°" } ?? ""
        if key == entry.today {
            return WeatherLine(
                symbol: WeatherSnapshot.symbol(for: weather.iconKey),
                condition: weather.condition,
                current: weather.temperature,
                range: range
            )
        }
        guard let day else {
            return nil
        }
        return WeatherLine(symbol: WeatherSnapshot.symbol(for: day.iconKey), condition: day.condition, current: nil, range: range)
    }

    @ViewBuilder
    private func weatherLink<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let url = entry.weather?.pageURL {
            Link(destination: url) { content() }
                .buttonStyle(.plain)
        } else {
            content()
        }
    }

    /// 系统多色模式下云朵固定为白色，浅色背景上看不清，因此按符号分层手动配色（各符号的分层顺序不同）。
    private func weatherSymbol(_ name: String, size: CGFloat) -> some View {
        let cloud = theme.mutedInk
        let sun = Color(red: 1.0, green: 0.7, blue: 0.1)
        let rain = Color(red: 0.25, green: 0.6, blue: 1.0)
        let layers: (Color, Color, Color)
        switch name {
        case "sun.max.fill", "moon.stars.fill":
            layers = (sun, sun, sun)
        case "cloud.sun.fill", "cloud.moon.fill":
            layers = (cloud, sun, sun)
        case "cloud.sun.rain.fill", "cloud.moon.rain.fill":
            layers = (cloud, sun, rain)
        case "sun.haze.fill", "sun.dust.fill":
            layers = (sun, cloud, cloud)
        default:
            layers = (cloud, rain, rain)
        }
        return Image(systemName: name)
            .symbolRenderingMode(renderingMode == .fullColor ? .palette : .monochrome)
            .foregroundStyle(layers.0, layers.1, layers.2)
            .font(.system(size: size))
    }

    private func reminderText(_ reminder: WorkReminder) -> String {
        switch reminder {
        case .today: return "今天补班，记得上班"
        case .tomorrow(let weekday): return "明天\(weekday)补班"
        }
    }

    private func statusBadge(_ status: HolidayStatus, size: CGFloat) -> some View {
        Text(status == .rest ? "休" : "班")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(theme.onBadge)
            .padding(.horizontal, size * 0.35)
            .padding(.vertical, size * 0.15)
            .background(
                status == .rest ? theme.holiday : theme.workBadge,
                in: RoundedRectangle(cornerRadius: 3, style: .continuous)
            )
            .widgetAccentable(status == .rest)
    }

    /// 上下月的淡灰色日期同样可点击，点后切到所在月份并选中；
    /// 否则点击会落到整块组件的 widgetURL 上直接打开网页，容易让人误解。
    private func selectable<Cell: View>(_ cell: Cell, key: WidgetDateKey) -> some View {
        Button(intent: SelectDateIntent(date: key)) { cell }
            .buttonStyle(.plain)
    }

    private func almanacLine(tag: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(tag)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(theme.onBadge)
                .frame(width: 13, height: 13)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(text)
                .font(.system(size: 8))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(theme.ink.opacity(0.78))
        }
    }

    private func monthNavigator(year: Int, month: Int) -> some View {
        HStack(spacing: 3) {
            headerArrow("chevron.left", help: "上一个月", intent: PreviousMonthIntent())
            Text(verbatim: "\(year)年 \(month)月")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 74)
                .frame(height: 20)
            headerArrow("chevron.right", help: "下一个月", intent: NextMonthIntent())
        }
    }

    private func headerArrow<Intent: AppIntent>(_ systemName: String, help: String, intent: Intent) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.mutedInk)
                .frame(width: 20, height: 20)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(theme.controlBorder, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var todayButton: some View {
        Button(intent: TodayIntent()) {
            Text("今天")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(theme.controlBorder, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help("回到当前月份")
    }

    private func weekdayHeader(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, weekday in
                Text(weekday)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(index >= 5 ? theme.holiday : theme.mutedInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var appearanceToggle: some View {
        let isDark = effectiveScheme == .dark
        return Button(intent: ToggleAppearanceIntent(dark: !isDark, systemDark: colorScheme == .dark)) {
            Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.appearanceIcon)
                .frame(width: 18, height: 16)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(theme.infoBorder, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help(isDark ? "切换为浅色" : "切换为深色")
    }

    private var webLink: some View {
        Link(destination: CalendarWidgetConstants.calendarURL) {
            HStack(spacing: 2) {
                Text("网页")
                Image(systemName: "arrow.up.right.square")
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(theme.infoText)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(theme.infoBorder, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .help("在百度日历网页中查看更多月份")
    }
}

struct DesktopCalendarWidget: Widget {
    let kind = CalendarWidgetConstants.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("桌面日历")
        .description("与百度日历同步的法定节假日、调休安排与天气，点击日期可查看当日农历与宜忌。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

@main
struct DesktopCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        DesktopCalendarWidget()
    }
}
