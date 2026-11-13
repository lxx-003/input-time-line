import Foundation

actor TimelineStore {
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

    init(
        silenceGapSeconds: Int = RecordingPreference.silenceGapSeconds,
        isRecording: Bool = RecordingPreference.enabled
    ) {
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

    func handleClipboardEvent(kind: TimelineItemKind, appName: String?, text: String, at date: Date) async throws -> String? {
        guard isRecording else { return nil }
        try rotateDayIfNeeded(for: date)
        try flushPendingKeyboardSegment()

        items.append(
            TimelineItem(
                kind: kind,
                at: timestampFormatter.string(from: date),
                appName: appName,
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
        appFilter: String? = nil,
        searchQuery: String = ""
    ) async throws -> DailyTimelinePage {
        if day == currentDay {
            return TimelineQueryEngine.makeTimelinePage(
                day: day,
                silenceGapSeconds: silenceGapSeconds,
                sourceItems: flushedItemsForPreview(),
                page: page,
                pageSize: pageSize,
                previewTextLimit: previewTextLimit,
                kindFilter: kindFilter,
                appFilter: appFilter,
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
                appCounts: [:],
                loadedCount: 0,
                hasMore: false
            )
        }

        let data = try Data(contentsOf: url)
        return try TimelineQueryEngine.decodeTimelinePage(
            from: data,
            page: page,
            pageSize: pageSize,
            previewTextLimit: previewTextLimit,
            kindFilter: kindFilter,
            appFilter: appFilter,
            searchQuery: searchQuery
        )
    }

    func recentEntries(limit: Int = 5, previewTextLimit: Int = 200) async throws -> (day: String?, items: [TimelineDisplayItem]) {
        let targetDay: String?
        if let currentDay {
            targetDay = currentDay
        } else {
            targetDay = try allAvailableDays().first
        }
        guard let targetDay else { return (nil, []) }

        let page = try await timelinePage(
            for: targetDay,
            page: 0,
            pageSize: limit,
            previewTextLimit: previewTextLimit
        )
        return (targetDay, page.items)
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

        return TimelineQueryEngine.findFullText(in: sourceItems, matching: target)
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
}
