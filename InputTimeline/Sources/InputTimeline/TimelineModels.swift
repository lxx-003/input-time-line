import Foundation

enum TimelineItemKind: String, Codable, CaseIterable {
    case keyboard = "键盘"
    case copy = "复制"
    case paste = "粘贴"
}

struct TimelineItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let kind: TimelineItemKind
    var start: String?
    var end: String?
    var at: String?
    var text: String

    init(id: UUID = UUID(), kind: TimelineItemKind, start: String? = nil, end: String? = nil, at: String? = nil, text: String) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.at = at
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case start
        case end
        case at
        case text
    }
}

struct DailyTimeline: Codable, Hashable {
    let date: String
    let silenceGapSeconds: Int
    let items: [TimelineItem]
}

struct DailyTimelinePage: Hashable {
    let date: String
    let silenceGapSeconds: Int
    let items: [TimelineItem]
    let totalCount: Int
    let loadedCount: Int
    let hasMore: Bool
}

struct KeyboardSegment {
    var start: Date
    var end: Date
    var text: String
}
