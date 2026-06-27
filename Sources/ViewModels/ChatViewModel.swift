import SwiftUI
import SwiftData

// MARK: - ViewModel

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
    private var conversationIsPersisted = false

    // ---- Message queue ----
    /// Queued message texts, keyed by conversation UUID. Survives navigation.
    private var messageQueues: [UUID: [String]] = [:]

    init(settingsViewModel: SettingsViewModel? = nil) {
        // SettingsViewModel is injected after init from the environment in ContentView
        // because @Environment values aren't available inside init().
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel()
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    func selectConversation(_ conversation: Conversation?) {
        // Save the queue for the conversation we're leaving
        if let oldID = selectedConversation?.id, !queuedItemIDs.isEmpty {
            messageQueues[oldID] = queuedItemIDs.compactMap { queuedItemText(for: $0) }
        }

        deleteEmptyPreviousConversation(whenSelecting: conversation)

        // NEVER clear streaming content while a stream is active.
        if !isLoading {
            streamingContent = ""
        }

        selectedConversation = conversation
        conversationIsPersisted = conversation != nil
        errorMessage = nil

        // Restore the queue for the conversation we're entering
        if let newID = conversation?.id, let texts = messageQueues[newID], !texts.isEmpty {
            queuedItemIDs = texts.map { addQueuedItem(text: $0) }
        } else {
            queuedItemIDs = []
        }
    }

    /// If the previous conversation was persisted but never got any
    /// messages, delete it.  Empty chats shouldn't clutter the sidebar.
    private func deleteEmptyPreviousConversation(whenSelecting next: Conversation?) {
        guard conversationIsPersisted,
              selectedConversation?.id != next?.id,
              let prev = selectedConversation,
              prev.messages.isEmpty else { return }
        modelContext?.delete(prev)
        try? modelContext?.save()
    }

    var messages: [Message] {
        selectedConversation?.sortedMessages ?? []
    }

    var displayMessages: [Message] {
        let msgs = messages
        guard isLoading, let streamingID = streamingMessageID else { return msgs }
        return msgs.filter { !($0.role == .assistant && $0.id == streamingID) }
    }

    var hasMessages: Bool {
        !messages.isEmpty
    }

    // MARK: - Queue helpers

    /// Ordered IDs of currently-visible queued items.
    private var queuedItemIDs: [UUID] = []
    /// Maps queued-item ID → text.
    private var queuedItemTexts: [UUID: String] = [:]

    var hasQueuedMessages: Bool { !queuedItemIDs.isEmpty }

    /// Ordered texts of currently queued messages (read-only for the UI).
    var queuedMessagePreviews: [(id: UUID, text: String)] {
        queuedItemIDs.compactMap { id in
            queuedItemTexts[id].map { (id, $0) }
        }
    }

    func cancelQueuedMessage(_ id: UUID) {
        removeQueuedItem(id)
    }

    private func addQueuedItem(text: String) -> UUID {
        let id = UUID()
        queuedItemTexts[id] = text
        queuedItemIDs.append(id)
        return id
    }

    private func removeQueuedItem(_ id: UUID) {
        queuedItemIDs.removeAll { $0 == id }
        queuedItemTexts.removeValue(forKey: id)
    }

    private func queuedItemText(for id: UUID) -> String? {
        queuedItemTexts[id]
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        // If a stream is already in progress, queue this message to be
        // sent automatically once the current stream finishes.
        if isLoading {
            _ = addQueuedItem(text: text)
            return
        }

        errorMessage = nil
        isLoading = true
        streamingContent = ""

        await sendNow(text: text)

        // Stream finished — drain the queue.
        if hasQueuedMessages {
            await drainQueue()
        }
    }

    /// Actually sends `text` to the LLM. Extracted so the queue can
    /// call it without going through the guard / queue logic again.
    private func sendNow(text: String) async {
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
            conversationIsPersisted = true
            selectedConversation = newConversation
        }

        // Persist the conversation on first message if it's not yet in SwiftData
        if !conversationIsPersisted, let conv = selectedConversation {
            context.insert(conv)
            conversationIsPersisted = true
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
        // If there are queued messages, drain them now
        if hasQueuedMessages {
            Task { await drainQueue() }
        }
    }

    // MARK: - Queue draining

    /// Pops and sends queued messages one by one. Stops if a message fails.
    private func drainQueue() async {
        while hasQueuedMessages, !isLoading {
            guard let id = queuedItemIDs.first,
                  let text = queuedItemText(for: id) else { break }
            removeQueuedItem(id)
            isLoading = true
            streamingContent = ""
            await sendNow(text: text)
            // If sendNow left an error, stop draining so the user can see it
            if errorMessage != nil { break }
        }
    }

    func deleteConversation(_ conversation: Conversation) {
        guard let context = modelContext else { return }
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        conversation.softDelete()
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

        // If the previous conversation was persisted but has no messages,
        // delete it from SwiftData — empty chats shouldn't stick around.
        if conversationIsPersisted, let prev = selectedConversation, prev.messages.isEmpty {
            modelContext?.delete(prev)
            try? modelContext?.save()
        }

        conversationIsPersisted = false
        let newConv = Conversation(title: "New Chat")
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
