import Foundation

actor TimelineStore {
    private enum PagingContext {
        static let pageKey = CodingUserInfoKey(rawValue: "timeline.page")!
        static let pageSizeKey = CodingUserInfoKey(rawValue: "timeline.pageSize")!
        static let previewTextLimitKey = CodingUserInfoKey(rawValue: "timeline.previewTextLimit")!
    }

    private struct TimelinePageSnapshot: Decodable {
        let date: String
        let silenceGapSeconds: Int
        let items: [TimelineItem]
        let totalCount: Int
        let hasMore: Bool

        private enum CodingKeys: String, CodingKey {
            case date
            case silenceGapSeconds
            case items
        }

        init(from decoder: Decoder) throws {
            let page = decoder.userInfo[PagingContext.pageKey] as? Int ?? 0
            let pageSize = decoder.userInfo[PagingContext.pageSizeKey] as? Int ?? 10
            let previewTextLimit = decoder.userInfo[PagingContext.previewTextLimitKey] as? Int ?? 300
            let bufferedCount = max(pageSize * (page + 1), pageSize)

            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            silenceGapSeconds = try container.decode(Int.self, forKey: .silenceGapSeconds)

            var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
            var recentItems: [TimelineItem] = []
            recentItems.reserveCapacity(bufferedCount)

            var totalCount = 0
            while !itemsContainer.isAtEnd {
                var item = try itemsContainer.decode(TimelineItem.self)
                item.text = TimelineStore.previewText(item.text, limit: previewTextLimit)
                recentItems.append(item)
                totalCount += 1

                if recentItems.count > bufferedCount {
                    recentItems.removeFirst(recentItems.count - bufferedCount)
                }
            }

            let endIndex = max(0, recentItems.count - (page * pageSize))
            let startIndex = max(0, endIndex - pageSize)
            items = Array(recentItems[startIndex..<endIndex].reversed())
            self.totalCount = totalCount
            hasMore = totalCount > ((page + 1) * pageSize)
        }
    }

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dayFormatter: DateFormatter
    private let timestampFormatter: DateFormatter

    private var silenceGapSeconds: Int
    private var isRecording = false
    private var currentDay: String?
    private var items: [TimelineItem] = []
    private var pendingKeyboardSegment: KeyboardSegment?

    init(silenceGapSeconds: Int) {
        self.silenceGapSeconds = silenceGapSeconds

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
        self.decoder = JSONDecoder()

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar.current
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = dayFormatter

        let timestampFormatter = DateFormatter()
        timestampFormatter.calendar = Calendar.current
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.timeZone = .current
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.timestampFormatter = timestampFormatter
    }

    func setSilenceGapSeconds(_ value: Int) async throws {
        silenceGapSeconds = value
        if currentDay != nil {
            try persistCurrentDay()
        }
    }

    func setRecording(_ enabled: Bool) async throws {
        isRecording = enabled
        if !enabled {
            try flushPendingKeyboardSegment()
        }
    }

    func handleKeyboardText(_ text: String, appName: String?, at date: Date) async throws -> String? {
        guard isRecording else { return nil }
        try rotateDayIfNeeded(for: date)

        guard !text.isEmpty else { return currentDay }

        if var pending = pendingKeyboardSegment {
            let gap = date.timeIntervalSince(pending.end)
            if gap <= Double(silenceGapSeconds), pending.appName == appName {
                pending.end = date
                pending.text += text
                pendingKeyboardSegment = pending
            } else {
                appendKeyboardSegment(pending)
                pendingKeyboardSegment = KeyboardSegment(start: date, end: date, appName: appName, text: text)
            }
        } else {
            pendingKeyboardSegment = KeyboardSegment(start: date, end: date, appName: appName, text: text)
        }

        try persistCurrentDay()
        return currentDay
    }

    func handleClipboardEvent(kind: TimelineItemKind, text: String, at date: Date) async throws -> String? {
        guard isRecording else { return nil }
        try rotateDayIfNeeded(for: date)
        try flushPendingKeyboardSegment()

        items.append(
            TimelineItem(
                kind: kind,
                at: timestampFormatter.string(from: date),
                text: text
            )
        )
        try persistCurrentDay()
        return currentDay
    }

    func timelinePage(for day: String, page: Int, pageSize: Int, previewTextLimit: Int) async throws -> DailyTimelinePage {
        if day == currentDay {
            return makeTimelinePage(
                day: day,
                silenceGapSeconds: silenceGapSeconds,
                sourceItems: flushedItemsForPreview(),
                page: page,
                pageSize: pageSize,
                previewTextLimit: previewTextLimit
            )
        }

        let url = try fileURL(for: day)
        guard fileManager.fileExists(atPath: url.path) else {
            return DailyTimelinePage(
                date: day,
                silenceGapSeconds: silenceGapSeconds,
                items: [],
                totalCount: 0,
                loadedCount: 0,
                hasMore: false
            )
        }

        let data = try Data(contentsOf: url)
        let pageDecoder = JSONDecoder()
        pageDecoder.userInfo[PagingContext.pageKey] = page
        pageDecoder.userInfo[PagingContext.pageSizeKey] = pageSize
        pageDecoder.userInfo[PagingContext.previewTextLimitKey] = previewTextLimit
        let snapshot = try pageDecoder.decode(TimelinePageSnapshot.self, from: data)

        return DailyTimelinePage(
            date: snapshot.date,
            silenceGapSeconds: snapshot.silenceGapSeconds,
            items: snapshot.items,
            totalCount: snapshot.totalCount,
            loadedCount: min(snapshot.totalCount, (page + 1) * pageSize),
            hasMore: snapshot.hasMore
        )
    }

    func allAvailableDays() throws -> [String] {
        let directory = try baseDirectory()
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let names = try fileManager.contentsOfDirectory(atPath: directory.path)
        return names
            .filter { $0.hasSuffix(".json") }
            .map { $0.replacingOccurrences(of: ".json", with: "") }
            .sorted(by: >)
    }

    func exportFileURL(for day: String) async throws -> URL {
        if day == currentDay {
            try persistCurrentDay()
        }
        return try fileURL(for: day)
    }

    func flush() async throws {
        try flushPendingKeyboardSegment()
    }

    private func rotateDayIfNeeded(for date: Date) throws {
        let day = dayFormatter.string(from: date)
        guard day != currentDay else { return }

        try flushPendingKeyboardSegment()
        currentDay = day
        items = []
        pendingKeyboardSegment = nil

        let url = try fileURL(for: day)
        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let timeline = try decoder.decode(DailyTimeline.self, from: data)
            items = timeline.items
        } else {
            try persistCurrentDay()
        }
    }

    private func appendKeyboardSegment(_ segment: KeyboardSegment) {
        items.append(
            TimelineItem(
                kind: .keyboard,
                start: timestampFormatter.string(from: segment.start),
                end: timestampFormatter.string(from: segment.end),
                appName: segment.appName,
                text: segment.text
            )
        )
    }

    private func flushPendingKeyboardSegment() throws {
        guard let pendingKeyboardSegment else { return }
        appendKeyboardSegment(pendingKeyboardSegment)
        self.pendingKeyboardSegment = nil
        try persistCurrentDay()
    }

    private func flushedItemsForPreview() -> [TimelineItem] {
        guard let pendingKeyboardSegment else { return items }
        var previewItems = items
        previewItems.append(
            TimelineItem(
                kind: .keyboard,
                start: timestampFormatter.string(from: pendingKeyboardSegment.start),
                end: timestampFormatter.string(from: pendingKeyboardSegment.end),
                appName: pendingKeyboardSegment.appName,
                text: pendingKeyboardSegment.text
            )
        )
        return previewItems
    }

    private func makeDailyTimeline(_ items: [TimelineItem]) -> DailyTimeline {
        DailyTimeline(
            date: currentDay ?? dayFormatter.string(from: Date()),
            silenceGapSeconds: silenceGapSeconds,
            items: items
        )
    }

    private func makeTimelinePage(
        day: String,
        silenceGapSeconds: Int,
        sourceItems: [TimelineItem],
        page: Int,
        pageSize: Int,
        previewTextLimit: Int
    ) -> DailyTimelinePage {
        let endIndex = max(0, sourceItems.count - (page * pageSize))
        let startIndex = max(0, endIndex - pageSize)
        let pageItems = sourceItems[startIndex..<endIndex]
            .reversed()
            .map { item in
                var previewItem = item
                previewItem.text = Self.previewText(item.text, limit: previewTextLimit)
                return previewItem
            }

        return DailyTimelinePage(
            date: day,
            silenceGapSeconds: silenceGapSeconds,
            items: Array(pageItems),
            totalCount: sourceItems.count,
            loadedCount: min(sourceItems.count, (page + 1) * pageSize),
            hasMore: sourceItems.count > ((page + 1) * pageSize)
        )
    }

    private func persistCurrentDay() throws {
        guard let currentDay else { return }
        let timeline = DailyTimeline(
            date: currentDay,
            silenceGapSeconds: silenceGapSeconds,
            items: flushedItemsForPreview()
        )
        let data = try encoder.encode(timeline)
        let url = try fileURL(for: currentDay)
        try data.write(to: url, options: .atomic)
    }

    private func baseDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("InputTimeline", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func fileURL(for day: String) throws -> URL {
        try baseDirectory().appendingPathComponent("\(day).json")
    }

    private static func previewText(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }
}
