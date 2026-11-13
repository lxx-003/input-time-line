import Foundation
import SwiftUI

extension TimelineFormatters {
    static func singleLineSnippet(_ raw: String, limit: Int = 72) -> String {
        let cleaned = formatDisplayText(raw)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "（空内容）"
        }
        if cleaned.count <= limit {
            return cleaned
        }
        return String(cleaned.prefix(limit)) + "..."
    }

    static func formattedRichText(_ raw: String, highlightQuery: String = "") -> Text {
        var normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        while normalized.hasSuffix("\n") {
            normalized.removeLast()
        }

        let trimmedQuery = highlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fast path: no special control characters
        let hasControls = normalized.unicodeScalars.contains { scalar in
            scalar == "\r" || scalar == "\t" || scalar == "\u{08}" || scalar == "\u{1B}"
        }
        if !hasControls {
            return highlightedTextSegment(normalized, query: trimmedQuery)
        }

        var segments: [Text] = []
        var buffer = ""

        func flushBuffer() {
            if !buffer.isEmpty {
                segments.append(highlightedTextSegment(buffer, query: trimmedQuery))
                buffer = ""
            }
        }

        func symbolText(_ systemName: String) -> Text {
            Text(Image(systemName: systemName))
                .font(.system(size: 10.5))
                .foregroundColor(PlushTheme.ink3)
        }

        let chars = Array(normalized)
        for (index, char) in chars.enumerated() {
            switch char {
            case "\r":
                flushBuffer()
                segments.append(symbolText("return"))
                if index < chars.count - 1 {
                    buffer.append("\n")
                }
            case "\t":
                flushBuffer()
                segments.append(symbolText("arrow.right.to.line"))
                buffer.append(" ")
            case "\u{08}":
                flushBuffer()
                segments.append(symbolText("delete.left"))
            case "\u{1B}":
                flushBuffer()
                segments.append(symbolText("escape"))
            default:
                buffer.append(char)
            }
        }
        flushBuffer()

        if segments.isEmpty {
            return Text("")
        }
        return segments.dropFirst().reduce(segments[0], +)
    }

    static func highlightedAttributedString(_ text: String, query: String) -> AttributedString {
        var attr = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attr }

        let lowerText = text.lowercased()
        let lowerQuery = trimmed.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].backgroundColor = PlushTheme.selectMark
                attr[attrRange].foregroundColor = PlushTheme.ink
            }
            searchStart = range.upperBound
        }
        return attr
    }

    private static func highlightedTextSegment(_ chunk: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(chunk)
        }
        return Text(highlightedAttributedString(chunk, query: query))
    }

    static func formatDisplayText(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        var output = raw.replacingOccurrences(of: "\r\n", with: "\n")
        output = output.replacingOccurrences(of: "\r", with: "↩\n")
        output = output.replacingOccurrences(of: "\t", with: "→ ")
        output = output.replacingOccurrences(of: "\u{08}", with: "⌫")
        output = output.replacingOccurrences(of: "\u{1B}", with: "⎋")
        while output.hasSuffix("\n") {
            output.removeLast()
        }
        return output
    }
}
