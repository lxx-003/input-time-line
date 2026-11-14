import Foundation
import SwiftUI

extension TimelineFormatters {
    private static let invisibleFormattingScalars: Set<UInt32> = [
        0x200B, // ZERO WIDTH SPACE
        0x200C, // ZERO WIDTH NON-JOINER
        0x200D, // ZERO WIDTH JOINER
        0x2060, // WORD JOINER
        0xFEFF, // ZERO WIDTH NO-BREAK SPACE / BOM
        0x00AD  // SOFT HYPHEN
    ]

    private static func isControlOrHiddenScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if value == 0x0A { return false }
        return value < 0x20 || (value >= 0x7F && value <= 0x9F)
    }

    static func blankPlaceholder(for raw: String) -> String? {
        if raw.isEmpty {
            return "（空内容）"
        }

        let display = formatDisplayText(raw)
        let hasVisibleContent = display.unicodeScalars.contains { scalar in
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return false
            }
            if invisibleFormattingScalars.contains(scalar.value) {
                return false
            }
            return true
        }
        guard !hasVisibleContent else { return nil }

        let spaceCount = raw.filter { $0 == " " || $0 == "\u{3000}" }.count
        if spaceCount > 0 {
            return "（空白内容 · \(spaceCount) 个空格）"
        }
        if raw.allSatisfy({ $0 == "\n" || $0 == "\r" }) {
            return "（空内容）"
        }
        return "（不可见字符）"
    }

    static func singleLineSnippet(_ raw: String, limit: Int = 72) -> String {
        if let placeholder = blankPlaceholder(for: raw) {
            return placeholder
        }
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
        let hasControls = normalized.unicodeScalars.contains(where: isControlOrHiddenScalar)
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

        func controlTagText(_ label: String) -> Text {
            Text(label)
                .font(PlushTheme.rounded(11, weight: .medium))
                .foregroundColor(PlushTheme.ink3)
        }

        let chars = Array(normalized)
        for (index, char) in chars.enumerated() {
            switch char {
            case "\r", "\u{03}":
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
            case "\u{7F}":
                flushBuffer()
                segments.append(symbolText("delete.forward"))
            case "\u{1B}":
                flushBuffer()
                segments.append(symbolText("escape"))
            case "\u{1C}":
                flushBuffer()
                segments.append(symbolText("arrow.left"))
            case "\u{1D}":
                flushBuffer()
                segments.append(symbolText("arrow.right"))
            case "\u{1E}":
                flushBuffer()
                segments.append(symbolText("arrow.up"))
            case "\u{1F}":
                flushBuffer()
                segments.append(symbolText("arrow.down"))
            case "\u{10}":
                flushBuffer()
                segments.append(symbolText("fn"))
            case "\u{01}":
                flushBuffer()
                segments.append(symbolText("arrow.up.to.line"))
            case "\u{04}":
                flushBuffer()
                segments.append(symbolText("arrow.down.to.line"))
            case "\u{0B}":
                flushBuffer()
                segments.append(symbolText("chevron.up.2"))
            case "\u{0C}":
                flushBuffer()
                segments.append(symbolText("chevron.down.2"))
            case "\u{05}":
                flushBuffer()
                segments.append(symbolText("questionmark.circle"))
            default:
                if char.unicodeScalars.count == 1,
                   let scalar = char.unicodeScalars.first,
                   isControlOrHiddenScalar(scalar) {
                    flushBuffer()
                    segments.append(controlTagText("·"))
                } else {
                    buffer.append(char)
                }
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
        var output = ""
        output.reserveCapacity(raw.count)

        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        for char in normalized {
            switch char {
            case "\r", "\u{03}":
                output.append("↩\n")
            case "\t":
                output.append("⇥ ")
            case "\u{08}":
                output.append("⌫")
            case "\u{7F}":
                output.append("⌦")
            case "\u{1B}":
                output.append("⎋")
            case "\u{1C}":
                output.append("←")
            case "\u{1D}":
                output.append("→")
            case "\u{1E}":
                output.append("↑")
            case "\u{1F}":
                output.append("↓")
            case "\u{10}":
                output.append("[Fn]")
            case "\u{01}":
                output.append("↖")
            case "\u{04}":
                output.append("↘")
            case "\u{0B}":
                output.append("⇞")
            case "\u{0C}":
                output.append("⇟")
            case "\u{05}":
                output.append("[Help]")
            default:
                if char.unicodeScalars.count == 1,
                   let scalar = char.unicodeScalars.first,
                   isControlOrHiddenScalar(scalar) {
                    output.append("·")
                } else {
                    output.append(char)
                }
            }
        }

        while output.hasSuffix("\n") {
            output.removeLast()
        }
        return output
    }
}
