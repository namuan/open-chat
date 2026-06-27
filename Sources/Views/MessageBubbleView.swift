import SwiftUI

struct MessageBubbleView: View {
    let role: MessageRole
    let content: String
    var isStreaming: Bool

    init(message: Message, isStreaming: Bool = false) {
        self.role = message.role
        self.content = message.content
        self.isStreaming = isStreaming
    }

    init(role: MessageRole, content: String, isStreaming: Bool = false) {
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }

    private var isUser: Bool { role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                // Assistant avatar
                AvatarView(role: role)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Role label
                Text(isUser ? "You" : role.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                // Message content with markdown
                MarkdownContentView(content: content, isStreaming: isStreaming)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isUser
                            ? Color.blue.opacity(0.9)
                            : Color(.systemGray5)
                    )
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser {
                // User avatar
                AvatarView(role: role)
            }
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let role: MessageRole

    var body: some View {
        Image(systemName: role == .user ? "person.circle.fill" : "brain.head.profile")
            .font(.title3)
            .foregroundStyle(role == .user ? .blue : .purple)
            .frame(width: 30, height: 30)
    }
}

// MARK: - Markdown Content View

struct MarkdownContentView: View {
    let content: String
    var isStreaming: Bool

    var body: some View {
        if content.isEmpty, !isStreaming {
            Text("(empty)")
                .italic()
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Parse content into blocks
                ForEach(parseMarkdownBlocks(content), id: \.self) { block in
                    MarkdownBlockView(block: block)
                }

                if isStreaming {
                    // Blinking cursor for streaming
                    Rectangle()
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: 2, height: 16)
                        .opacity(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: true)
                }
            }
        }
    }

    private func parseMarkdownBlocks(_ text: String) -> [String] {
        // Split by double newlines for paragraph separation
        let rawBlocks = text.components(separatedBy: "\n\n")
        return rawBlocks.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Markdown Block View

struct MarkdownBlockView: View {
    let block: String

    var body: some View {
        if block.hasPrefix("```") {
            // Code block
            CodeBlockView(content: block)
        } else {
            // Regular text with inline markdown
            Text(try! AttributedString(
                markdown: block,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            ))
            .textSelection(.enabled)
        }
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let content: String

    private var language: String? {
        let lines = content.split(separator: "\n", maxSplits: 1)
        guard let firstLine = lines.first else { return nil }
        let lang = firstLine.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        return lang.isEmpty ? nil : lang
    }

    private var code: String {
        let lines = content.split(separator: "\n")
        guard lines.count > 1 else { return "" }
        // Remove first (```lang) and last (```) lines
        let codeLines = lines.dropFirst().dropLast()
        return codeLines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            role: .user,
            content: "Write a Swift function to sort an array.",
            isStreaming: false
        )
        MessageBubbleView(
            role: .assistant,
            content: "Here's a sorting function:\n\n```swift\nfunc sortArray<T: Comparable>(_ array: [T]) -> [T] {\n    return array.sorted()\n}\n```\n\nThis uses Swift's built-in `sorted()` method.",
            isStreaming: false
        )
    }
    .padding()
}
