import AppKit
import Foundation
import SwiftUI

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

    static func singleLineSnippet(_ raw: String, limit: Int = 72) -> String {
        let cleaned = formatDisplayText(raw)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "（空内容）"
        }
        if cleaned.count <= limit {
            return cleaned
        }
        return String(cleaned.prefix(limit)) + "..."
    }

    static func formattedRichText(_ raw: String, highlightQuery: String = "") -> Text {
        var normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        while normalized.hasSuffix("\n") {
            normalized.removeLast()
        }

        let trimmedQuery = highlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fast path: no special control characters
        let hasControls = normalized.unicodeScalars.contains { scalar in
            scalar == "\r" || scalar == "\t" || scalar == "\u{08}" || scalar == "\u{1B}"
        }
        if !hasControls {
            return highlightedTextSegment(normalized, query: trimmedQuery)
        }

        var segments: [Text] = []
        var buffer = ""

        func flushBuffer() {
            if !buffer.isEmpty {
                segments.append(highlightedTextSegment(buffer, query: trimmedQuery))
                buffer = ""
            }
        }

        func symbolText(_ systemName: String) -> Text {
            Text(Image(systemName: systemName))
                .font(.system(size: 10.5))
                .foregroundColor(PlushTheme.ink3)
        }

        let chars = Array(normalized)
        for (index, char) in chars.enumerated() {
            switch char {
            case "\r":
                flushBuffer()
                segments.append(symbolText("return"))
                if index < chars.count - 1 {
                    buffer.append("\n")
                }
            case "\t":
                flushBuffer()
                segments.append(symbolText("arrow.right.to.line"))
                buffer.append(" ")
            case "\u{08}":
                flushBuffer()
                segments.append(symbolText("delete.left"))
            case "\u{1B}":
                flushBuffer()
                segments.append(symbolText("escape"))
            default:
                buffer.append(char)
            }
        }
        flushBuffer()

        if segments.isEmpty {
            return Text("")
        }
        return segments.dropFirst().reduce(segments[0], +)
    }

    static func highlightedAttributedString(_ text: String, query: String) -> AttributedString {
        var attr = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attr }

        let lowerText = text.lowercased()
        let lowerQuery = trimmed.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].backgroundColor = PlushTheme.selectMark
                attr[attrRange].foregroundColor = PlushTheme.ink
            }
            searchStart = range.upperBound
        }
        return attr
    }

    private static func highlightedTextSegment(_ chunk: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(chunk)
        }
        return Text(highlightedAttributedString(chunk, query: query))
    }

    static func formatDisplayText(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        var output = raw.replacingOccurrences(of: "\r\n", with: "\n")
        output = output.replacingOccurrences(of: "\r", with: "↩\n")
        output = output.replacingOccurrences(of: "\t", with: "→ ")
        output = output.replacingOccurrences(of: "\u{08}", with: "⌫")
        output = output.replacingOccurrences(of: "\u{1B}", with: "⎋")
        while output.hasSuffix("\n") {
            output.removeLast()
        }
        return output
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
        guard let start, let end,
              let startDate = timestampParser.date(from: start),
              let endDate = timestampParser.date(from: end) else {
            return nil
        }
        let seconds = Int(endDate.timeIntervalSince(startDate).rounded())
        guard seconds >= 1 else { return nil }
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let rem = seconds % 60
        return rem == 0 ? "\(minutes)m" : "\(minutes)m\(rem)s"
    }
}
