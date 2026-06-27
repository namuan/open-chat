import SwiftUI
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    var inputText: String = ""
    var isLoading: Bool = false
    var streamingContent: String = ""
    var streamingMessageID: UUID?       // ID of the assistant msg being streamed
    var errorMessage: String?
    var selectedConversation: Conversation?

    private var modelContext: ModelContext?
    var settingsViewModel: SettingsViewModel
    private var streamTask: Task<Void, Never>?

    init(settingsViewModel: SettingsViewModel? = nil) {
        // SettingsViewModel is injected after init from the environment in ContentView
        // because @Environment values aren't available inside init().
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel()
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    func selectConversation(_ conversation: Conversation?) {
        selectedConversation = conversation
        streamingContent = ""
        errorMessage = nil
    }

    var messages: [Message] {
        selectedConversation?.sortedMessages ?? []
    }

    /// Messages to show in the chat view. During streaming, the in-progress
    /// assistant message is shown separately as the streaming bubble, so we
    /// exclude it here to avoid a double-render.
    var displayMessages: [Message] {
        let msgs = messages
        guard isLoading, let streamingID = streamingMessageID else { return msgs }
        return msgs.filter { !($0.role == .assistant && $0.id == streamingID) }
    }

    var hasMessages: Bool {
        !messages.isEmpty
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        errorMessage = nil
        isLoading = true
        streamingContent = ""

        // Validate API key up front with a clear, actionable error
        let provider = settingsViewModel.activeProvider
        let config = settingsViewModel.config(for: provider)
        if config.apiKey.isEmpty {
            // Build a helpful error that points to Settings
            let providerName = provider.displayName
            if let other = settingsViewModel.firstProviderWithKey, other != provider {
                errorMessage = "No API key for \(providerName). Tap Settings and switch to \(other.displayName), or add a \(providerName) key."
            } else {
                errorMessage = "No API key for \(providerName). Open Settings to add one."
            }
            isLoading = false
            return
        }

        guard let context = modelContext else {
            errorMessage = "Database not initialized"
            isLoading = false
            return
        }

        // Ensure we have a conversation
        if selectedConversation == nil {
            let newConversation = Conversation(title: String(text.prefix(40)))
            context.insert(newConversation)
            selectedConversation = newConversation
        }

        guard let conversation = selectedConversation else {
            isLoading = false
            return
        }

        // Update title from first message
        if conversation.messages.isEmpty {
            conversation.title = String(text.prefix(40))
        }

        // Save user message
        let userMessage = Message(role: .user, content: text, conversation: conversation)
        context.insert(userMessage)
        conversation.updatedAt = Date()
        try? context.save()

        // Build message history for API
        let chatMessages = buildChatMessages(for: conversation)

        // Create assistant message placeholder
        let assistantMessage = Message(role: .assistant, content: "", conversation: conversation)
        context.insert(assistantMessage)
        streamingMessageID = assistantMessage.id

        // Get the service
        let service = settingsViewModel.service(for: provider)

        // Stream response
        let stream = service.streamResponse(messages: chatMessages, config: config)

        do {
            for try await chunk in stream {
                streamingContent += chunk
                assistantMessage.content = streamingContent
                // Persist the assistant message as it grows, but don't bump
                // conversation.updatedAt on every chunk — that would re-render
                // the sidebar and look like a timer ticking up every second.
                try? context.save()
            }
            // Streaming finished cleanly — bump the conversation timestamp so
            // it sorts to the top of the sidebar.
            conversation.updatedAt = Date()
            try? context.save()
        } catch {
            errorMessage = error.localizedDescription
            // Remove empty assistant message on error
            if assistantMessage.content.isEmpty {
                context.delete(assistantMessage)
            }
        }

        isLoading = false
        streamingContent = ""
        streamingMessageID = nil
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isLoading = false
    }

    func deleteConversation(_ conversation: Conversation) {
        guard let context = modelContext else { return }
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        context.delete(conversation)
        try? context.save()
    }

    func newConversation() {
        // Cancel any in-flight stream so we don't keep streaming into the new chat
        streamTask?.cancel()
        streamTask = nil
        isLoading = false
        streamingContent = ""
        errorMessage = nil
        inputText = ""

        guard let context = modelContext else {
            selectedConversation = nil
            return
        }

        let newConv = Conversation(title: "New Chat")
        context.insert(newConv)
        try? context.save()
        selectedConversation = newConv
    }

    private func buildChatMessages(for conversation: Conversation) -> [ChatMessage] {
        conversation.sortedMessages.map { msg in
            ChatMessage(
                role: msg.role == .assistant ? "assistant" : msg.role == .system ? "system" : "user",
                content: msg.content
            )
        }
    }
}
