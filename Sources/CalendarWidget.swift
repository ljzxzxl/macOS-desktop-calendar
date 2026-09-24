import SwiftUI
import WidgetKit
import AppIntents
import Foundation

private struct WidgetDateKey: Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
        day = components.day ?? 0
    }
}

private enum WidgetWorkMarker: Equatable {
    case rest
    case work
}

private enum WidgetPalette {
    static let ink = Color(red: 0.15, green: 0.17, blue: 0.20)
    static let mutedInk = Color(red: 0.40, green: 0.43, blue: 0.47)
}

private enum CalendarWidgetConstants {
    static let kind = "com.allen.desktopcalendar.widget"
    static let calendarURL = URL(string: "https://www.baidu.com/s?wd=%E6%97%A5%E5%8E%86")!
}

private enum CalendarWidgetNavigation {
    private static let selectedMonthKey = "selectedCalendarMonth"

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    static func displayedMonth(referenceDate: Date) -> Date {
        if let selectedMonth = UserDefaults.standard.object(forKey: selectedMonthKey) as? Date {
            return startOfMonth(containing: selectedMonth)
        }
        return startOfMonth(containing: referenceDate)
    }

    static func move(by monthCount: Int) {
        let baseMonth = displayedMonth(referenceDate: Date())
        guard let destination = calendar.date(byAdding: .month, value: monthCount, to: baseMonth) else {
            return
        }
        UserDefaults.standard.set(startOfMonth(containing: destination), forKey: selectedMonthKey)
        reloadWidget()
    }

    static func showToday() {
        UserDefaults.standard.removeObject(forKey: selectedMonthKey)
        reloadWidget()
    }

    private static func startOfMonth(containing date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: 1,
                hour: 12
            )
        ) ?? date
    }

    private static func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetConstants.kind)
    }
}

struct PreviousMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "上一个月"
    static let description = IntentDescription("在桌面日历中显示上一个月")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetNavigation.move(by: -1)
        return .result()
    }
}

struct NextMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "下一个月"
    static let description = IntentDescription("在桌面日历中显示下一个月")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetNavigation.move(by: 1)
        return .result()
    }
}

struct TodayIntent: AppIntent {
    static let title: LocalizedStringResource = "回到今天"
    static let description = IntentDescription("让桌面日历重新显示当前月份")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        CalendarWidgetNavigation.showToday()
        return .result()
    }
}

private struct WidgetCalendarModel {
    var gregorian: Calendar
    var chinese: Calendar

    private let recurringEvents: [String: [String]] = [
        "01-01": ["元旦"],
        "03-08": ["国际妇女节"],
        "04-22": ["世界地球日"],
        "05-01": ["劳动节"],
        "05-04": ["青年节"],
        "06-01": ["儿童节"],
        "08-01": ["建军节"],
        "09-10": ["教师节"],
        "09-20": ["全国爱牙日", "清洁地球日"],
        "10-01": ["国庆节"],
        "12-25": ["圣诞节"]
    ]

    private let holidayNames: [WidgetDateKey: String] = [
        WidgetDateKey(2026, 1, 1): "元旦",
        WidgetDateKey(2026, 2, 17): "春节",
        WidgetDateKey(2026, 4, 5): "清明节",
        WidgetDateKey(2026, 5, 1): "劳动节",
        WidgetDateKey(2026, 6, 19): "端午节",
        WidgetDateKey(2026, 9, 25): "中秋节",
        WidgetDateKey(2026, 10, 1): "国庆节"
    ]

