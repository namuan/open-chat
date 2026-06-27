import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    // Soft delete properties
    var softDeleted: Bool
    var deletedAt: Date?

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
        self.softDeleted = false
        self.deletedAt = nil
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    var lastMessagePreview: String {
        messages.last?.content.prefix(80).replacingOccurrences(of: "\n", with: " ") ?? "No messages"
    }

    // MARK: - Soft Delete

    /// Marks the conversation as deleted without removing it from the store.
    func softDelete() {
        softDeleted = true
        deletedAt = Date()
    }

    /// Restores a soft-deleted conversation.
    func restore() {
        softDeleted = false
        deletedAt = nil
    }

    /// Whether this conversation has been soft-deleted and is past the 30-day retention period.
    var isExpired: Bool {
        guard softDeleted, let deletedAt else { return false }
        return Calendar.current.date(byAdding: .day, value: 30, to: deletedAt)! <= Date()
    }

    /// Number of days remaining until permanent deletion, or nil if not deleted.
    var daysUntilPermanentDeletion: Int? {
        guard softDeleted, let deletedAt else { return nil }
        let daysSinceDeletion = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        return max(30 - daysSinceDeletion, 0)
    }
}
