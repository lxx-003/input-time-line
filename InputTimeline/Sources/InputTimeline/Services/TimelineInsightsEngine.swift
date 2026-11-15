import Foundation

enum KeyboardLayoutSpec {
    struct KeyDefinition: Identifiable, Hashable, Sendable {
        let id: String
        let keyCode: Int?
        let label: String
        let secondaryLabel: String?
        let fullName: String
        let unitWidth: CGFloat

        init(
            id: String? = nil,
            keyCode: Int?,
            label: String,
            secondaryLabel: String? = nil,
            fullName: String? = nil,
            unitWidth: CGFloat = 1.0
        ) {
            self.id = id ?? (keyCode.map { "kc-\($0)" } ?? "label-\(label)")
            self.keyCode = keyCode
            self.label = label
            self.secondaryLabel = secondaryLabel
            self.fullName = fullName ?? label
            self.unitWidth = unitWidth
        }
    }

    static let row1: [KeyDefinition] = [
        KeyDefinition(keyCode: 53, label: "esc", fullName: "Escape", unitWidth: 1.45),
        KeyDefinition(keyCode: 122, label: "F1", unitWidth: 0.975),
        KeyDefinition(keyCode: 120, label: "F2", unitWidth: 0.975),
        KeyDefinition(keyCode: 99, label: "F3", unitWidth: 0.975),
        KeyDefinition(keyCode: 118, label: "F4", unitWidth: 0.975),
        KeyDefinition(keyCode: 96, label: "F5", unitWidth: 0.975),
        KeyDefinition(keyCode: 97, label: "F6", unitWidth: 0.975),
        KeyDefinition(keyCode: 98, label: "F7", unitWidth: 0.975),
        KeyDefinition(keyCode: 100, label: "F8", unitWidth: 0.975),
        KeyDefinition(keyCode: 101, label: "F9", unitWidth: 0.975),
        KeyDefinition(keyCode: 109, label: "F10", unitWidth: 0.975),
        KeyDefinition(keyCode: 103, label: "F11", unitWidth: 0.975),
        KeyDefinition(keyCode: 111, label: "F12", unitWidth: 0.975),
        KeyDefinition(id: "lock", keyCode: nil, label: "lock", fullName: "锁屏键（系统保留）", unitWidth: 1.45)
    ]

    static let row2: [KeyDefinition] = [
        KeyDefinition(keyCode: 50, label: "`", secondaryLabel: "~", fullName: "` / ~", unitWidth: 1.0),
        KeyDefinition(keyCode: 18, label: "1", secondaryLabel: "!", unitWidth: 1.0),
        KeyDefinition(keyCode: 19, label: "2", secondaryLabel: "@", unitWidth: 1.0),
        KeyDefinition(keyCode: 20, label: "3", secondaryLabel: "#", unitWidth: 1.0),
        KeyDefinition(keyCode: 21, label: "4", secondaryLabel: "$", unitWidth: 1.0),
        KeyDefinition(keyCode: 23, label: "5", secondaryLabel: "%", unitWidth: 1.0),
        KeyDefinition(keyCode: 22, label: "6", secondaryLabel: "^", unitWidth: 1.0),
        KeyDefinition(keyCode: 26, label: "7", secondaryLabel: "&", unitWidth: 1.0),
        KeyDefinition(keyCode: 28, label: "8", secondaryLabel: "*", unitWidth: 1.0),
        KeyDefinition(keyCode: 25, label: "9", secondaryLabel: "(", unitWidth: 1.0),
        KeyDefinition(keyCode: 29, label: "0", secondaryLabel: ")", unitWidth: 1.0),
        KeyDefinition(keyCode: 27, label: "-", secondaryLabel: "_", unitWidth: 1.0),
        KeyDefinition(keyCode: 24, label: "=", secondaryLabel: "+", unitWidth: 1.0),
        KeyDefinition(keyCode: 51, label: "⌫", fullName: "Delete", unitWidth: 1.6)
    ]

