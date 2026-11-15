import Foundation

actor TimelineStore {
    private struct CachedDayTimeline {
        let date: String
        let silenceGapSeconds: Int
        let items: [TimelineItem]
        let keyCounts: [String: Int]
        let aggregates: TimelineQueryEngine.DayAggregates
        let fileSize: Int?
        let modificationDate: Date?
    }

    private struct CachedDaySummary {
        let summary: TimelineInsightsEngine.DayRawSummary
        let fileSize: Int?
        let modificationDate: Date?
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
    private var keyCounts: [String: Int] = [:]
    private var pendingKeyboardSegment: KeyboardSegment?
    private var currentDayAggregates: TimelineQueryEngine.DayAggregates?
    private var hasDirtyKeyCounts = false
    private var keyCountsPersistTask: Task<Void, Never>?
    private var dayCache: [String: CachedDayTimeline] = [:]
    private var dayCacheOrder: [String] = []
    private let maxCachedDays = 8
    private var summaryCache: [String: CachedDaySummary] = [:]
    private var summaryCacheOrder: [String] = []
    private let maxCachedSummaries = 120

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
            if hasDirtyKeyCounts {
                try persistCurrentDay()
            }
        }
    }

    func handleKeyPress(keyCode: Int, at date: Date) async throws -> String? {
        guard isRecording else { return nil }
        try rotateDayIfNeeded(for: date)

        keyCounts[String(keyCode), default: 0] += 1
        hasDirtyKeyCounts = true
        scheduleKeyCountsPersist()
        return currentDay
    }

    private func scheduleKeyCountsPersist() {
        keyCountsPersistTask?.cancel()
        keyCountsPersistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.persistKeyCountsIfNeeded()
        }
    }

    private func persistKeyCountsIfNeeded() {
        guard hasDirtyKeyCounts else { return }
        try? persistCurrentDay()
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

        currentDayAggregates = nil
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
        currentDayAggregates = nil
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
            let previewItems = flushedItemsForPreview()
            let aggregates: TimelineQueryEngine.DayAggregates
            if let cachedAggregates = currentDayAggregates {
                aggregates = cachedAggregates
            } else {
                aggregates = TimelineQueryEngine.computeDayAggregates(from: previewItems)
                currentDayAggregates = aggregates
            }
            return TimelineQueryEngine.makeTimelinePage(
                day: day,
                silenceGapSeconds: silenceGapSeconds,
                sourceItems: previewItems,
                precomputedAggregates: aggregates,
                page: page,
                pageSize: pageSize,
                previewTextLimit: previewTextLimit,
                kindFilter: kindFilter,
                appFilter: appFilter,
                searchQuery: searchQuery
            )
        }

        if let cached = try loadCachedDay(for: day) {
            return TimelineQueryEngine.makeTimelinePage(
                day: cached.date,
                silenceGapSeconds: cached.silenceGapSeconds,
                sourceItems: cached.items,
                precomputedAggregates: cached.aggregates,
                page: page,
                pageSize: pageSize,
                previewTextLimit: previewTextLimit,
                kindFilter: kindFilter,
                appFilter: appFilter,
                searchQuery: searchQuery
            )
        }

        let trimmedApp = appFilter?.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeApp = (trimmedApp?.isEmpty == false) ? trimmedApp : nil
        return DailyTimelinePage(
            date: day,
            silenceGapSeconds: silenceGapSeconds,
            items: [],
            totalCount: 0,
            dayTotalCount: 0,
            kindCounts: [:],
            appCounts: [:],
            sortedApps: [],
            activeKindFilter: kindFilter,
            activeAppFilter: activeApp,
            activeSearchQuery: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            loadedCount: 0,
            hasMore: false
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

    func dailyInsights(for day: String) async throws -> DailyInsights {
        try await insights(for: .singleDay(day))
    }

    func insights(for range: InsightsDateRange) async throws -> DailyInsights {
        let days = range.resolvedDays()
        var summaries: [TimelineInsightsEngine.DayRawSummary] = []
        summaries.reserveCapacity(days.count)

        for day in days {
            summaries.append(try loadDayRawSummary(for: day))
        }

        return TimelineInsightsEngine.aggregateInsights(range: range, summaries: summaries)
    }

    private func loadDayRawSummary(for day: String) throws -> TimelineInsightsEngine.DayRawSummary {
        if day == currentDay {
            let previewItems = flushedItemsForPreview()
            return TimelineInsightsEngine.computeDayRawSummary(
                date: day,
                items: previewItems,
                rawKeyCounts: keyCounts.isEmpty ? nil : keyCounts
            )
        }

        let url = try fileURL(for: day)
        guard fileManager.fileExists(atPath: url.path) else {
            summaryCache.removeValue(forKey: day)
            summaryCacheOrder.removeAll { $0 == day }
            return .empty(date: day)
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = resourceValues?.fileSize
        let modDate = resourceValues?.contentModificationDate

        if let existing = summaryCache[day],
           existing.fileSize == fileSize,
           existing.modificationDate == modDate {
            touchSummaryCacheOrder(day)
            return existing.summary
        }

        if let cachedDay = dayCache[day],
           cachedDay.fileSize == fileSize,
           cachedDay.modificationDate == modDate {
            let summary = TimelineInsightsEngine.computeDayRawSummary(
                date: day,
                items: cachedDay.items,
                rawKeyCounts: cachedDay.keyCounts.isEmpty ? nil : cachedDay.keyCounts
            )
            storeSummaryCache(day: day, summary: summary, fileSize: fileSize, modDate: modDate)
            return summary
        }

        let data = try Data(contentsOf: url)
        let timeline = try decoder.decode(DailyTimeline.self, from: data)
        let summary = TimelineInsightsEngine.computeDayRawSummary(
            date: day,
            items: timeline.items,
            rawKeyCounts: timeline.keyCounts
        )
        storeSummaryCache(day: day, summary: summary, fileSize: fileSize, modDate: modDate)
        return summary
    }

    private func storeSummaryCache(
        day: String,
        summary: TimelineInsightsEngine.DayRawSummary,
        fileSize: Int?,
        modDate: Date?
    ) {
        summaryCache[day] = CachedDaySummary(
            summary: summary,
            fileSize: fileSize,
            modificationDate: modDate
        )
        touchSummaryCacheOrder(day)
        while summaryCacheOrder.count > maxCachedSummaries {
            let evicted = summaryCacheOrder.removeFirst()
            summaryCache.removeValue(forKey: evicted)
        }
    }

    private func touchSummaryCacheOrder(_ day: String) {
        summaryCacheOrder.removeAll { $0 == day }
        summaryCacheOrder.append(day)
    }

    func fullText(for day: String, matching target: TimelineItem) async throws -> String {
        let sourceItems: [TimelineItem]
        if day == currentDay {
            sourceItems = flushedItemsForPreview()
        } else if let cached = try loadCachedDay(for: day) {
            sourceItems = cached.items
        } else {
            return target.text
        }

        return TimelineQueryEngine.findFullText(in: sourceItems, matching: target)
    }

    private func loadCachedDay(for day: String) throws -> CachedDayTimeline? {
        let url = try fileURL(for: day)
        guard fileManager.fileExists(atPath: url.path) else {
            dayCache.removeValue(forKey: day)
            dayCacheOrder.removeAll { $0 == day }
            return nil
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = resourceValues?.fileSize
        let modDate = resourceValues?.contentModificationDate

        if let existing = dayCache[day],
           existing.fileSize == fileSize,
           existing.modificationDate == modDate {
            touchCacheOrder(day)
            return existing
        }

        let data = try Data(contentsOf: url)
        let timeline = try decoder.decode(DailyTimeline.self, from: data)
        let aggregates = TimelineQueryEngine.computeDayAggregates(from: timeline.items)
        let cached = CachedDayTimeline(
            date: timeline.date,
            silenceGapSeconds: timeline.silenceGapSeconds,
            items: timeline.items,
            keyCounts: timeline.keyCounts ?? [:],
            aggregates: aggregates,
            fileSize: fileSize,
            modificationDate: modDate
        )
        dayCache[day] = cached
        touchCacheOrder(day)
        evictCacheIfNeeded()
        return cached
    }

    private func touchCacheOrder(_ day: String) {
        dayCacheOrder.removeAll { $0 == day }
        dayCacheOrder.append(day)
    }

    private func evictCacheIfNeeded() {
        while dayCacheOrder.count > maxCachedDays {
            let evicted = dayCacheOrder.removeFirst()
            dayCache.removeValue(forKey: evicted)
        }
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
        keyCountsPersistTask?.cancel()
        try flushPendingKeyboardSegment()
        if hasDirtyKeyCounts {
            try persistCurrentDay()
        }
    }

    private func rotateDayIfNeeded(for date: Date) throws {
        let day = dayFormatter.string(from: date)
        guard day != currentDay else { return }

        keyCountsPersistTask?.cancel()
        try flushPendingKeyboardSegment()
        if hasDirtyKeyCounts {
            try persistCurrentDay()
        }

        currentDay = day
        items = []
        keyCounts = [:]
        pendingKeyboardSegment = nil
        currentDayAggregates = nil
        hasDirtyKeyCounts = false

        if let cached = dayCache.removeValue(forKey: day) {
            dayCacheOrder.removeAll { $0 == day }
            items = cached.items
            keyCounts = cached.keyCounts
            currentDayAggregates = cached.aggregates
            return
        }

        let url = try fileURL(for: day)
        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let timeline = try decoder.decode(DailyTimeline.self, from: data)
            items = timeline.items
            keyCounts = timeline.keyCounts ?? [:]
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
        keyCountsPersistTask?.cancel()
        hasDirtyKeyCounts = false
        dayCache.removeValue(forKey: currentDay)
        dayCacheOrder.removeAll { $0 == currentDay }
        summaryCache.removeValue(forKey: currentDay)
        summaryCacheOrder.removeAll { $0 == currentDay }
        let timeline = DailyTimeline(
            date: currentDay,
            silenceGapSeconds: silenceGapSeconds,
            items: flushedItemsForPreview(),
            keyCounts: keyCounts.isEmpty ? nil : keyCounts
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
