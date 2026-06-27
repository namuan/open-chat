import Foundation
import SwiftData

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system

    var displayName: String {
        switch self {
        case .user: "You"
        case .assistant: "Assistant"
        case .system: "System"
        }
    }

    var isUser: Bool { self == .user }
    var isAssistant: Bool { self == .assistant }
}

@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var conversation: Conversation?

    init(role: MessageRole, content: String, conversation: Conversation? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.conversation = conversation
    }
}
