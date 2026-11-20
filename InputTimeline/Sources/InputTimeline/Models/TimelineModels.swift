import Foundation

enum TimelineItemKind: String, Codable, CaseIterable, Hashable {
    case keyboard = "键盘"
    case copy = "复制"
    case paste = "粘贴"
}

enum TimelineKindFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case keyboard = "键盘"
    case copy = "复制"
    case paste = "粘贴"

    var id: String { rawValue }

    var itemKind: TimelineItemKind? {
        switch self {
        case .all: return nil
        case .keyboard: return .keyboard
        case .copy: return .copy
        case .paste: return .paste
        }
    }
}

struct TimelineItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let kind: TimelineItemKind
    var start: String?
    var end: String?
    var at: String?
    var appName: String?
    var text: String

    init(
        id: UUID = UUID(),
        kind: TimelineItemKind,
        start: String? = nil,
        end: String? = nil,
        at: String? = nil,
        appName: String? = nil,
        text: String
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.at = at
        self.appName = appName
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case start
        case end
        case at
        case appName
        case text
    }
}

struct DailyTimeline: Codable, Hashable {
    let date: String
    let silenceGapSeconds: Int
    let items: [TimelineItem]
    var keyCounts: [String: Int]?
}

enum MainContentTab: String, CaseIterable, Identifiable, Hashable {
    case timeline = "时间线"
    case insights = "统计洞察"
    case settings = "偏好设置"

    var id: String { rawValue }
}

enum InsightsRangePreset: String, CaseIterable, Identifiable, Hashable, Sendable {
    case today = "今日"
    case yesterday = "昨日"
    case last7Days = "最近 7 天"
    case thisWeek = "本周"
    case custom = "自定义"

    var id: String { rawValue }
}

struct InsightsDateRange: Hashable, Sendable {
    let preset: InsightsRangePreset
    let startDay: String
    let endDay: String

    var isSingleDay: Bool {
        startDay == endDay
    }

    func resolvedDays() -> [String] {
        TimelineFormatters.enumerateDays(from: startDay, to: endDay)
    }

    var highlightedDaySet: Set<String> {
        Set(resolvedDays())
    }

    static func singleDay(_ day: String) -> InsightsDateRange {
        let todayKey = TimelineFormatters.formatDayKey(Date())
        if day == todayKey {
            return InsightsDateRange(preset: .today, startDay: day, endDay: day)
        }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           day == TimelineFormatters.formatDayKey(yesterday) {
            return InsightsDateRange(preset: .yesterday, startDay: day, endDay: day)
        }
        return InsightsDateRange(preset: .custom, startDay: day, endDay: day)
    }

    static func forPreset(_ preset: InsightsRangePreset, referenceDate: Date = Date()) -> InsightsDateRange {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)
        let todayKey = TimelineFormatters.formatDayKey(todayStart)

        switch preset {
        case .today:
            return InsightsDateRange(preset: .today, startDay: todayKey, endDay: todayKey)
        case .yesterday:
            let yDate = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            let yKey = TimelineFormatters.formatDayKey(yDate)
            return InsightsDateRange(preset: .yesterday, startDay: yKey, endDay: yKey)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            return InsightsDateRange(
                preset: .last7Days,
                startDay: TimelineFormatters.formatDayKey(start),
                endDay: todayKey
            )
        case .thisWeek:
            var mondayCal = calendar
            mondayCal.firstWeekday = 2
            let comps = mondayCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart)
            let monday = mondayCal.date(from: comps) ?? todayStart
            return InsightsDateRange(
                preset: .thisWeek,
                startDay: TimelineFormatters.formatDayKey(monday),
                endDay: todayKey
            )
        case .custom:
            return InsightsDateRange(preset: .custom, startDay: todayKey, endDay: todayKey)
        }
    }
}

struct ActivityBucketSlice: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let minutes: Int
    let colorIndex: Int
}

struct HourlyActivityStat: Identifiable, Hashable, Sendable {
    let hour: Int
    let totalMinutes: Int
    let eventCount: Int
    let appSlices: [ActivityBucketSlice]

    var id: Int { hour }
}

struct DailyActivityStat: Identifiable, Hashable, Sendable {
    let date: String
    let shortLabel: String
    let fullLabel: String
    let totalMinutes: Int
    let eventCount: Int
    let appSlices: [ActivityBucketSlice]

    var id: String { date }
}

struct AppActivitySummary: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let minutes: Int
    let eventCount: Int
    let colorIndex: Int
}

struct KeyHeatmapStat: Identifiable, Hashable, Sendable {
    let keyCode: Int
    let label: String
    let count: Int

    var id: Int { keyCode }
}

struct DailyInsights: Hashable, Sendable {
    let range: InsightsDateRange
    let date: String
    let isMultiDay: Bool
    let totalDaysInRange: Int
    let activeDaysCount: Int
    let daysWithKeyDataCount: Int
    let totalActiveMinutes: Int
    let averageDailyMinutes: Int
    let peakHour: Int?
    let peakHourMinutes: Int
    let busiestDay: DailyActivityStat?
    let totalEvents: Int
    let totalCharactersTyped: Int
    let hourlyStats: [HourlyActivityStat]
    let dailyStats: [DailyActivityStat]
    let appSummaries: [AppActivitySummary]
    let keyCounts: [Int: Int]
    let totalKeyPresses: Int
    let topKeys: [KeyHeatmapStat]
    let hasKeyHeatmapData: Bool
}

struct TimelineAppCount: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { name }
}

struct TimelineDisplayItem: Identifiable, Hashable {
    let id: UUID
    let item: TimelineItem
    let originalCharacterCount: Int
    let isTruncated: Bool
    let timeClock: String
    let durationLabel: String?
    let blankPlaceholder: String?
    let formattedPreview: String
    let hasControlSymbols: Bool
    let styledPreview: AttributedString
    let shouldAllowInspect: Bool
}

struct DailyTimelinePage: Hashable {
    let date: String
    let silenceGapSeconds: Int
    let items: [TimelineDisplayItem]
    let totalCount: Int
    let dayTotalCount: Int
    let kindCounts: [TimelineItemKind: Int]
    let appCounts: [String: Int]
    let sortedApps: [TimelineAppCount]
    let activeKindFilter: TimelineItemKind?
    let activeAppFilter: String?
    let activeSearchQuery: String
    let loadedCount: Int
    let hasMore: Bool
}

struct InspectedTimelineEntry: Identifiable, Hashable {
    let id: UUID
    let item: TimelineItem
    let fullText: String
}

struct KeyboardSegment {
    var start: Date
    var end: Date
    var appName: String?
    var text: String
}
