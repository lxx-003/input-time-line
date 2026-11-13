import Foundation

actor TimelineStore {
    private enum PagingContext {
        static let pageKey = CodingUserInfoKey(rawValue: "timeline.page")!
        static let pageSizeKey = CodingUserInfoKey(rawValue: "timeline.pageSize")!
        static let previewTextLimitKey = CodingUserInfoKey(rawValue: "timeline.previewTextLimit")!
        static let kindFilterKey = CodingUserInfoKey(rawValue: "timeline.kindFilter")!
        static let searchQueryKey = CodingUserInfoKey(rawValue: "timeline.searchQuery")!
    }

    private struct TimelinePageSnapshot: Decodable {
        let date: String
        let silenceGapSeconds: Int
        let items: [TimelineDisplayItem]
        let totalCount: Int
        let dayTotalCount: Int
        let kindCounts: [TimelineItemKind: Int]
        let hasMore: Bool

        private enum CodingKeys: String, CodingKey {
            case date
            case silenceGapSeconds
            case items
        }

        init(from decoder: Decoder) throws {
            let page = decoder.userInfo[PagingContext.pageKey] as? Int ?? 0
            let pageSize = decoder.userInfo[PagingContext.pageSizeKey] as? Int ?? 30
            let previewTextLimit = decoder.userInfo[PagingContext.previewTextLimitKey] as? Int ?? 400
            let kindFilter = (decoder.userInfo[PagingContext.kindFilterKey] as? String)
                .flatMap(TimelineItemKind.init(rawValue:))
            let searchQuery = (decoder.userInfo[PagingContext.searchQueryKey] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let bufferedCount = max(pageSize * (page + 1), pageSize)

            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            silenceGapSeconds = try container.decode(Int.self, forKey: .silenceGapSeconds)

            var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
            var recentItems: [TimelineDisplayItem] = []
            recentItems.reserveCapacity(bufferedCount)

            var dayTotalCount = 0
            var filteredTotalCount = 0
            var kindCounts: [TimelineItemKind: Int] = [:]

            while !itemsContainer.isAtEnd {
                let item = try itemsContainer.decode(TimelineItem.self)
                dayTotalCount += 1
                kindCounts[item.kind, default: 0] += 1

                guard TimelineStore.matches(item, kindFilter: kindFilter, searchQuery: searchQuery) else {
                    continue
                }

                filteredTotalCount += 1
                recentItems.append(TimelineStore.makeDisplayItem(from: item, limit: previewTextLimit))

                if recentItems.count > bufferedCount {
                    recentItems.removeFirst(recentItems.count - bufferedCount)
                }
            }

            let endIndex = max(0, recentItems.count - (page * pageSize))
            let startIndex = max(0, endIndex - pageSize)
            items = Array(recentItems[startIndex..<endIndex].reversed())
            self.totalCount = filteredTotalCount
            self.dayTotalCount = dayTotalCount
            self.kindCounts = kindCounts
            hasMore = filteredTotalCount > ((page + 1) * pageSize)
        }
    }

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dayFormatter: DateFormatter
    private let timestampFormatter: DateFormatter

    private var silenceGapSeconds: Int
    private var isRecording: Bool
    private var currentDay: String?
    private var items: [TimelineItem] = []
    private var pendingKeyboardSegment: KeyboardSegment?

    init(silenceGapSeconds: Int, isRecording: Bool = RecordingPreference.enabled) {
        self.silenceGapSeconds = silenceGapSeconds
        self.isRecording = isRecording

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

    func timelinePage(
        for day: String,
        page: Int,
        pageSize: Int,
        previewTextLimit: Int,
        kindFilter: TimelineItemKind? = nil,
        searchQuery: String = ""
    ) async throws -> DailyTimelinePage {
        if day == currentDay {
            return makeTimelinePage(
                day: day,
                silenceGapSeconds: silenceGapSeconds,
                sourceItems: flushedItemsForPreview(),
                page: page,
                pageSize: pageSize,
                previewTextLimit: previewTextLimit,
                kindFilter: kindFilter,
                searchQuery: searchQuery
            )
        }

        let url = try fileURL(for: day)
        guard fileManager.fileExists(atPath: url.path) else {
            return DailyTimelinePage(
                date: day,
                silenceGapSeconds: silenceGapSeconds,
                items: [],
                totalCount: 0,
                dayTotalCount: 0,
                kindCounts: [:],
                loadedCount: 0,
                hasMore: false
            )
        }

        let data = try Data(contentsOf: url)
        let pageDecoder = JSONDecoder()
        pageDecoder.userInfo[PagingContext.pageKey] = page
        pageDecoder.userInfo[PagingContext.pageSizeKey] = pageSize
        pageDecoder.userInfo[PagingContext.previewTextLimitKey] = previewTextLimit
        if let kindFilter {
            pageDecoder.userInfo[PagingContext.kindFilterKey] = kindFilter.rawValue
        }
        pageDecoder.userInfo[PagingContext.searchQueryKey] = searchQuery
        let snapshot = try pageDecoder.decode(TimelinePageSnapshot.self, from: data)

        return DailyTimelinePage(
            date: snapshot.date,
            silenceGapSeconds: snapshot.silenceGapSeconds,
            items: snapshot.items,
            totalCount: snapshot.totalCount,
            dayTotalCount: snapshot.dayTotalCount,
            kindCounts: snapshot.kindCounts,
            loadedCount: min(snapshot.totalCount, (page + 1) * pageSize),
            hasMore: snapshot.hasMore
        )
    }

    func fullText(for day: String, matching target: TimelineItem) async throws -> String {
        let sourceItems: [TimelineItem]
        if day == currentDay {
            sourceItems = flushedItemsForPreview()
        } else {
            let url = try fileURL(for: day)
            guard fileManager.fileExists(atPath: url.path) else {
                return target.text
            }
            let data = try Data(contentsOf: url)
            let timeline = try decoder.decode(DailyTimeline.self, from: data)
            sourceItems = timeline.items
        }

        let prefix = target.text.hasSuffix("...") ? String(target.text.dropLast(3)) : target.text
        if let matched = sourceItems.reversed().first(where: { candidate in
            candidate.kind == target.kind &&
            candidate.start == target.start &&
            candidate.end == target.end &&
            candidate.at == target.at &&
            candidate.appName == target.appName &&
            (candidate.text == target.text || (!prefix.isEmpty && candidate.text.hasPrefix(prefix)))
        }) {
            return matched.text
        }
        return target.text
    }

    func storageDirectoryURL() throws -> URL {
        try baseDirectory()
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
        previewTextLimit: Int,
        kindFilter: TimelineItemKind?,
        searchQuery: String
    ) -> DailyTimelinePage {
        var kindCounts: [TimelineItemKind: Int] = [:]
        var filteredItems: [TimelineItem] = []
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        for item in sourceItems {
            kindCounts[item.kind, default: 0] += 1
            if Self.matches(item, kindFilter: kindFilter, searchQuery: trimmedQuery) {
                filteredItems.append(item)
            }
        }

        let endIndex = max(0, filteredItems.count - (page * pageSize))
        let startIndex = max(0, endIndex - pageSize)
        let pageItems = filteredItems[startIndex..<endIndex]
            .reversed()
            .map { Self.makeDisplayItem(from: $0, limit: previewTextLimit) }

        return DailyTimelinePage(
            date: day,
            silenceGapSeconds: silenceGapSeconds,
            items: Array(pageItems),
            totalCount: filteredItems.count,
            dayTotalCount: sourceItems.count,
            kindCounts: kindCounts,
            loadedCount: min(filteredItems.count, (page + 1) * pageSize),
            hasMore: filteredItems.count > ((page + 1) * pageSize)
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

    private static func matches(_ item: TimelineItem, kindFilter: TimelineItemKind?, searchQuery: String) -> Bool {
        if let kindFilter, item.kind != kindFilter {
            return false
        }
        if searchQuery.isEmpty {
            return true
        }
        if item.text.localizedCaseInsensitiveContains(searchQuery) {
            return true
        }
        if let appName = item.appName, appName.localizedCaseInsensitiveContains(searchQuery) {
            return true
        }
        return false
    }

    private static func makeDisplayItem(from item: TimelineItem, limit: Int) -> TimelineDisplayItem {
        let originalCount = item.text.count
        var previewItem = item
        previewItem.text = previewText(item.text, limit: limit)
        return TimelineDisplayItem(
            id: item.id,
            item: previewItem,
            originalCharacterCount: originalCount,
            isTruncated: limit > 0 && originalCount > limit
        )
    }

    private static func previewText(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }
}