    private let solarTerms: [WidgetDateKey: String] = [
        WidgetDateKey(2026, 1, 5): "小寒",
        WidgetDateKey(2026, 1, 20): "大寒",
        WidgetDateKey(2026, 2, 4): "立春",
        WidgetDateKey(2026, 2, 18): "雨水",
        WidgetDateKey(2026, 3, 5): "惊蛰",
        WidgetDateKey(2026, 3, 20): "春分",
        WidgetDateKey(2026, 4, 5): "清明",
        WidgetDateKey(2026, 4, 20): "谷雨",
        WidgetDateKey(2026, 5, 5): "立夏",
        WidgetDateKey(2026, 5, 21): "小满",
        WidgetDateKey(2026, 6, 5): "芒种",
        WidgetDateKey(2026, 6, 21): "夏至",
        WidgetDateKey(2026, 7, 7): "小暑",
        WidgetDateKey(2026, 7, 23): "大暑",
        WidgetDateKey(2026, 8, 7): "立秋",
        WidgetDateKey(2026, 8, 23): "处暑",
        WidgetDateKey(2026, 9, 7): "白露",
        WidgetDateKey(2026, 9, 23): "秋分",
        WidgetDateKey(2026, 10, 8): "寒露",
        WidgetDateKey(2026, 10, 23): "霜降",
        WidgetDateKey(2026, 11, 7): "立冬",
        WidgetDateKey(2026, 11, 22): "小雪",
        WidgetDateKey(2026, 12, 7): "大雪",
        WidgetDateKey(2026, 12, 22): "冬至"
    ]

    init() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = Locale(identifier: "zh_CN")
        gregorian.timeZone = .autoupdatingCurrent
        gregorian.firstWeekday = 2
        self.gregorian = gregorian

