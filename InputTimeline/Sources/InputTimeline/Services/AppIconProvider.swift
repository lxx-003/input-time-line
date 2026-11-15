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
            let thumbnail = makeThumbnail(from: icon)
            cache[name] = thumbnail
            return thumbnail
        }

        if let path = resolveApplicationPath(for: name) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            let thumbnail = makeThumbnail(from: icon)
            cache[name] = thumbnail
            return thumbnail
        }

        missedApps.insert(name)
        return nil
    }

    private func makeThumbnail(from source: NSImage) -> NSImage {
        let pointSize: CGFloat = 16
        let pixelSize = 32
        let cornerRadius: CGFloat = 3.5

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return source
        }
        rep.size = NSSize(width: pointSize, height: pointSize)

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            let rect = NSRect(x: 0, y: 0, width: pointSize, height: pointSize)
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            context.flushGraphics()
        }
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: NSSize(width: pointSize, height: pointSize))
        result.addRepresentation(rep)
        return result
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
