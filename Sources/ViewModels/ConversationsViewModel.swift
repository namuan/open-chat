import SwiftUI
import SwiftData

@MainActor
@Observable
final class ConversationsViewModel {
    var conversations: [Conversation] = []
    var deletedConversations: [Conversation] = []
    var searchText: String = ""

    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        self.modelContext = context
        fetchConversations()
    }

    func fetchConversations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            let all = try context.fetch(descriptor)
            conversations = all.filter { !$0.softDeleted }
            deletedConversations = all.filter { $0.softDeleted }
        } catch {
            print("Failed to fetch conversations: \(error)")
        }
    }

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            conversations
        } else {
            conversations.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Soft Delete

    /// Soft-deletes a conversation (marks as deleted, keeps in store for 30 days).
    func softDeleteConversation(_ conversation: Conversation) {
        conversation.softDelete()
        try? modelContext?.save()
        fetchConversations()
    }

    /// Restores a soft-deleted conversation to the active list.
    func restoreConversation(_ conversation: Conversation) {
        conversation.restore()
        try? modelContext?.save()
        fetchConversations()
    }

    /// Permanently deletes a conversation from the store.
    func permanentDeleteConversation(_ conversation: Conversation) {
        guard let context = modelContext else { return }
        context.delete(conversation)
        try? context.save()
        fetchConversations()
    }

    /// Permanently deletes all conversations that were soft-deleted more than 30 days ago.
    func purgeExpiredConversations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        do {
            let allDeleted = try context.fetch(descriptor).filter { $0.softDeleted }
            let expired = allDeleted.filter { $0.isExpired }
            for conversation in expired {
                context.delete(conversation)
            }
            try context.save()
            fetchConversations()
        } catch {
            print("Failed to purge expired conversations: \(error)")
        }
    }

    /// Permanently deletes all soft-deleted conversations immediately.
    func purgeAllDeletedConversations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        do {
            let allDeleted = try context.fetch(descriptor).filter { $0.softDeleted }
            for conversation in allDeleted {
                context.delete(conversation)
            }
            try context.save()
            fetchConversations()
        } catch {
            print("Failed to purge all deleted conversations: \(error)")
        }
    }

    // MARK: - Legacy Delete (kept for backward compatibility)

    func deleteConversation(at offsets: IndexSet) {
        guard let context = modelContext else { return }
        for index in offsets {
            let conversation = conversations[index]
            context.delete(conversation)
        }
        try? context.save()
        fetchConversations()
    }

    func deleteConversation(_ conversation: Conversation) {
        guard let context = modelContext else { return }
        context.delete(conversation)
        try? context.save()
        fetchConversations()
    }
}