        var chinese = Calendar(identifier: .chinese)
        chinese.locale = Locale(identifier: "zh_CN")
        chinese.timeZone = .autoupdatingCurrent
        self.chinese = chinese
    }

    func date(year: Int, month: Int, day: Int) -> Date {
        gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    func key(for date: Date) -> WidgetDateKey {
        WidgetDateKey(date, calendar: gregorian)
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        gregorian.isDate(lhs, inSameDayAs: rhs)
    }

    func visibleDates(containing date: Date) -> [Date] {
        let components = gregorian.dateComponents([.year, .month], from: date)
        let firstDay = self.date(
            year: components.year ?? 2026,
            month: components.month ?? 1,
            day: 1
        )
        let weekday = gregorian.component(.weekday, from: firstDay)
        let daysFromMonday = (weekday + 5) % 7
        guard let startDate = gregorian.date(byAdding: .day, value: -daysFromMonday, to: firstDay) else {
            return []
        }
        return (0..<42).compactMap {
            gregorian.date(byAdding: .day, value: $0, to: startDate)
        }
    }

    func marker(for date: Date) -> WidgetWorkMarker? {
        let key = key(for: date)
        let restDates: Set<WidgetDateKey> = [
            WidgetDateKey(2026, 1, 1), WidgetDateKey(2026, 1, 2), WidgetDateKey(2026, 1, 3),
            WidgetDateKey(2026, 2, 15), WidgetDateKey(2026, 2, 16),
            WidgetDateKey(2026, 2, 17), WidgetDateKey(2026, 2, 18),
            WidgetDateKey(2026, 2, 19), WidgetDateKey(2026, 2, 20),
            WidgetDateKey(2026, 2, 21), WidgetDateKey(2026, 2, 22),
            WidgetDateKey(2026, 2, 23),
            WidgetDateKey(2026, 4, 4), WidgetDateKey(2026, 4, 5), WidgetDateKey(2026, 4, 6),
            WidgetDateKey(2026, 5, 1), WidgetDateKey(2026, 5, 2),
            WidgetDateKey(2026, 5, 3), WidgetDateKey(2026, 5, 4), WidgetDateKey(2026, 5, 5),
            WidgetDateKey(2026, 6, 19), WidgetDateKey(2026, 6, 20), WidgetDateKey(2026, 6, 21),
            WidgetDateKey(2026, 9, 25), WidgetDateKey(2026, 9, 26), WidgetDateKey(2026, 9, 27),
            WidgetDateKey(2026, 10, 1), WidgetDateKey(2026, 10, 2),
            WidgetDateKey(2026, 10, 3), WidgetDateKey(2026, 10, 4),
            WidgetDateKey(2026, 10, 5), WidgetDateKey(2026, 10, 6),
            WidgetDateKey(2026, 10, 7)
        ]
        let workDates: Set<WidgetDateKey> = [
            WidgetDateKey(2026, 1, 4),
            WidgetDateKey(2026, 2, 14), WidgetDateKey(2026, 2, 28),
            WidgetDateKey(2026, 5, 9),
            WidgetDateKey(2026, 9, 20),
            WidgetDateKey(2026, 10, 10)
        ]

        if restDates.contains(key) {
            return .rest
        }
        if workDates.contains(key) {
            return .work
        }
        return nil
    }

    func dayLabel(for date: Date) -> String {
        let key = key(for: date)
        if key != WidgetDateKey(2026, 9, 20) {
            if let holiday = holidayNames[key] {
                return holiday
            }
            if let term = solarTerms[key] {
                return term
            }
            let monthDay = String(format: "%02d-%02d", key.month, key.day)
            if let event = recurringEvents[monthDay]?.first {
                return event
            }
        }

        let lunar = lunarComponents(for: date)
        if lunar.month == 1 && lunar.day == 1 {
            return "春节"
        }
        if lunar.month == 1 && lunar.day == 15 {
            return "元宵节"
        }
        if lunar.month == 5 && lunar.day == 5 {
            return "端午节"
        }
        if lunar.month == 8 && lunar.day == 15 {
            return "中秋节"
        }
        return lunar.day == 1
            ? lunarMonthName(lunar.month, isLeap: lunar.isLeap)
            : lunarDayName(lunar.day)
    }

    func lunarTitle(for date: Date) -> String {
        let lunar = lunarComponents(for: date)
        return "\(lunarMonthName(lunar.month, isLeap: lunar.isLeap))\(lunarDayName(lunar.day))"
    }

    func zodiacTitle(for date: Date) -> String {
        let year = chinese.dateComponents([.year], from: date).year ?? 1
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        let animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
        let stemIndex = (year - 1) % stems.count
        let branchIndex = (year - 1) % branches.count
        return "\(stems[stemIndex])\(branches[branchIndex])年 · \(animals[branchIndex])"
    }

    func eventSummary(for date: Date) -> String {
        let key = key(for: date)
        var events: [String] = []
        if let holiday = holidayNames[key] {
            events.append(holiday)
        }
        if let term = solarTerms[key], !events.contains(term) {
            events.append(term)
        }
        let monthDay = String(format: "%02d-%02d", key.month, key.day)
        for event in recurringEvents[monthDay] ?? [] where !events.contains(event) {
            events.append(event)
        }
        if events.isEmpty {
            return "\(weekdayName(for: date)) · 农历\(lunarTitle(for: date))"
        }
        return events.joined(separator: " · ")
    }

    func countdown(for date: Date) -> String {
        let start = gregorian.startOfDay(for: date)
        let targets: [(Date, String)] = [
            (self.date(year: 2026, month: 9, day: 25), "2026年中秋节"),
            (self.date(year: 2026, month: 10, day: 1), "2026年国庆节")
        ]
        for (target, name) in targets where target >= start {
            let days = gregorian.dateComponents([.day], from: start, to: target).day ?? 0
            if days == 0 {
                return "今天是\(name)"
            }
            return "距离 \(name) 还有\(days)天"
        }
        return "愿今天安排从容"
    }

    func almanac(for date: Date) -> (good: String, avoid: String) {
        if key(for: date) == WidgetDateKey(2026, 9, 20) {
            return (
                "出行·房屋清洁·沐浴·安葬·祭祀·除事勿取",
                "买房·动土·掘井·破土"
            )
        }
        return ("整理·学习·出行·会友", "行程过满·熬夜")
    }

    func weekdayName(for date: Date) -> String {
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let index = max(1, min(7, gregorian.component(.weekday, from: date))) - 1
        return names[index]
    }

    private func lunarComponents(for date: Date) -> (month: Int, day: Int, isLeap: Bool) {
        let components = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
        return (
            max(1, min(12, components.month ?? 1)),
            max(1, min(30, components.day ?? 1)),
            components.isLeapMonth ?? false
        )
    }

    private func lunarMonthName(_ month: Int, isLeap: Bool) -> String {
        let names = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
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
    let displayedMonth: Date
}

private struct CalendarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
        let entries = [
            makeEntry(for: now),
            makeEntry(for: nextDay)
        ]
        completion(Timeline(entries: entries, policy: .after(nextDay)))
    }

    private func makeEntry(for date: Date) -> CalendarWidgetEntry {
        CalendarWidgetEntry(
            date: date,
            displayedMonth: CalendarWidgetNavigation.displayedMonth(referenceDate: date)
        )
    }
}

