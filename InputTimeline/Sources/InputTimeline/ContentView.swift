import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("Input Timeline")
        .frame(minWidth: 940, minHeight: 620)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("开启记录", isOn: Binding(
                get: { model.isRecording },
                set: { model.toggleRecording($0) }
            ))
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                Text("键盘静默分段")
                    .font(.headline)
                Stepper(value: Binding(
                    get: { model.silenceGapSeconds },
                    set: { model.updateSilenceGap($0) }
                ), in: 1 ... 10) {
                    Text("\(model.silenceGapSeconds) 秒")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(model.permissionGranted ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(model.permissionGranted ? "输入监控权限已就绪" : "需要输入监控权限")
                        .font(.subheadline)
                }
                Button("请求权限并打开系统设置") {
                    model.requestPermission()
                }
                Text("说明：仅在记录开启时采集。密码框等安全输入域通常不会被系统提供内容。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Text("历史日期")
                    .font(.headline)
                Spacer()
                Button("刷新") {
                    model.start()
                }
                .buttonStyle(.borderless)
            }

            List(selection: Binding(
                get: { model.selectedDay },
                set: { day in
                    if let day {
                        model.selectDay(day)
                    }
                }
            )) {
                ForEach(model.availableDays, id: \.self) { day in
                    Text(day)
                        .tag(day)
                }
            }
        }
        .padding(20)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedTimeline?.date ?? "请选择日期")
                        .font(.title2.bold())
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("导出 JSON") {
                    model.exportSelectedDay()
                }
                .disabled(model.selectedDay == nil)
            }

            if let timeline = model.selectedTimeline {
                Text("silenceGapSeconds: \(timeline.silenceGapSeconds)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                List(timeline.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.kind.rawValue)
                            .font(.headline)
                        if let start = item.start, let end = item.end {
                            Text("\(start) → \(end)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let at = item.at {
                            Text(at)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.text.isEmpty ? "（空字符串）" : item.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("暂无时间线")
                        .font(.title3.weight(.semibold))
                    Text("左侧选择日期后可查看内容。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(20)
    }
}
