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
        todayFill: Color(red: 0.49, green: 0.62, blue: 1.00).opacity(0.20),
        restFill: Color(red: 1.00, green: 0.35, blue: 0.33).opacity(0.14),
        outsideMonthOpacity: 0.35
    )

    static func resolve(_ colorScheme: ColorScheme) -> WidgetTheme {
        colorScheme == .dark ? dark : light
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

private struct DayDetail {
    let dateTitle: String
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

        guard let day, !day.lunarDay.isEmpty else {
            let lunar = lunarComponents(for: key)
            return DayDetail(
                dateTitle: dateTitle,
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
            festivals: festivals.isEmpty ? "暂无节日" : festivals.prefix(3).joined(separator: " · "),
            lunarTitle: "\(day.lunarMonthTitle)\(day.lunarDay)",
            ganzhi: "\(day.ganzhiYear)\(day.animal)年 \(day.ganzhiMonth)月 \(day.ganzhiDay)日",
            suit: day.suit.isEmpty ? "—" : day.suit.prefix(6).joined(separator: "·"),
            avoid: day.avoid.isEmpty ? "—" : day.avoid.prefix(6).joined(separator: "·")
        )
    }

    func countdown(today: WidgetDateKey, days: [WidgetDateKey: CalendarDay]) -> String {
        guard let first = days.values
            .filter({ $0.key >= today && $0.status == .rest })
            .min(by: { $0.key < $1.key })
        else {
            return "后续假期安排待官方公布"
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

        let name = holidayName(in: block)
        if first.key == today {
            return "今天是\(name)假期 · 共放假\(block.count)天"
        }
        return "距离 \(first.key.year)年\(name) 还有\(distance(from: today, to: first.key))天 · 放假\(block.count)天"
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
}

private struct CalendarWidgetProvider: TimelineProvider {
    private let model = WidgetCalendarModel.shared

    func placeholder(in context: Context) -> CalendarWidgetEntry {
        makeEntry(for: Date(), days: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        completion(makeEntry(for: Date(), days: CalendarDataStore.cachedDays()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void
    ) {
        let started = Date()
        let now = Date()
        let days = CalendarDataStore.cachedDays()
        let calendar = Calendar.widgetGregorian
        let startOfToday = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
        let refreshDate = min(nextDay, now.addingTimeInterval(CalendarDataStore.refreshInterval))
        // 每个条目都要按多种外观各渲染一遍，只放一个条目以缩短点击后的渲染时间；跨天由到期刷新完成。
        let entry = makeEntry(for: now, days: days)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        performanceLog.debug("timeline built in \(Int(Date().timeIntervalSince(started) * 1000)) ms")

        // 先用缓存立即响应点击，联网更新放到后台，数据有变化时再刷新一次。
        let displayed = entry.displayedMonth
        let todayMonth = entry.today.monthStart
        Task {
            let changed = await CalendarDataStore.refreshIfNeeded(
                centers: [
                    todayMonth.addingMonths(1),
                    displayed,
                    displayed.addingMonths(3),
                    displayed.addingMonths(-3)
                ],
                now: now
            )
            if changed {
                WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetConstants.kind)
            }
        }
    }

    private func makeEntry(for date: Date, days: [WidgetDateKey: CalendarDay]) -> CalendarWidgetEntry {
        let today = model.key(for: date)
        let state = CalendarWidgetState.snapshot(today: date)
        return CalendarWidgetEntry(
            date: date,
            today: today,
            displayedMonth: state.displayedMonth,
            selectedDate: state.selectedDate,
            days: days,
            countdown: model.countdown(today: today, days: days)
        )
    }
}

private struct CalendarWidgetView: View {
    let entry: CalendarWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private let model = WidgetCalendarModel.shared
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    private var theme: WidgetTheme {
        .resolve(colorScheme)
    }

    var body: some View {
        content
        .containerBackground(for: .widget) {
            theme.background
        }
    }

    @ViewBuilder
    private var content: some View {
        let month = entry.displayedMonth
        let compact = family == .systemLarge

        VStack(spacing: 0) {
            header(year: month.year, month: month.month, compact: compact)
            weekdayHeader(compact: compact)
                .padding(.horizontal, compact ? 4 : 12)
                .padding(.top, compact ? 2 : 8)
            calendarGrid(
                days: model.visibleDays(for: month),
                month: month,
                compact: compact
            )
                .padding(.horizontal, compact ? 4 : 10)
                .padding(.top, compact ? 2 : 4)

            if family == .systemLarge {
                compactDetails
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.top, compact ? 12 : 16)
        .padding(.bottom, compact ? 0 : 4)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if family == .systemMedium {
                webLink(compact: true)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var compactDetails: some View {
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
                Spacer(minLength: 0)
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
                webLink(compact: true)
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

    private func almanacLine(tag: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(tag)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.white)
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

    private func header(year: Int, month: Int, compact: Bool) -> some View {
        HStack(spacing: compact ? 3 : 6) {
            headerTag("假期", compact: compact)

            Spacer(minLength: compact ? 1 : 4)

            headerArrow(
                "chevron.left",
                help: "上一个月",
                intent: PreviousMonthIntent(),
                compact: compact
            )
            headerTitle(year: year, month: month, compact: compact)
            headerArrow(
                "chevron.right",
                help: "下一个月",
                intent: NextMonthIntent(),
                compact: compact
            )

            Spacer(minLength: compact ? 1 : 4)

            headerAction(compact: compact)
        }
        .padding(.horizontal, compact ? 2 : 4)
        .padding(.vertical, compact ? 3 : 7)
        .background(theme.headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                .stroke(theme.headerBorder, lineWidth: 0.75)
        )
    }

    private func headerTag(_ title: String, compact: Bool) -> some View {
        Text(verbatim: title)
            .font(.system(size: compact ? 9 : 12, weight: .medium))
            .foregroundStyle(theme.tagText)
            .padding(.horizontal, compact ? 5 : 8)
            .frame(height: compact ? 20 : 30)
            .background(theme.tagBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
    }

    private func headerTitle(year: Int, month: Int, compact: Bool) -> some View {
        Text(verbatim: "\(year)年 \(month)月")
            .font(.system(size: compact ? 11 : 14, weight: .semibold))
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(minWidth: compact ? 74 : 96)
        .frame(height: compact ? 20 : 30)
    }

    private func headerArrow<Intent: AppIntent>(
        _ systemName: String,
        help: String,
        intent: Intent,
        compact: Bool
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: compact ? 8 : 10, weight: .semibold))
                .foregroundStyle(theme.mutedInk)
                .frame(width: compact ? 20 : 26, height: compact ? 20 : 30)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                        .stroke(theme.controlBorder, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func headerAction(compact: Bool) -> some View {
        Button(intent: TodayIntent()) {
            Text("今天")
                .font(.system(size: compact ? 10 : 13, weight: .medium))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, compact ? 6 : 9)
                .frame(height: compact ? 20 : 30)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                        .stroke(theme.controlBorder, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help("回到当前月份")
    }

    private func weekdayHeader(compact: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, weekday in
                Text(weekday)
                    .font(.system(size: compact ? 9 : 12, weight: .medium))
                    .foregroundStyle(index >= 5 ? theme.holiday : theme.mutedInk)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: compact ? 12 : nil)
    }

    private func calendarGrid(
        days: [WidgetDateKey],
        month: WidgetDateKey,
        compact: Bool
    ) -> some View {
        VStack(spacing: compact ? 1 : 5) {
            ForEach(0..<days.count / 7, id: \.self) { row in
                HStack(spacing: compact ? 1 : 2) {
                    ForEach(days[(row * 7)..<(row * 7 + 7)], id: \.self) { key in
                        dayCell(key: key, month: month, compact: compact)
                    }
                }
            }
        }
    }

    private func dayCell(key: WidgetDateKey, month: WidgetDateKey, compact: Bool) -> some View {
        let theme = self.theme
        let day = entry.days[key]
        let status = day?.status
        let inCurrentMonth = key.year == month.year && key.month == month.month
        let isToday = key == entry.today
        let isSelected = key == entry.selectedDate
        let isRedDay = status == .rest || (status != .work && model.isWeekend(key))
        let numberColor = isToday ? theme.accent : (isRedDay ? theme.holiday : theme.ink)
        let fadedOpacity = inCurrentMonth ? 1.0 : theme.outsideMonthOpacity
        let label = model.dayLabel(for: key, day: day)
        let fill: Color? = isToday
            ? theme.todayFill
            : (status == .rest ? theme.restFill : nil)

        let cell = VStack(spacing: 1) {
            Text("\(key.day)")
                .font(.system(size: compact ? 13 : 17, weight: .medium))
                .foregroundStyle(numberColor.opacity(fadedOpacity))
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.system(size: compact ? 8 : 10, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(label.count > 4 ? 0.65 : 1)
                .foregroundStyle(
                    (status == .rest || isToday ? numberColor : theme.mutedInk)
                        .opacity(fadedOpacity)
                )
                .frame(maxWidth: .infinity)
        }
        .frame(height: compact ? 30 : nil)
        .padding(.vertical, compact ? 1 : 4)
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
                    .font(.system(size: compact ? 6 : 7, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 2 : 3)
                    .padding(.vertical, compact ? 1 : 2)
                    .background(status == .rest ? theme.holiday : theme.workBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .opacity(inCurrentMonth ? 1 : 0.5)
                    .offset(x: 2, y: -2)
            }
        }
        .contentShape(Rectangle())

        // 每个按钮都会显著增加点击后的渲染时间，淡灰色的上下月日期不做成按钮。
        return Group {
            if inCurrentMonth {
                Button(intent: SelectDateIntent(date: key)) { cell }
                    .buttonStyle(.plain)
            } else {
                cell
            }
        }
    }

    private func webLink(compact: Bool) -> some View {
        Link(destination: CalendarWidgetConstants.calendarURL) {
            HStack(spacing: compact ? 2 : 3) {
                Text("网页")
                Image(systemName: "arrow.up.right.square")
            }
            .font(.system(size: compact ? 8 : 10, weight: .medium))
            .foregroundStyle(theme.infoText)
            .padding(.horizontal, compact ? 5 : 7)
            .frame(height: compact ? 16 : 20)
            .background(theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
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
        .description("与百度日历同步的法定节假日与调休安排，点击日期可查看当日农历与宜忌。")
        .supportedFamilies([.systemMedium, .systemLarge])
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
