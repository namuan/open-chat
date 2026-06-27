import SwiftUI
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    var inputText: String = ""
    var isLoading: Bool = false
    var streamingContent: String = ""
    var errorMessage: String?
    var selectedConversation: Conversation?

    private var modelContext: ModelContext?
    private let settingsViewModel: SettingsViewModel
    private var streamTask: Task<Void, Never>?

    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
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

        // Get the appropriate provider
        let provider = settingsViewModel.activeProvider
        let config = settingsViewModel.config(for: provider)

        // Create assistant message placeholder
        let assistantMessage = Message(role: .assistant, content: "", conversation: conversation)
        context.insert(assistantMessage)

        // Get the service
        let service = settingsViewModel.service(for: provider)

        // Stream response
        let stream = service.streamResponse(messages: chatMessages, config: config)

        do {
            for try await chunk in stream {
                streamingContent += chunk
                assistantMessage.content = streamingContent
                conversation.updatedAt = Date()
                try? context.save()
            }
        } catch {
            errorMessage = error.localizedDescription
            // Remove empty assistant message on error
            if assistantMessage.content.isEmpty {
                context.delete(assistantMessage)
            }
        }

        isLoading = false
        streamingContent = ""
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
        selectedConversation = nil
        streamingContent = ""
        errorMessage = nil
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
