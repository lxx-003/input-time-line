import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            TimelineSidebarView()
                .frame(width: 266)

            Rectangle()
                .fill(PlushTheme.line)
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .top)

            TimelineDetailView(isSearchFocused: $isSearchFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PlushTheme.bg.ignoresSafeArea(.container, edges: .top))
        .background(WindowStyleConfigurator())
        .overlay(alignment: .top) {
            WindowTitlebarDragStrip()
                .frame(height: 32)
                .padding(.leading, 76)
                .ignoresSafeArea(.container, edges: .top)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.handleAppDidBecomeActive()
        }
        .sheet(item: $model.inspectedEntry) { entry in
            TimelineDetailSheet(entry: entry, searchQuery: model.searchText) { text in
                model.copyRawString(text)
            }
        }
        .overlay {
            // Keyboard shortcuts layer
            Group {
                Button("") {
                    model.setMainTab(.timeline)
                    isSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("") { model.setKindFilter(.all) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { model.setKindFilter(.keyboard) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { model.setKindFilter(.copy) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { model.setKindFilter(.paste) }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
        }
        .frame(minWidth: 940, minHeight: 620)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppModel.previewSample())
            .frame(width: 1080, height: 700)
    }
}