private struct CalendarWidgetView: View {
    let entry: CalendarWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let model = WidgetCalendarModel()
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        content
        .environment(\.colorScheme, .light)
        .containerBackground(for: .widget) {
            Color.white
        }
    }

    @ViewBuilder
    private var content: some View {
        let dates = model.visibleDates(containing: entry.displayedMonth)
        let selectedKey = model.key(for: entry.displayedMonth)
        let currentMonth = selectedKey.month
        let currentYear = selectedKey.year
        let compact = family == .systemLarge

        VStack(spacing: 0) {
            header(year: currentYear, month: currentMonth, compact: compact)
            weekdayHeader(compact: compact)
                .padding(.horizontal, compact ? 4 : 12)
                .padding(.top, compact ? 2 : 8)
            calendarGrid(
                dates: dates,
                currentYear: currentYear,
                currentMonth: currentMonth,
                compact: compact
            )
                .padding(.horizontal, compact ? 4 : 10)
                .padding(.top, compact ? 2 : 4)

            if family == .systemLarge {
                compactDetails
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            } else if family == .systemExtraLarge {
                details
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.top, compact ? 12 : 16)
        .padding(.bottom, compact ? 0 : 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.89, blue: 0.91), lineWidth: 1)
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
        let almanac = model.almanac(for: entry.date)
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("节日百科")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.blue.opacity(0.82))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(model.eventSummary(for: entry.date))
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
            }
            .frame(height: 18)

            Divider()

            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.lunarTitle(for: entry.date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetPalette.ink)
                    Text(model.zodiacTitle(for: entry.date))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(WidgetPalette.mutedInk)
                }
                .frame(width: 58, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text("宜")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        Text(almanac.good)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(WidgetPalette.ink.opacity(0.78))
                    }
                    HStack(spacing: 3) {
                        Text("忌")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        Text(almanac.avoid)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(WidgetPalette.ink.opacity(0.78))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 34)

            Divider()

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(model.countdown(for: entry.date))
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
                webLink(compact: true)
            }
            .foregroundStyle(WidgetPalette.ink.opacity(0.72))
            .frame(height: 18)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: 80)
        .background(Color(red: 0.97, green: 0.97, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .background(Color(red: 0.93, green: 0.97, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                .stroke(Color(red: 0.82, green: 0.88, blue: 0.92), lineWidth: 0.75)
        )
    }

    private func headerTag(_ title: String, compact: Bool) -> some View {
        Text(verbatim: title)
            .font(.system(size: compact ? 9 : 12, weight: .medium))
            .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.20))
            .padding(.horizontal, compact ? 5 : 8)
            .frame(height: compact ? 20 : 30)
            .background(Color.red.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
    }

    private func headerTitle(year: Int, month: Int, compact: Bool) -> some View {
        Text(verbatim: "\(year)年 \(month)月")
            .font(.system(size: compact ? 11 : 14, weight: .semibold))
            .foregroundStyle(WidgetPalette.ink)
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
                .foregroundStyle(WidgetPalette.mutedInk)
                .frame(width: compact ? 20 : 26, height: compact ? 20 : 30)
                .background(Color.white.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                        .stroke(Color(red: 0.84, green: 0.88, blue: 0.91), lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func headerAction(compact: Bool) -> some View {
        Button(intent: TodayIntent()) {
            Text("今天")
                .font(.system(size: compact ? 10 : 13, weight: .medium))
                .foregroundStyle(WidgetPalette.ink)
                .padding(.horizontal, compact ? 6 : 9)
                .frame(height: compact ? 20 : 30)
                .background(Color.white.opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                        .stroke(Color(red: 0.82, green: 0.86, blue: 0.89), lineWidth: 0.7)
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
                    .foregroundStyle(index >= 5 ? Color.red.opacity(0.88) : WidgetPalette.mutedInk)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: compact ? 12 : nil)
    }

    private func calendarGrid(
        dates: [Date],
        currentYear: Int,
        currentMonth: Int,
        compact: Bool
    ) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: compact ? 1 : 2),
                count: 7
            ),
            spacing: compact ? 1 : (family == .systemSmall ? 3 : 5)
        ) {
            ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                dayCell(
                    date: date,
                    currentYear: currentYear,
                    currentMonth: currentMonth,
                    compact: compact
                )
            }
        }
    }

    private func dayCell(
        date: Date,
        currentYear: Int,
        currentMonth: Int,
        compact: Bool
    ) -> some View {
        let key = model.key(for: date)
        let inCurrentMonth = key.year == currentYear && key.month == currentMonth
        let selected = model.isSameDay(date, entry.date)
        let marker = model.marker(for: date)
        let numberColor = selected
            ? Color(red: 0.29, green: 0.43, blue: 0.88)
            : (marker == .rest || keyDayIsWeekend(date) ? Color.red.opacity(0.88) : WidgetPalette.ink)

        return VStack(spacing: 1) {
            Text("\(key.day)")
                .font(
                    .system(
                        size: compact ? 13 : (family == .systemSmall ? 13 : 17),
                        weight: .medium
                    )
                )
                .foregroundStyle(numberColor.opacity(inCurrentMonth ? 1 : 0.28))
                .frame(maxWidth: .infinity)
            Text(model.dayLabel(for: date))
                .font(
                    .system(
                        size: compact ? 8 : (family == .systemSmall ? 8 : 10),
                        weight: .regular
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(
                    (marker == .rest || selected ? numberColor : WidgetPalette.mutedInk)
                        .opacity(inCurrentMonth ? 1 : 0.28)
                )
                .frame(maxWidth: .infinity)
        }
        .frame(height: compact ? 30 : nil)
        .padding(.vertical, compact ? 1 : (family == .systemSmall ? 2 : 4))
        .background(marker == .rest ? Color.red.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.32, green: 0.46, blue: 0.91), lineWidth: 1.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let marker {
                Text(marker == .rest ? "休" : "班")
                    .font(.system(size: compact ? 6 : 7, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 2 : 3)
                    .padding(.vertical, compact ? 1 : 2)
                    .background(marker == .rest ? Color.red.opacity(0.88) : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .offset(x: 2, y: -2)
            }
        }
    }

    private var details: some View {
        let almanac = model.almanac(for: entry.date)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("节日百科")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.blue.opacity(0.78))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(model.eventSummary(for: entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)

            Divider()

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.lunarTitle(for: entry.date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WidgetPalette.ink)
                    Text(model.zodiacTitle(for: entry.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetPalette.mutedInk)
                }
                .frame(width: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    AlmanacLine(tag: "宜", text: almanac.good, color: .red)
                    AlmanacLine(tag: "忌", text: almanac.avoid, color: .gray)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)

            Divider()

            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(model.countdown(for: entry.date))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                webLink(compact: false)
            }
            .foregroundStyle(WidgetPalette.ink.opacity(0.72))
            .padding(.top, 7)
        }
        .padding(9)
        .background(Color(red: 0.97, green: 0.97, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func webLink(compact: Bool) -> some View {
        Link(destination: CalendarWidgetConstants.calendarURL) {
            HStack(spacing: compact ? 2 : 3) {
                Text("网页")
                Image(systemName: "arrow.up.right.square")
            }
            .font(.system(size: compact ? 8 : 10, weight: .medium))
            .foregroundStyle(Color.blue.opacity(0.86))
            .padding(.horizontal, compact ? 5 : 7)
            .frame(height: compact ? 16 : 20)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
                    .stroke(Color.blue.opacity(0.20), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .help("在百度日历网页中查看更多月份")
    }

    private func keyDayIsWeekend(_ date: Date) -> Bool {
        let weekday = model.gregorian.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

private struct AlmanacLine: View {
    let tag: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(text)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(WidgetPalette.ink.opacity(0.75))
        }
    }
}

struct DesktopCalendarWidget: Widget {
    let kind = CalendarWidgetConstants.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("桌面日历")
        .description("显示公历、农历、节气和中国法定节假日，可直接切换月份。")
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