    static let row3: [KeyDefinition] = [
        KeyDefinition(keyCode: 48, label: "⇥", fullName: "Tab", unitWidth: 1.6),
        KeyDefinition(keyCode: 12, label: "Q", unitWidth: 1.0),
        KeyDefinition(keyCode: 13, label: "W", unitWidth: 1.0),
        KeyDefinition(keyCode: 14, label: "E", unitWidth: 1.0),
        KeyDefinition(keyCode: 15, label: "R", unitWidth: 1.0),
        KeyDefinition(keyCode: 17, label: "T", unitWidth: 1.0),
        KeyDefinition(keyCode: 16, label: "Y", unitWidth: 1.0),
        KeyDefinition(keyCode: 32, label: "U", unitWidth: 1.0),
        KeyDefinition(keyCode: 34, label: "I", unitWidth: 1.0),
        KeyDefinition(keyCode: 31, label: "O", unitWidth: 1.0),
        KeyDefinition(keyCode: 35, label: "P", unitWidth: 1.0),
        KeyDefinition(keyCode: 33, label: "[", secondaryLabel: "{", unitWidth: 1.0),
        KeyDefinition(keyCode: 30, label: "]", secondaryLabel: "}", unitWidth: 1.0),
        KeyDefinition(keyCode: 42, label: "\\", secondaryLabel: "|", unitWidth: 1.0)
    ]

    static let row4: [KeyDefinition] = [
        KeyDefinition(keyCode: 57, label: "⇪", fullName: "Caps Lock", unitWidth: 1.85),
        KeyDefinition(keyCode: 0, label: "A", unitWidth: 1.0),
        KeyDefinition(keyCode: 1, label: "S", unitWidth: 1.0),
        KeyDefinition(keyCode: 2, label: "D", unitWidth: 1.0),
        KeyDefinition(keyCode: 3, label: "F", unitWidth: 1.0),
        KeyDefinition(keyCode: 5, label: "G", unitWidth: 1.0),
        KeyDefinition(keyCode: 4, label: "H", unitWidth: 1.0),
        KeyDefinition(keyCode: 38, label: "J", unitWidth: 1.0),
        KeyDefinition(keyCode: 40, label: "K", unitWidth: 1.0),
        KeyDefinition(keyCode: 37, label: "L", unitWidth: 1.0),
        KeyDefinition(keyCode: 41, label: ";", secondaryLabel: ":", unitWidth: 1.0),
        KeyDefinition(keyCode: 39, label: "'", secondaryLabel: "\"", unitWidth: 1.0),
        KeyDefinition(keyCode: 36, label: "↩", fullName: "Return", unitWidth: 1.75)
    ]

    static let row5: [KeyDefinition] = [
        KeyDefinition(keyCode: 56, label: "⇧", fullName: "左 Shift", unitWidth: 2.3),
        KeyDefinition(keyCode: 6, label: "Z", unitWidth: 1.0),
        KeyDefinition(keyCode: 7, label: "X", unitWidth: 1.0),
        KeyDefinition(keyCode: 8, label: "C", unitWidth: 1.0),
        KeyDefinition(keyCode: 9, label: "V", unitWidth: 1.0),
        KeyDefinition(keyCode: 11, label: "B", unitWidth: 1.0),
        KeyDefinition(keyCode: 45, label: "N", unitWidth: 1.0),
        KeyDefinition(keyCode: 46, label: "M", unitWidth: 1.0),
        KeyDefinition(keyCode: 43, label: ",", secondaryLabel: "<", unitWidth: 1.0),
        KeyDefinition(keyCode: 47, label: ".", secondaryLabel: ">", unitWidth: 1.0),
        KeyDefinition(keyCode: 44, label: "/", secondaryLabel: "?", unitWidth: 1.0),
        KeyDefinition(keyCode: 60, label: "⇧", fullName: "右 Shift", unitWidth: 2.3)
    ]

    static let row6Left: [KeyDefinition] = [
        KeyDefinition(keyCode: 63, label: "fn", fullName: "fn / Globe", unitWidth: 1.0),
        KeyDefinition(keyCode: 59, label: "⌃", fullName: "Control", unitWidth: 1.0),
        KeyDefinition(keyCode: 58, label: "⌥", fullName: "左 Option", unitWidth: 1.0),
        KeyDefinition(keyCode: 55, label: "⌘", fullName: "左 Command", unitWidth: 1.3),
        KeyDefinition(keyCode: 49, label: "Space", fullName: "Space 空格", unitWidth: 5.0),
        KeyDefinition(keyCode: 54, label: "⌘", fullName: "右 Command", unitWidth: 1.3),
        KeyDefinition(keyCode: 61, label: "⌥", fullName: "右 Option", unitWidth: 1.0)
    ]

    static let arrowLeft = KeyDefinition(keyCode: 123, label: "◀", fullName: "左方向键", unitWidth: 1.0)
    static let arrowUp = KeyDefinition(keyCode: 126, label: "▲", fullName: "上方向键", unitWidth: 1.0)
    static let arrowDown = KeyDefinition(keyCode: 125, label: "▼", fullName: "下方向键", unitWidth: 1.0)
    static let arrowRight = KeyDefinition(keyCode: 124, label: "▶", fullName: "右方向键", unitWidth: 1.0)

