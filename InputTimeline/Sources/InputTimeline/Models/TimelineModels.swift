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
