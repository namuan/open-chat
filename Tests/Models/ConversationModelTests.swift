import XCTest
import SwiftData
@testable import open_chat

final class ConversationModelTests: XCTestCase {

    func testTitleDefaultsToNewChat() {
        let conv = Conversation()
        XCTAssertEqual(conv.title, "New Chat")
    }

    func testCustomTitle() {
        let conv = Conversation(title: "My Chat")
        XCTAssertEqual(conv.title, "My Chat")
    }

    func testIdsAreUnique() {
        let a = Conversation()
        let b = Conversation()
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSortedMessagesByCreationDate() {
        let conv = Conversation()
        let m1 = Message(role: .user, content: "First", conversation: conv)
        let m2 = Message(role: .assistant, content: "Second", conversation: conv)
        m1.createdAt = Date(timeIntervalSince1970: 100)
        m2.createdAt = Date(timeIntervalSince1970: 200)
        conv.messages = [m2, m1]
        XCTAssertEqual(conv.sortedMessages.first?.content, "First")
        XCTAssertEqual(conv.sortedMessages.last?.content, "Second")
    }

    func testLastMessagePreviewWhenEmpty() {
        let conv = Conversation()
        XCTAssertEqual(conv.lastMessagePreview, "No messages")
    }

    func testLastMessagePreviewShowsLastMessage() {
        let conv = Conversation()
        conv.messages.append(Message(role: .user, content: "First", conversation: conv))
        conv.messages.append(Message(role: .assistant, content: "Second", conversation: conv))
        XCTAssertEqual(conv.lastMessagePreview, "Second")
    }

    func testLastMessagePreviewTruncatesLong() {
        let conv = Conversation()
        let long = String(repeating: "A", count: 100)
        conv.messages.append(Message(role: .user, content: long, conversation: conv))
        XCTAssertEqual(conv.lastMessagePreview.count, 80)
    }

    func testLastMessagePreviewReplacesNewlines() {
        let conv = Conversation()
        conv.messages.append(Message(role: .user, content: "line1\nline2", conversation: conv))
        XCTAssertEqual(conv.lastMessagePreview, "line1 line2")
    }

    // MARK: - Soft Delete

    func testConversationDefaultsToNotDeleted() {
        let conv = Conversation()
        XCTAssertFalse(conv.softDeleted)
        XCTAssertNil(conv.deletedAt)
    }

    func testSoftDeleteSetsIsDeletedAndDeletedAt() {
        let conv = Conversation()
        conv.softDelete()
        XCTAssertTrue(conv.softDeleted)
        XCTAssertNotNil(conv.deletedAt)
    }

    func testRestoreClearsIsDeletedAndDeletedAt() {
        let conv = Conversation()
        conv.softDelete()
        conv.restore()
        XCTAssertFalse(conv.softDeleted)
        XCTAssertNil(conv.deletedAt)
    }

    func testIsExpiredReturnsFalseWhenNotDeleted() {
        let conv = Conversation()
        XCTAssertFalse(conv.isExpired)
    }

    func testIsExpiredReturnsFalseWhenDeletedLessThan30DaysAgo() {
        let conv = Conversation()
        conv.softDelete()
        // deletedAt is now, so not expired
        XCTAssertFalse(conv.isExpired)
    }

    func testIsExpiredReturnsTrueWhenDeletedMoreThan30DaysAgo() {
        let conv = Conversation()
        conv.softDelete()
        // Set deletedAt to 31 days ago
        conv.deletedAt = Calendar.current.date(byAdding: .day, value: -31, to: Date())
        XCTAssertTrue(conv.isExpired)
    }

    func testDaysUntilPermanentDeletionCalculatesCorrectly() {
        let conv = Conversation()
        // Not deleted — should be nil
        XCTAssertNil(conv.daysUntilPermanentDeletion)

        // Soft delete — should be 30
        conv.softDelete()
        XCTAssertEqual(conv.daysUntilPermanentDeletion, 30)

        // Deleted 15 days ago — should be 15
        conv.deletedAt = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        XCTAssertEqual(conv.daysUntilPermanentDeletion, 15)

        // Deleted 30 days ago — should be 0 (expired)
        conv.deletedAt = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        XCTAssertEqual(conv.daysUntilPermanentDeletion, 0)

        // Deleted 31 days ago — should be 0 (expired)
        conv.deletedAt = Calendar.current.date(byAdding: .day, value: -31, to: Date())
        XCTAssertEqual(conv.daysUntilPermanentDeletion, 0)
    }

    // MARK: - SwiftData Persistence

    @MainActor
    func testSoftDeletedPropertyPersistsAfterSave() throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext

        let conv = Conversation(title: "Persist Test")
        ctx.insert(conv)
        try ctx.save()

        conv.softDelete()
        try ctx.save()

        // Fetch fresh from store
        let descriptor = FetchDescriptor<Conversation>()
        let all = try ctx.fetch(descriptor)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all.first!.softDeleted, "softDeleted should persist after save and fetch")
        XCTAssertNotNil(all.first!.deletedAt)
    }
}

// MARK: - MessageRole

final class MessageRoleTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(MessageRole.user.displayName, "You")
        XCTAssertEqual(MessageRole.assistant.displayName, "Assistant")
        XCTAssertEqual(MessageRole.system.displayName, "System")
    }

    func testIsUserIsAssistant() {
        XCTAssertTrue(MessageRole.user.isUser)
        XCTAssertFalse(MessageRole.user.isAssistant)
        XCTAssertTrue(MessageRole.assistant.isAssistant)
        XCTAssertFalse(MessageRole.assistant.isUser)
    }

    func testAllCases() {
        XCTAssertEqual(MessageRole.allCases.count, 3)
    }

    func testCodableRoundTrip() throws {
        XCTAssertEqual(try JSONDecoder().decode(MessageRole.self, from: Data(#""user""#.utf8)), .user)
        XCTAssertEqual(try JSONDecoder().decode(MessageRole.self, from: Data(#""assistant""#.utf8)), .assistant)
        XCTAssertEqual(try JSONDecoder().decode(MessageRole.self, from: Data(#""system""#.utf8)), .system)
    }
}

// MARK: - Message Model

final class MessageModelTests: XCTestCase {

    func testInit() {
        let msg = Message(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNil(msg.conversation)
        XCTAssertNotNil(msg.id)
    }

    func testInitWithConversation() {
        let conv = Conversation(title: "Chat")
        let msg = Message(role: .assistant, content: "Hi", conversation: conv)
        XCTAssertEqual(msg.conversation?.id, conv.id)
    }
}