    static let totalUnitsPerRow: CGFloat = 14.6

    static let keyNameByCode: [Int: String] = {
        var map: [Int: String] = [
            62: "右 Control",
            76: "数字键盘 Enter",
            117: "Forward Delete"
        ]
        let all = row1 + row2 + row3 + row4 + row5 + row6Left + [arrowLeft, arrowUp, arrowDown, arrowRight]
        for key in all {
            if let code = key.keyCode {
                map[code] = key.fullName
            }
        }
        return map
    }()

    static func displayName(for keyCode: Int) -> String {
        keyNameByCode[keyCode] ?? "Key #\(keyCode)"
    }
}

enum TimelineInsightsEngine {
    struct DayRawSummary: Sendable {
        let date: String
        let totalEvents: Int
        let totalCharactersTyped: Int
        let totalActiveMinutes: Int
        let hourTotals: [Int]
        let hourEventCounts: [Int]
        let hourAppMinutes: [[String: Int]]
        let appTotalMinutes: [String: Int]
        let appEventCounts: [String: Int]
        let keyCounts: [Int: Int]
        let totalKeyPresses: Int

        static func empty(date: String) -> DayRawSummary {
            DayRawSummary(
                date: date,
                totalEvents: 0,
                totalCharactersTyped: 0,
                totalActiveMinutes: 0,
                hourTotals: Array(repeating: 0, count: 24),
                hourEventCounts: Array(repeating: 0, count: 24),
                hourAppMinutes: Array(repeating: [:], count: 24),
                appTotalMinutes: [:],
                appEventCounts: [:],
                keyCounts: [:],
                totalKeyPresses: 0
            )
        }
    }

    static func computeDailyInsights(
        date: String,
        items: [TimelineItem],
        rawKeyCounts: [String: Int]?
    ) -> DailyInsights {
        let summary = computeDayRawSummary(date: date, items: items, rawKeyCounts: rawKeyCounts)
        return aggregateInsights(range: .singleDay(date), summaries: [summary])
    }

    static func computeDayRawSummary(
        date: String,
        items: [TimelineItem],
        rawKeyCounts: [String: Int]?
    ) -> DayRawSummary {
        var minuteAppWeights: [[String: Int]] = Array(repeating: [:], count: 1440)
        var appEventCounts: [String: Int] = [:]
        var hourEventCounts = Array(repeating: 0, count: 24)
        var totalCharactersTyped = 0

        for item in items {
            let appName = normalizedAppName(item.appName)
            appEventCounts[appName, default: 0] += 1

            switch item.kind {
            case .keyboard:
                totalCharactersTyped += item.text.count
                let startClock = minuteOfDay(from: item.start)
                let endClock = minuteOfDay(from: item.end)
                if let startMin = startClock {
                    let resolvedEnd = max(startMin, endClock ?? startMin)
                    hourEventCounts[startMin / 60] += 1
                    for minute in startMin...resolvedEnd {
                        let weight = (minute == startMin || minute == resolvedEnd) ? 2 : 3
                        minuteAppWeights[minute][appName, default: 0] += weight
                    }
                }
            case .copy, .paste:
                if let minute = minuteOfDay(from: item.at) {
                    hourEventCounts[minute / 60] += 1
                    minuteAppWeights[minute][appName, default: 0] += 1
                }
            }
        }

        // Resolve dominant app per active minute (each active minute = 1 minute, max 60/hour)
        var appTotalMinutes: [String: Int] = [:]
        var hourAppMinutes: [[String: Int]] = Array(repeating: [:], count: 24)
        var hourTotals = Array(repeating: 0, count: 24)

        for minute in 0..<1440 {
            let appWeights = minuteAppWeights[minute]
            guard !appWeights.isEmpty else { continue }

            let hour = minute / 60
            hourTotals[hour] += 1

            if let dominantApp = appWeights.max(by: { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.key > rhs.key
            })?.key {
                appTotalMinutes[dominantApp, default: 0] += 1
                hourAppMinutes[hour][dominantApp, default: 0] += 1
            }
        }

        var parsedKeyCounts: [Int: Int] = [:]
        if let rawKeyCounts {
            for (rawCode, count) in rawKeyCounts where count > 0 {
                if let code = Int(rawCode) {
                    parsedKeyCounts[code, default: 0] += count
                }
            }
        }

        let totalActiveMinutes = hourTotals.reduce(0, +)
        let totalKeyPresses = parsedKeyCounts.values.reduce(0, +)

        return DayRawSummary(
            date: date,
            totalEvents: items.count,
            totalCharactersTyped: totalCharactersTyped,
            totalActiveMinutes: totalActiveMinutes,
            hourTotals: hourTotals,
            hourEventCounts: hourEventCounts,
            hourAppMinutes: hourAppMinutes,
            appTotalMinutes: appTotalMinutes,
            appEventCounts: appEventCounts,
            keyCounts: parsedKeyCounts,
            totalKeyPresses: totalKeyPresses
        )
    }

