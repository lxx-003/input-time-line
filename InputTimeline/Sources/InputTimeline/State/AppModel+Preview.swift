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
        model.insightsRange = .singleDay("2026-11-13")

        let rawItems: [TimelineItem] = [
            TimelineItem(
                kind: .keyboard,
                start: "2026-11-13 14:32:10",
                end: "2026-11-13 14:32:24",
                appName: "Cursor",
                text: "重构 ContentView 的时间线卡片样式，加上应用图标和工具栏筛选\r"
            ),
            TimelineItem(
                kind: .copy,
                at: "2026-11-13 14:28:03",
                appName: "Safari",
                text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
            ),
            TimelineItem(
                kind: .paste,
                at: "2026-11-13 14:28:09",
                appName: "Cursor",
                text: "NavigationSplitView {\n    SidebarView()\n} detail: {\n    TimelineDetailView()\n}"
            ),
            TimelineItem(
                kind: .keyboard,
                start: "2026-11-13 14:15:02",
                end: "2026-11-13 14:15:18",
                appName: "Safari",
                text: "macOS SwiftUI NavigationSplitView toolbar searchable design"
            )
        ]

        let sampleItems = rawItems.map {
            TimelineQueryEngine.makeDisplayItem(from: $0, limit: Paging.previewTextLimit)
        }

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
            sortedApps: [
                TimelineAppCount(name: "Cursor", count: 14),
                TimelineAppCount(name: "Safari", count: 10)
            ],
            activeKindFilter: nil,
            activeAppFilter: nil,
            activeSearchQuery: "",
            loadedCount: 4,
            hasMore: true
        )

        let sampleKeyCounts: [String: Int] = [
            "49": 620, "51": 390, "0": 280, "1": 240, "2": 210, "14": 340,
            "13": 195, "17": 180, "34": 230, "31": 175, "45": 165, "55": 310,
            "56": 150, "58": 140, "36": 190, "48": 130, "53": 48, "122": 64,
            "18": 120, "19": 95, "3": 110, "5": 90, "4": 135, "38": 145,
            "40": 115, "37": 125, "6": 75, "7": 85, "8": 130, "9": 95
        ]
        model.selectedInsights = TimelineInsightsEngine.computeDailyInsights(
            date: "2026-11-13",
            items: rawItems,
            rawKeyCounts: sampleKeyCounts
        )
        return model
    }
}
