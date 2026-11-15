import Foundation

enum TimelineFormatters {
    struct DayEntry: Identifiable, Hashable {
        let id: String
        let primary: String
        let badge: String?
    }

    struct DaySection: Identifiable, Hashable {
        let id: String
        let title: String
        let days: [DayEntry]
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let chineseFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }()

    private static let chinesePaddedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM 月 dd 日"
        return formatter
    }()

    private static let chineseYearMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy 年 MM 月 dd 日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let fullWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func parseDay(_ day: String) -> Date? {
        dayParser.date(from: day)
    }

    static func formatDayKey(_ date: Date) -> String {
        dayParser.string(from: date)
    }

    static func sidebarDayDisplay(_ day: String) -> (primary: String, badge: String?) {
        guard let date = parseDay(day) else {
            return (day, nil)
        }

        let calendar = Calendar.current
        let formatted = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? chinesePaddedDateFormatter.string(from: date)
            : chineseYearMonthDayFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return (formatted, "今天")
        }
        if calendar.isDateInYesterday(date) {
            return (formatted, "昨天")
        }
        let weekday = weekdayFormatter.string(from: date)
        return (formatted, weekday)
    }

    static func detailHeaderDisplay(_ day: String) -> (title: String, subtitleTag: String?) {
        guard let date = parseDay(day) else {
            return (day, nil)
        }
        let calendar = Calendar.current
        let fullDate = chineseFullDateFormatter.string(from: date)
        let weekday = fullWeekdayFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return (fullDate, "今天 · \(weekday)")
        }
        if calendar.isDateInYesterday(date) {
            return (fullDate, "昨天 · \(weekday)")
        }
        return (fullDate, weekday)
    }

    static func enumerateDays(from startDay: String, to endDay: String) -> [String] {
        guard let start = parseDay(startDay), let end = parseDay(endDay) else {
            return startDay <= endDay ? [startDay] : [endDay]
        }
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: min(start, end))
        let normalizedEnd = calendar.startOfDay(for: max(start, end))

        var result: [String] = []
        var cursor = normalizedStart
        var guardCount = 0
        while cursor <= normalizedEnd && guardCount < 366 {
            result.append(formatDayKey(cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return result
    }

    static func shortMonthDay(_ day: String) -> String {
        guard let date = parseDay(day) else { return day }
        let comps = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%d/%02d", comps.month ?? 0, comps.day ?? 0)
    }

    static func dailyChartAxisLabel(_ day: String, totalDays: Int) -> String {
        guard let date = parseDay(day) else { return day }
        let calendar = Calendar.current
        if totalDays <= 7 {
            if calendar.isDateInToday(date) { return "今天" }
            if calendar.isDateInYesterday(date) { return "昨天" }
            return weekdayFormatter.string(from: date)
        }
        return shortMonthDay(day)
    }

    static func dailyChartFullLabel(_ day: String) -> String {
        guard let date = parseDay(day) else { return day }
        let calendar = Calendar.current
        let md = chinesePaddedDateFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "\(md) · 今天" }
        if calendar.isDateInYesterday(date) { return "\(md) · 昨天" }
        return "\(md) · \(weekdayFormatter.string(from: date))"
    }

    static func insightsHeaderDisplay(_ range: InsightsDateRange) -> (title: String, subtitleTag: String?) {
        if range.isSingleDay {
            return detailHeaderDisplay(range.startDay)
        }

        let startShort = shortMonthDay(range.startDay)
        let endShort = shortMonthDay(range.endDay)
        let dayCount = max(1, range.resolvedDays().count)

        switch range.preset {
        case .last7Days:
            return ("最近 7 天", "\(startShort) – \(endShort)")
        case .thisWeek:
            return ("本周概览", "\(startShort) – \(endShort) · \(dayCount) 天")
        case .custom, .today, .yesterday:
            return ("\(startShort) – \(endShort)", "共 \(dayCount) 天")
        }
    }

    static func groupDays(_ days: [String]) -> [DaySection] {
        let calendar = Calendar.current
        let now = Date()

        var recent: [DayEntry] = []
        var thisWeek: [DayEntry] = []
        var earlier: [DayEntry] = []

        for day in days {
            let display = sidebarDayDisplay(day)
            let entry = DayEntry(id: day, primary: display.primary, badge: display.badge)

            guard let date = parseDay(day) else {
                earlier.append(entry)
                continue
            }

            if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
                recent.append(entry)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)),
                      date >= weekAgo {
                thisWeek.append(entry)
            } else {
                earlier.append(entry)
            }
        }

        var sections: [DaySection] = []
        if !recent.isEmpty {
            sections.append(DaySection(id: "recent", title: "最近", days: recent))
        }
        if !thisWeek.isEmpty {
            sections.append(DaySection(id: "week", title: "近 7 天", days: thisWeek))
        }
        if !earlier.isEmpty {
            sections.append(DaySection(id: "earlier", title: "更早记录", days: earlier))
        }
        return sections
    }

    static func timeLabel(for item: TimelineItem) -> (clock: String, duration: String?) {
        switch item.kind {
        case .keyboard:
            let startClock = extractClock(from: item.start)
            let endClock = extractClock(from: item.end)
            let duration = durationText(start: item.start, end: item.end)
            if startClock == endClock || endClock.isEmpty {
                return (startClock.isEmpty ? "—" : startClock, duration)
            }
            return ("\(startClock) – \(endClock)", duration)
        case .copy, .paste:
            let clock = extractClock(from: item.at)
            return (clock.isEmpty ? "—" : clock, nil)
        }
    }

    static func fullTimeLabel(for item: TimelineItem) -> String {
        switch item.kind {
        case .keyboard:
            if let start = item.start, let end = item.end {
                return start == end ? start : "\(start) → \(end)"
            }
            return item.start ?? item.end ?? ""
        case .copy, .paste:
            return item.at ?? ""
        }
    }

    private static func extractClock(from timestamp: String?) -> String {
        guard let timestamp, !timestamp.isEmpty else { return "" }
        let parts = timestamp.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[1])
        }
        return timestamp
    }

    private static func durationText(start: String?, end: String?) -> String? {
        guard let start, let end else { return nil }

        let seconds: Int
        if let startSec = fastTimestampEpochSeconds(start),
           let endSec = fastTimestampEpochSeconds(end) {
            seconds = endSec - startSec
        } else if let startDate = timestampParser.date(from: start),
                  let endDate = timestampParser.date(from: end) {
            seconds = Int(endDate.timeIntervalSince(startDate).rounded())
        } else {
            return nil
        }

        guard seconds >= 1 else { return nil }
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let rem = seconds % 60
        return rem == 0 ? "\(minutes)m" : "\(minutes)m\(rem)s"
    }

    private static func fastTimestampEpochSeconds(_ s: String) -> Int? {
        // Fast ASCII parse for "yyyy-MM-dd HH:mm:ss" (19 bytes)
        let bytes = Array(s.utf8)
        guard bytes.count == 19,
              bytes[4] == 45, bytes[7] == 45, bytes[10] == 32, bytes[13] == 58, bytes[16] == 58 else {
            return nil
        }

        func digit(_ b: UInt8) -> Int? {
            b >= 48 && b <= 57 ? Int(b - 48) : nil
        }
        func twoDigits(_ i: Int) -> Int? {
            guard let a = digit(bytes[i]), let b = digit(bytes[i + 1]) else { return nil }
            return a * 10 + b
        }

        guard let y1 = twoDigits(0), let y2 = twoDigits(2),
              let month = twoDigits(5), let day = twoDigits(8),
              let hour = twoDigits(11), let minute = twoDigits(14), let second = twoDigits(17) else {
            return nil
        }
        let year = y1 * 100 + y2
        guard (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }

        // Howard Hinnant civil-from-days algorithm (accurate Gregorian day count)
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146097 + doe - 719468
        return ((days * 24 + hour) * 60 + minute) * 60 + second
    }
}
