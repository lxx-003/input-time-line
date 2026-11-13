import SwiftUI

struct TimelineDetailHeaderCard: View {
    @EnvironmentObject private var model: AppModel
    let timeline: DailyTimelinePage

    var body: some View {
        let header = TimelineFormatters.detailHeaderDisplay(timeline.date)
        let sortedApps = timeline.appCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(header.title)
                            .font(PlushTheme.rounded(20, weight: .semibold))
                            .foregroundStyle(PlushTheme.ink)

                        if let tag = header.subtitleTag {
                            Text(tag)
                                .font(PlushTheme.rounded(11.5, weight: .semibold))
                                .foregroundStyle(PlushTheme.ink2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(PlushTheme.fill))
                        }
                    }

                    if model.kindFilter != .all || model.selectedAppFilter != nil || !model.searchText.isEmpty {
                        HStack(spacing: 6) {
                            Text("已筛选出 \(timeline.totalCount) 条")
                                .font(PlushTheme.rounded(11.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(PlushTheme.ink2)

                            Button("清除筛选") {
                                withAnimation(PlushTheme.spring) {
                                    model.clearFilters()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(PlushTheme.rounded(11.5, weight: .semibold))
                            .foregroundStyle(PlushTheme.selectA)
                        }
                    }
                }

                Spacer()

                // Odometer Counter summary badge
                VStack(alignment: .trailing, spacing: 1) {
                    Text("今日记录")
                        .font(PlushTheme.rounded(10.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                    Text("\(timeline.dayTotalCount)")
                        .font(PlushTheme.rounded(20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PlushTheme.ink)
                        .plushNumericTransition()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: PlushTheme.Radius.row, style: .continuous)
                        .fill(PlushTheme.fill)
                )
            }

            // Active Apps quick filter chips
            if !sortedApps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedApps.prefix(10), id: \.key) { appName, count in
                            let isSelected = model.selectedAppFilter?.caseInsensitiveCompare(appName) == .orderedSame
                            Button {
                                withAnimation(PlushTheme.spring) {
                                    model.toggleAppFilter(appName)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    if let icon = AppIconProvider.shared.icon(for: appName) {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .interpolation(.high)
                                            .frame(width: 13, height: 13)
                                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                    }
                                    Text(appName)
                                        .font(PlushTheme.rounded(11.5, weight: .semibold))
                                    Text("\(count)")
                                        .font(PlushTheme.rounded(10.5, weight: .semibold).monospacedDigit())
                                        .opacity(0.75)
                                }
                                .foregroundStyle(isSelected ? PlushTheme.onSelect : PlushTheme.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AnyShapeStyle(PlushTheme.selectGradient) : AnyShapeStyle(PlushTheme.fill))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .plushCardSurface(cornerRadius: PlushTheme.Radius.card, background: PlushTheme.surface)
    }
}
