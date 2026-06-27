import SwiftUI
import SwiftData

@MainActor
@Observable
final class ConversationsViewModel {
    var conversations: [Conversation] = []
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
            conversations = try context.fetch(descriptor)
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
