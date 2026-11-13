import AppKit
import Foundation

@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()

    private var cache: [String: NSImage] = [:]
    private var missedApps: Set<String> = []

    private init() {}

    func icon(for appName: String?) -> NSImage? {
        guard let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        if let cached = cache[name] {
            return cached
        }
        if missedApps.contains(name) {
            return nil
        }

        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }),
           let icon = runningApp.icon {
            cache[name] = icon
            return icon
        }

        if let path = resolveApplicationPath(for: name) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[name] = icon
            return icon
        }

        missedApps.insert(name)
        return nil
    }

    private func resolveApplicationPath(for appName: String) -> String? {
        let candidates = [
            "/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            "/System/Library/CoreServices/\(appName).app",
            NSString(string: "~/Applications/\(appName).app").expandingTildeInPath
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
