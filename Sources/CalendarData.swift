import Foundation
import os

extension Calendar {
    static var widgetGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}

struct WidgetDateKey: Hashable, Codable, Comparable {
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

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }
        self.init(parts[0], parts[1], parts[2])
    }

    init?(number: Int) {
        guard number > 0 else {
            return nil
        }
        self.init(number / 10_000, number / 100 % 100, number % 100)
    }

    var number: Int {
        year * 10_000 + month * 100 + day
    }

    var stringValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var monthKey: String {
        String(format: "%04d-%02d", year, month)
    }

    var monthStart: WidgetDateKey {
        WidgetDateKey(year, month, 1)
    }

    func addingMonths(_ count: Int) -> WidgetDateKey {
        let total = year * 12 + (month - 1) + count
        return WidgetDateKey(total / 12, total % 12 + 1, 1)
    }

    static func < (lhs: WidgetDateKey, rhs: WidgetDateKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum HolidayStatus: String, Codable, Equatable {
    case rest = "1"
    case work = "2"
}

struct CalendarDay: Codable, Equatable {
    let key: WidgetDateKey
    let lunarMonth: String
    let lunarDay: String
    let ganzhiYear: String
    let ganzhiMonth: String
    let ganzhiDay: String
    let animal: String
    let suit: [String]
    let avoid: [String]
    let terms: [String]
    let festivals: [String]
    let status: HolidayStatus?

    var lunarMonthTitle: String {
        "\(lunarMonth)月"
    }
}

extension CalendarDay {
    init?(baidu item: [String: Any]) {
        func text(_ key: String) -> String {
            ((item[key] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func list(_ key: String, separator: Character) -> [String] {
            text(key)
                .split(separator: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard
            let year = Int(text("year")),
            let month = Int(text("month")),
            let day = Int(text("day"))
        else {
            return nil
        }

        self.init(
            key: WidgetDateKey(year, month, day),
            lunarMonth: text("lMonth"),
            lunarDay: text("lDate"),
            ganzhiYear: text("gzYear"),
            ganzhiMonth: text("gzMonth"),
            ganzhiDay: text("gzDate"),
            animal: text("animal"),
            suit: list("suit", separator: "."),
            avoid: list("avoid", separator: "."),
            terms: list("term", separator: " "),
            festivals: list("festivalList", separator: ","),
            status: HolidayStatus(rawValue: text("status"))
        )
    }
}

/// 宿主 App 与小组件扩展共享的设置，存放在扩展容器内的 JSON 里。
/// 扩展按自己的 Application Support 目录读取，宿主按绝对路径写入（见 WidgetHostMain.swift）。
enum WidgetSettings {
    static let fileName = "settings.json"

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DesktopCalendar", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    /// 留空表示由天气接口按出口 IP 判断城市。
    static var weatherCity: String {
        guard
            let url = fileURL,
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let city = json["weatherCity"] as? String
        else {
            return ""
        }
        return city.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension WeatherSnapshot {
    init?(baidu tplData: [String: Any]) {
        func text(_ container: [String: Any]?, _ key: String) -> String {
            ((container?[key] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let observe = tplData["observe"] as? [String: Any]
        guard let temperature = Int(text(observe, "temperature")) else {
            return nil
        }

        // 当前天气代号在逐小时预报的第一项里，日级预报只有白天/夜间代号。
        let hourly = (tplData["f1h"] as? [String: Any])?["info"] as? [[String: Any]]
        let currentIcon = text(hourly?.first, "iconKey")

        var forecast: [Int: WeatherDay] = [:]
        let daily = (tplData["day_forecast"] as? [String: Any])?["info"] as? [[String: Any]] ?? []
        for item in daily {
            let digits = text(item, "date").filter(\.isNumber)
            guard
                let number = Int(digits), digits.count == 8,
                let high = Int(text(item, "temperature_day")),
                let low = Int(text(item, "temperature_night"))
            else {
                continue
            }
            forecast[number] = WeatherDay(
                condition: text(item, "weather_day"),
                iconKey: text(item, "dayIconKey"),
                high: high,
                low: low
            )
        }

        let aqiDetail = tplData["ps_pm25_detail"] as? [String: Any]
        let location = [text(tplData, "county"), text(tplData, "city")].first { !$0.isEmpty } ?? ""
        self.init(
            location: location,
            temperature: temperature,
            condition: text(observe, "weather"),
            iconKey: currentIcon.isEmpty ? "yin" : currentIcon,
            aqi: Int(text(aqiDetail, "value")),
            aqiLevel: text(aqiDetail, "level").isEmpty ? nil : text(aqiDetail, "level"),
            forecast: forecast
        )
    }

    /// 点击天气时跳转的百度天气页面。
    var pageURL: URL? {
        var components = URLComponents(string: "https://www.baidu.com/s")!
        components.queryItems = [URLQueryItem(name: "wd", value: "\(location)天气")]
        return components.url
    }
}

/// 百度天气（https://www.baidu.com/s?wd=天气）同源数据，按城市缓存在扩展容器内。
enum WeatherStore {
    /// 天气比日历变化快，单独用更短的刷新间隔。
    static let refreshInterval: TimeInterval = 30 * 60
    /// 缓存太旧时宁可不显示，也不展示过期温度。
    static let staleInterval: TimeInterval = 6 * 60 * 60

    private struct Record: Codable {
        var fetchedAt: Date
        var snapshot: WeatherSnapshot
    }

    private static let lock = NSLock()
    private static var memoryCache: [String: Record]?

    private static var cacheURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DesktopCalendar", isDirectory: true)
            .appendingPathComponent("baidu-weather-cache.json")
    }

    /// 城市为空时由接口按出口 IP 判断。
    static func cached(city: String, now: Date = Date()) -> WeatherSnapshot? {
        guard let record = loadCache()[key(for: city)] else {
            return nil
        }
        return now.timeIntervalSince(record.fetchedAt) < staleInterval ? record.snapshot : nil
    }

    /// 返回值表示缓存内容是否真的发生了变化。
    @discardableResult
    static func refreshIfNeeded(city: String, now: Date = Date()) async -> Bool {
        var cache = loadCache()
        let cacheKey = key(for: city)
        if let record = cache[cacheKey], now.timeIntervalSince(record.fetchedAt) < refreshInterval {
            return false
        }
        guard let snapshot = try? await fetch(city: city) else {
            return false
        }
        let changed = cache[cacheKey]?.snapshot != snapshot
        cache[cacheKey] = Record(fetchedAt: now, snapshot: snapshot)
        saveCache(cache)
        return changed
    }

    private static func key(for city: String) -> String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "auto" : trimmed
    }

    private static func fetch(city: String) async throws -> WeatherSnapshot {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://opendata.baidu.com/data/inner")!
        components.queryItems = [
            URLQueryItem(name: "tn", value: "reserved_all_res_tn"),
            URLQueryItem(name: "type", value: "json"),
            URLQueryItem(name: "resource_id", value: "4982"),
            URLQueryItem(name: "query", value: trimmed.isEmpty ? "天气" : "\(trimmed)天气")
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = root["Result"] as? [[String: Any]],
            let display = results.first?["DisplayData"] as? [String: Any],
            let resultData = display["resultData"] as? [String: Any],
            let tplData = resultData["tplData"] as? [String: Any],
            let snapshot = WeatherSnapshot(baidu: tplData)
        else {
            throw URLError(.cannotParseResponse)
        }
        return snapshot
    }

    private static func loadCache() -> [String: Record] {
        if let cache = lock.withLock({ memoryCache }) {
            return cache
        }
        guard
            let url = cacheURL,
            let data = try? Data(contentsOf: url),
            let cache = try? JSONDecoder().decode([String: Record].self, from: data)
        else {
            return [:]
        }
        lock.withLock { memoryCache = cache }
        return cache
    }

    private static func saveCache(_ cache: [String: Record]) {
        lock.withLock { memoryCache = cache }
        guard let url = cacheURL, let data = try? JSONEncoder().encode(cache) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}

/// 百度日历（https://www.baidu.com/s?wd=日历）同源数据，按月缓存在扩展容器内。
enum CalendarDataStore {
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    private struct MonthRecord: Codable {
        var fetchedAt: Date
        var days: [CalendarDay]
    }

    private static let lock = NSLock()
    private static var memoryCache: [String: MonthRecord]?
    private static var memoryDays: [WidgetDateKey: CalendarDay]?

    private static var cacheURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DesktopCalendar", isDirectory: true)
            .appendingPathComponent("baidu-calendar-cache.json")
    }

    static func cachedDays() -> [WidgetDateKey: CalendarDay] {
        if let days = lock.withLock({ memoryDays }) {
            return days
        }
        let days = loadCache().values.reduce(into: [WidgetDateKey: CalendarDay]()) { result, record in
            for day in record.days {
                result[day.key] = day
            }
        }
        lock.withLock { memoryDays = days }
        return days
    }

    /// 百度接口按“某年某月”查询时会同时返回前后各一个月，所以每个中心月份覆盖三个月。
    /// 返回值表示缓存内容是否真的发生了变化。
    @discardableResult
    static func refreshIfNeeded(centers: [WidgetDateKey], now: Date = Date()) async -> Bool {
        var cache = loadCache()
        var fetched = false
        var contentChanged = false
        var visited: Set<WidgetDateKey> = []

        for center in centers.map(\.monthStart) where visited.insert(center).inserted {
            let covered = [center.addingMonths(-1), center, center.addingMonths(1)]
            let isComplete = covered.allSatisfy { cache[$0.monthKey] != nil }
            let isFresh = cache[center.monthKey].map {
                now.timeIntervalSince($0.fetchedAt) < refreshInterval
            } ?? false
            if isComplete && isFresh {
                continue
            }
            guard let days = try? await fetch(center), !days.isEmpty else {
                continue
            }
            for (monthKey, monthDays) in Dictionary(grouping: days, by: { $0.key.monthKey }) {
                let sorted = monthDays.sorted { $0.key < $1.key }
                if cache[monthKey]?.days != sorted {
                    contentChanged = true
                }
                cache[monthKey] = MonthRecord(fetchedAt: now, days: sorted)
            }
            fetched = true
        }

        if fetched {
            saveCache(cache)
        }
        return contentChanged
    }

    private static func fetch(_ month: WidgetDateKey) async throws -> [CalendarDay] {
        var components = URLComponents(string: "https://opendata.baidu.com/data/inner")!
        components.queryItems = [
            URLQueryItem(name: "tn", value: "reserved_all_res_tn"),
            URLQueryItem(name: "type", value: "json"),
            URLQueryItem(name: "resource_id", value: "52109"),
            URLQueryItem(name: "query", value: "\(month.year)年\(month.month)月"),
            URLQueryItem(name: "apiType", value: "yearMonthData")
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = root["Result"] as? [[String: Any]],
            let display = results.first?["DisplayData"] as? [String: Any],
            let resultData = display["resultData"] as? [String: Any],
            let tplData = resultData["tplData"] as? [String: Any],
            let payload = tplData["data"] as? [String: Any],
            let almanac = payload["almanac"] as? [[String: Any]]
        else {
            throw URLError(.cannotParseResponse)
        }
        return almanac.compactMap(CalendarDay.init(baidu:))
    }

    private static func loadCache() -> [String: MonthRecord] {
        if let cache = lock.withLock({ memoryCache }) {
            return cache
        }
        guard
            let url = cacheURL,
            let data = try? Data(contentsOf: url),
            let cache = try? JSONDecoder().decode([String: MonthRecord].self, from: data)
        else {
            return [:]
        }
        lock.withLock { memoryCache = cache }
        return cache
    }

    private static func saveCache(_ cache: [String: MonthRecord]) {
        lock.withLock {
            memoryCache = cache
            memoryDays = nil
        }
        guard let url = cacheURL, let data = try? JSONEncoder().encode(cache) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
