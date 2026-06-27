import SwiftUI

/// Re-exported markdown view for use in other modules.
/// Uses SwiftUI's built-in AttributedString markdown parsing.
///
/// For advanced rendering (code highlighting, tables, etc.),
/// see MessageBubbleView.swift which contains MarkdownContentView.
typealias MarkdownView = MarkdownContentView

// Detailed markdown view components are in MessageBubbleView.swift:
// - MarkdownContentView
// - MarkdownBlockView
// - CodeBlockView