    static func aggregateInsights(
        range: InsightsDateRange,
        summaries: [DayRawSummary]
    ) -> DailyInsights {
        var combinedAppMinutes: [String: Int] = [:]
        var combinedAppEvents: [String: Int] = [:]
        var combinedHourTotals = Array(repeating: 0, count: 24)
        var combinedHourEvents = Array(repeating: 0, count: 24)
        var combinedHourAppMinutes: [[String: Int]] = Array(repeating: [:], count: 24)
        var combinedKeyCounts: [Int: Int] = [:]

        var totalActiveMinutes = 0
        var totalEvents = 0
        var totalCharactersTyped = 0
        var totalKeyPresses = 0
        var activeDaysCount = 0
        var daysWithKeyDataCount = 0

        for summary in summaries {
            totalActiveMinutes += summary.totalActiveMinutes
            totalEvents += summary.totalEvents
            totalCharactersTyped += summary.totalCharactersTyped
            totalKeyPresses += summary.totalKeyPresses

            if summary.totalActiveMinutes > 0 || summary.totalEvents > 0 {
                activeDaysCount += 1
            }
            if summary.totalKeyPresses > 0 {
                daysWithKeyDataCount += 1
            }

            for (app, mins) in summary.appTotalMinutes {
                combinedAppMinutes[app, default: 0] += mins
            }
            for (app, cnt) in summary.appEventCounts {
                combinedAppEvents[app, default: 0] += cnt
            }
            for hour in 0..<24 {
                combinedHourTotals[hour] += summary.hourTotals[hour]
                combinedHourEvents[hour] += summary.hourEventCounts[hour]
                for (app, mins) in summary.hourAppMinutes[hour] {
                    combinedHourAppMinutes[hour][app, default: 0] += mins
                }
            }
            for (code, cnt) in summary.keyCounts {
                combinedKeyCounts[code, default: 0] += cnt
            }
        }

        let sortedApps = combinedAppMinutes.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }

        // Assign distinct Plush colors to up to 5 top apps; if > 5 apps, group 5th+ into "其他"
        let hasOtherGroup = sortedApps.count > 5
        let primaryAppLimit = hasOtherGroup ? 4 : 5
        var appColorIndexMap: [String: Int] = [:]
        var appSummaries: [AppActivitySummary] = []

        for (index, entry) in sortedApps.prefix(primaryAppLimit).enumerated() {
            appColorIndexMap[entry.key] = index
            appSummaries.append(
                AppActivitySummary(
                    id: entry.key,
                    name: entry.key,
                    minutes: entry.value,
                    eventCount: combinedAppEvents[entry.key, default: 0],
                    colorIndex: index
                )
            )
        }

        if hasOtherGroup {
            let remaining = sortedApps.dropFirst(primaryAppLimit)
            let otherMinutes = remaining.reduce(0) { $0 + $1.value }
            let otherEvents = remaining.reduce(0) { $0 + combinedAppEvents[$1.key, default: 0] }
            appSummaries.append(
                AppActivitySummary(
                    id: "__other__",
                    name: "其他应用",
                    minutes: otherMinutes,
                    eventCount: otherEvents,
                    colorIndex: -1
                )
            )
        }

        // Build 24-hour stats (used in single-day view)
        var hourlyStats: [HourlyActivityStat] = []
        hourlyStats.reserveCapacity(24)

        for hour in 0..<24 {
            let appSlices = makeAppSlices(
                idPrefix: "h\(hour)",
                rawAppMap: combinedHourAppMinutes[hour],
                appColorIndexMap: appColorIndexMap
            )
            hourlyStats.append(
                HourlyActivityStat(
                    hour: hour,
                    totalMinutes: combinedHourTotals[hour],
                    eventCount: combinedHourEvents[hour],
                    appSlices: appSlices
                )
            )
        }

