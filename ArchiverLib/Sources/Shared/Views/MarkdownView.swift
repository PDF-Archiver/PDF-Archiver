import SwiftUI

/// Optimized SwiftUI Markdown renderer with:
/// - Headings (#, ##, ###...)
/// - Blockquotes (>)
/// - Ordered lists (1. ...)
/// - Unordered lists (*, -, +)
/// - Paragraphs
/// Inline styles: bold/italic/code/links via AttributedString
public struct MarkdownView: View {
    let markdown: String
    @State private var blocks: [Block] = []

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    BlockRenderer(block: block)
                }
            }
            .padding()
        }
        .background(.background)
        .tint(.accentColor)
        .textSelection(.enabled)
        .task(id: markdown) {
            blocks = MarkdownParser.parse(markdown)
        }
    }
}

// MARK: - Block Renderer

private struct BlockRenderer: View {
    let block: Block
    var body: some View {
        switch block.kind {
        case .heading(let level):
            HeadingView(level: level, content: block.items.first ?? AttributedString(""))
        case .blockquote:
            BlockquoteView(content: block.items.first ?? AttributedString(""))
        case .orderedList(let start):
            OrderedListView(start: start, items: block.items)
        case .unorderedList:
            UnorderedListView(items: block.items)
        case .paragraph:
            Text(block.items.first ?? AttributedString(""))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Specialized Views

private struct HeadingView: View {
    let level: Int
    let content: AttributedString
    var body: some View {
        let base = Text(content).bold()
        switch level {
        case 1: base.font(.largeTitle)
        case 2: base.font(.title)
        case 3: base.font(.title2)
        case 4: base.font(.headline)
        case 5: base.font(.subheadline)
        default: base.font(.footnote).bold()
        }
    }
}

private struct BlockquoteView: View {
    let content: AttributedString
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(.secondary)
                .cornerRadius(2)
            Text(content)
                .italic()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct OrderedListView: View {
    let start: Int
    let items: [AttributedString]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(start + idx).")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct UnorderedListView: View {
    let items: [AttributedString]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                        .frame(minWidth: 20, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Block Model

private struct Block: Identifiable {
    enum Kind: Equatable {
        case heading(Int)
        case blockquote
        case orderedList(start: Int)
        case unorderedList
        case paragraph
    }
    let id = UUID()
    let kind: Kind
    let items: [AttributedString]
}

// MARK: - Parser

private enum MarkdownParser {
    // swiftlint:disable force_try
    private static let heading = try! NSRegularExpression(pattern: #"^\s{0,3}(#{1,6})\s+(.*)$"#)
    private static let blockquote = try! NSRegularExpression(pattern: #"^\s*>\s?(.*)$"#)
    private static let ordered = try! NSRegularExpression(pattern: #"^\s*(\d+)\.\s+(.*)$"#)
    private static let unordered = try! NSRegularExpression(pattern: #"^\s*[*+-]\s+(.*)$"#)
    // swiftlint:enable force_try

    private static let inlineOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.replacing("\r\n", with: "\n")
                        .replacing("\r", with: "\n")
                        .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                        .map(String.init)

        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1; continue
            }

            // Headings
            if let match = firstMatch(heading, in: line) {
                let level = max(1, min(6, match.int(1) ?? 1))
                blocks.append(Block(kind: .heading(level), items: [inline(match.string(2))]))
                index += 1; continue
            }

            // Blockquote
            if firstMatch(blockquote, in: line) != nil {
                var quoted: [String] = []
                while index < lines.count, let matchQ = firstMatch(blockquote, in: lines[index]) {
                    quoted.append(matchQ.string(1)); index += 1
                }
                blocks.append(Block(kind: .blockquote, items: [inline(quoted.joined(separator: "\n"))]))
                continue
            }

            // Ordered list
            if let match = firstMatch(ordered, in: line) {
                var items: [AttributedString] = [inline(match.string(2))]
                let start = match.int(1) ?? 1
                index += 1
                while index < lines.count, let matchN = firstMatch(ordered, in: lines[index]) {
                    items.append(inline(matchN.string(2))); index += 1
                }
                blocks.append(Block(kind: .orderedList(start: start), items: items))
                continue
            }

            // Unordered list
            if let match = firstMatch(unordered, in: line) {
                var items: [AttributedString] = [inline(match.string(1))]
                index += 1
                while index < lines.count, let matchN = firstMatch(unordered, in: lines[index]) {
                    items.append(inline(matchN.string(1))); index += 1
                }
                blocks.append(Block(kind: .unorderedList, items: items))
                continue
            }

            // Paragraph
            var paras: [String] = [line]; index += 1
            while index < lines.count {
                let next = lines[index]
                if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
                if firstMatch(heading, in: next) != nil { break }
                if firstMatch(blockquote, in: next) != nil { break }
                if firstMatch(ordered, in: next) != nil { break }
                if firstMatch(unordered, in: next) != nil { break }
                paras.append(next); index += 1
            }
            blocks.append(Block(kind: .paragraph, items: [inline(paras.joined(separator: "\n"))]))
        }
        return blocks
    }

    private static func inline(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: inlineOptions)) ?? AttributedString(string)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in line: String) -> NSTextCheckingResultWrapper? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        return NSTextCheckingResultWrapper(line: line, match: match)
    }

    private struct NSTextCheckingResultWrapper {
        let line: String; let match: NSTextCheckingResult
        func string(_ idx: Int) -> String { Range(match.range(at: idx), in: line).map { String(line[$0]) } ?? "" }
        func int(_ idx: Int) -> Int? { Int(string(idx)) }
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownView_Previews: PreviewProvider {
    static let sample = """
    > Quote

    # Heading
    ## Subheading

    1. Ordered
    2. Lists

    * Some
    * Other
    * List

    Regular text with **bold**, *italic*, `code`, and a [link](https://apple.com).
    """

    static var previews: some View {
        MarkdownView(markdown: sample)
            .preferredColorScheme(.light)
        MarkdownView(markdown: sample)
            .preferredColorScheme(.dark)
    }
}
#endif
