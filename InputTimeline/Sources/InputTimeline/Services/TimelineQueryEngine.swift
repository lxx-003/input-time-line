import Foundation

enum TimelineQueryEngine {
    private enum PagingContext {
        static let pageKey = CodingUserInfoKey(rawValue: "timeline.page")!
        static let pageSizeKey = CodingUserInfoKey(rawValue: "timeline.pageSize")!
        static let previewTextLimitKey = CodingUserInfoKey(rawValue: "timeline.previewTextLimit")!
        static let kindFilterKey = CodingUserInfoKey(rawValue: "timeline.kindFilter")!
        static let appFilterKey = CodingUserInfoKey(rawValue: "timeline.appFilter")!
        static let searchQueryKey = CodingUserInfoKey(rawValue: "timeline.searchQuery")!
    }

    private struct TimelinePageSnapshot: Decodable {
        let date: String
        let silenceGapSeconds: Int
        let items: [TimelineDisplayItem]
        let totalCount: Int
        let dayTotalCount: Int
        let kindCounts: [TimelineItemKind: Int]
        let appCounts: [String: Int]
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
            let appFilter = (decoder.userInfo[PagingContext.appFilterKey] as? String)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
            var appCounts: [String: Int] = [:]

            while !itemsContainer.isAtEnd {
                let item = try itemsContainer.decode(TimelineItem.self)
                dayTotalCount += 1
                kindCounts[item.kind, default: 0] += 1
                if let app = item.appName?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty {
                    appCounts[app, default: 0] += 1
                }

                guard TimelineQueryEngine.matches(
                    item,
                    kindFilter: kindFilter,
                    appFilter: appFilter,
                    searchQuery: searchQuery
                ) else {
                    continue
                }

                filteredTotalCount += 1
                recentItems.append(TimelineQueryEngine.makeDisplayItem(from: item, limit: previewTextLimit))

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
            self.appCounts = appCounts
            hasMore = filteredTotalCount > ((page + 1) * pageSize)
        }
    }

    static func decodeTimelinePage(
        from data: Data,
        page: Int,
        pageSize: Int,
        previewTextLimit: Int,
        kindFilter: TimelineItemKind?,
        appFilter: String?,
        searchQuery: String
    ) throws -> DailyTimelinePage {
        let pageDecoder = JSONDecoder()
        pageDecoder.userInfo[PagingContext.pageKey] = page
        pageDecoder.userInfo[PagingContext.pageSizeKey] = pageSize
        pageDecoder.userInfo[PagingContext.previewTextLimitKey] = previewTextLimit
        if let kindFilter {
            pageDecoder.userInfo[PagingContext.kindFilterKey] = kindFilter.rawValue
        }
        if let appFilter, !appFilter.isEmpty {
            pageDecoder.userInfo[PagingContext.appFilterKey] = appFilter
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
            appCounts: snapshot.appCounts,
            loadedCount: min(snapshot.totalCount, (page + 1) * pageSize),
            hasMore: snapshot.hasMore
        )
    }

    static func makeTimelinePage(
        day: String,
        silenceGapSeconds: Int,
        sourceItems: [TimelineItem],
        page: Int,
        pageSize: Int,
        previewTextLimit: Int,
        kindFilter: TimelineItemKind?,
        appFilter: String?,
        searchQuery: String
    ) -> DailyTimelinePage {
        var kindCounts: [TimelineItemKind: Int] = [:]
        var appCounts: [String: Int] = [:]
        var filteredItems: [TimelineItem] = []
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        for item in sourceItems {
            kindCounts[item.kind, default: 0] += 1
            if let app = item.appName?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty {
                appCounts[app, default: 0] += 1
            }
            if matches(item, kindFilter: kindFilter, appFilter: appFilter, searchQuery: trimmedQuery) {
                filteredItems.append(item)
            }
        }

        let endIndex = max(0, filteredItems.count - (page * pageSize))
        let startIndex = max(0, endIndex - pageSize)
        let pageItems = filteredItems[startIndex..<endIndex]
            .reversed()
            .map { makeDisplayItem(from: $0, limit: previewTextLimit) }

        return DailyTimelinePage(
            date: day,
            silenceGapSeconds: silenceGapSeconds,
            items: Array(pageItems),
            totalCount: filteredItems.count,
            dayTotalCount: sourceItems.count,
            kindCounts: kindCounts,
            appCounts: appCounts,
            loadedCount: min(filteredItems.count, (page + 1) * pageSize),
            hasMore: filteredItems.count > ((page + 1) * pageSize)
        )
    }

    static func findFullText(in sourceItems: [TimelineItem], matching target: TimelineItem) -> String {
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

    static func matches(
        _ item: TimelineItem,
        kindFilter: TimelineItemKind?,
        appFilter: String?,
        searchQuery: String
    ) -> Bool {
        if let kindFilter, item.kind != kindFilter {
            return false
        }
        if let appFilter, !appFilter.isEmpty {
            guard item.appName?.caseInsensitiveCompare(appFilter) == .orderedSame else {
                return false
            }
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

    static func makeDisplayItem(from item: TimelineItem, limit: Int) -> TimelineDisplayItem {
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

    static func previewText(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }
}
