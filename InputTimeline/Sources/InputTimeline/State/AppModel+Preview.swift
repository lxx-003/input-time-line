import Foundation

extension AppModel {
    static func previewSample() -> AppModel {
        let model = AppModel(previewMode: true)
        model.permissionGranted = true
        model.isRecording = true
        model.launchAtLogin = true
        model.statusMessage = "记录开启中"
        model.availableDays = ["2026-11-13", "2026-11-12", "2026-11-10"]
        model.availableDaySet = Set(model.availableDays)
        model.groupedDaySections = TimelineFormatters.groupDays(model.availableDays)
        model.selectedDay = "2026-11-13"

        let sampleItems: [TimelineDisplayItem] = [
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .keyboard,
                    start: "2026-11-13 14:32:10",
                    end: "2026-11-13 14:32:24",
                    appName: "Cursor",
                    text: "重构 ContentView 的时间线卡片样式，加上应用图标和工具栏筛选\r"
                ),
                originalCharacterCount: 38,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .copy,
                    at: "2026-11-13 14:28:03",
                    appName: "Safari",
                    text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
                ),
                originalCharacterCount: 78,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .paste,
                    at: "2026-11-13 14:28:09",
                    appName: "Cursor",
                    text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
                ),
                originalCharacterCount: 78,
                isTruncated: false
            ),
            TimelineDisplayItem(
                id: UUID(),
                item: TimelineItem(
                    kind: .keyboard,
                    start: "2026-11-13 14:15:02",
                    end: "2026-11-13 14:15:18",
                    appName: "Safari",
                    text: "macOS SwiftUI NavigationSplitView toolbar searchable design"
                ),
                originalCharacterCount: 59,
                isTruncated: false
            )
        ]

        model.recentMenuBarDay = "2026-11-13"
        model.recentMenuBarItems = sampleItems
        model.selectedTimeline = DailyTimelinePage(
            date: "2026-11-13",
            silenceGapSeconds: 2,
            items: sampleItems,
            totalCount: 4,
            dayTotalCount: 24,
            kindCounts: [.keyboard: 15, .copy: 5, .paste: 4],
            appCounts: ["Cursor": 14, "Safari": 10],
            loadedCount: 4,
            hasMore: true
        )
        return model
    }
}