        // Build per-day stats (used in multi-day view)
        let totalDaysInRange = max(1, summaries.count)
        let dailyStats: [DailyActivityStat] = summaries.map { summary in
            let slices = makeAppSlices(
                idPrefix: "d-\(summary.date)",
                rawAppMap: summary.appTotalMinutes,
                appColorIndexMap: appColorIndexMap
            )
            return DailyActivityStat(
                date: summary.date,
                shortLabel: TimelineFormatters.dailyChartAxisLabel(summary.date, totalDays: totalDaysInRange),
                fullLabel: TimelineFormatters.dailyChartFullLabel(summary.date),
                totalMinutes: summary.totalActiveMinutes,
                eventCount: summary.totalEvents,
                appSlices: slices
            )
        }

        let peakEntry = hourlyStats.max { lhs, rhs in
            if lhs.totalMinutes != rhs.totalMinutes { return lhs.totalMinutes < rhs.totalMinutes }
            return lhs.hour > rhs.hour
        }
        let peakHour = (peakEntry?.totalMinutes ?? 0) > 0 ? peakEntry?.hour : nil
        let peakHourMinutes = peakEntry?.totalMinutes ?? 0

        let busiestEntry = dailyStats.max { lhs, rhs in
            if lhs.totalMinutes != rhs.totalMinutes { return lhs.totalMinutes < rhs.totalMinutes }
            return lhs.date > rhs.date
        }
        let busiestDay = (busiestEntry?.totalMinutes ?? 0) > 0 ? busiestEntry : nil

        let averageDailyMinutes = activeDaysCount > 0
            ? Int((Double(totalActiveMinutes) / Double(activeDaysCount)).rounded())
            : 0

        let topKeys: [KeyHeatmapStat] = combinedKeyCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(8)
            .map { code, count in
                KeyHeatmapStat(
                    keyCode: code,
                    label: KeyboardLayoutSpec.displayName(for: code),
                    count: count
                )
            }

        return DailyInsights(
            range: range,
            date: range.endDay,
            isMultiDay: !range.isSingleDay,
            totalDaysInRange: totalDaysInRange,
            activeDaysCount: activeDaysCount,
            daysWithKeyDataCount: daysWithKeyDataCount,
            totalActiveMinutes: totalActiveMinutes,
            averageDailyMinutes: averageDailyMinutes,
            peakHour: peakHour,
            peakHourMinutes: peakHourMinutes,
            busiestDay: busiestDay,
            totalEvents: totalEvents,
            totalCharactersTyped: totalCharactersTyped,
            hourlyStats: hourlyStats,
            dailyStats: dailyStats,
            appSummaries: appSummaries,
            keyCounts: combinedKeyCounts,
            totalKeyPresses: totalKeyPresses,
            topKeys: topKeys,
            hasKeyHeatmapData: totalKeyPresses > 0
        )
    }

    private static func makeAppSlices(
        idPrefix: String,
        rawAppMap: [String: Int],
        appColorIndexMap: [String: Int]
    ) -> [ActivityBucketSlice] {
        var bucketMinutes: [String: (label: String, minutes: Int, colorIndex: Int)] = [:]

        for (app, mins) in rawAppMap where mins > 0 {
            if let colorIdx = appColorIndexMap[app] {
                bucketMinutes[app] = (app, mins, colorIdx)
            } else {
                let prev = bucketMinutes["__other__"]?.minutes ?? 0
                bucketMinutes["__other__"] = ("其他应用", prev + mins, -1)
            }
        }

        return bucketMinutes
            .sorted { lhs, rhs in
                let lIdx = lhs.value.colorIndex == -1 ? Int.max : lhs.value.colorIndex
                let rIdx = rhs.value.colorIndex == -1 ? Int.max : rhs.value.colorIndex
                if lIdx != rIdx { return lIdx < rIdx }
                return lhs.value.minutes > rhs.value.minutes
            }
            .map { key, value in
                ActivityBucketSlice(
                    id: "\(idPrefix)-\(key)",
                    label: value.label,
                    minutes: value.minutes,
                    colorIndex: value.colorIndex
                )
            }
    }

    private static func normalizedAppName(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未知应用" : trimmed
    }

    private static func minuteOfDay(from timestamp: String?) -> Int? {
        guard let timestamp else { return nil }
        let bytes = Array(timestamp.utf8)
        guard bytes.count >= 16, bytes[10] == 32, bytes[13] == 58 else {
            return nil
        }
        func digit(_ b: UInt8) -> Int? {
            b >= 48 && b <= 57 ? Int(b - 48) : nil
        }
        guard let h1 = digit(bytes[11]), let h2 = digit(bytes[12]),
              let m1 = digit(bytes[14]), let m2 = digit(bytes[15]) else {
            return nil
        }
        let hour = h1 * 10 + h2
        let minute = m1 * 10 + m2
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }
}
