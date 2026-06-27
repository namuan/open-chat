import XCTest
import SwiftData
@testable import open_chat

@MainActor
final class ConversationsViewModelTests: XCTestCase {

    var viewModel: ConversationsViewModel!
    var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        viewModel = ConversationsViewModel()
        viewModel.configure(with: container.mainContext)
    }

    override func tearDown() async throws {
        viewModel = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Fetch

    func testFetchReturnsEmptyInitially() {
        XCTAssertTrue(viewModel.conversations.isEmpty)
    }

    func testFetchReturnsInsertedConversations() throws {
        let ctx = container.mainContext
        ctx.insert(Conversation(title: "A"))
        ctx.insert(Conversation(title: "B"))
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 2)
    }

    // MARK: - Filter

    func testFilteredConversationsReturnsAllWhenSearchEmpty() throws {
        let ctx = container.mainContext
        ctx.insert(Conversation(title: "Hello"))
        ctx.insert(Conversation(title: "World"))
        try ctx.save()
        viewModel.fetchConversations()
        viewModel.searchText = ""
        XCTAssertEqual(viewModel.filteredConversations.count, 2)
    }

    func testFilteredConversationsMatchesCaseInsensitive() throws {
        let ctx = container.mainContext
        ctx.insert(Conversation(title: "Hello World"))
        ctx.insert(Conversation(title: "Goodbye"))
        try ctx.save()
        viewModel.fetchConversations()
        viewModel.searchText = "hello"
        XCTAssertEqual(viewModel.filteredConversations.count, 1)
        XCTAssertEqual(viewModel.filteredConversations.first?.title, "Hello World")
    }

    // MARK: - Delete

    func testDeleteConversationRemovesFromStore() throws {
        let ctx = container.mainContext
        let conv = Conversation(title: "Test")
        ctx.insert(conv)
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 1)
        viewModel.deleteConversation(conv)
        XCTAssertEqual(viewModel.conversations.count, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conversation>()), 0)
    }

    func testDeleteConversationAtOffset() throws {
        let ctx = container.mainContext
        ctx.insert(Conversation(title: "A"))
        ctx.insert(Conversation(title: "B"))
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 2)
        viewModel.deleteConversation(at: IndexSet(integer: 0))
        XCTAssertEqual(viewModel.conversations.count, 1)
    }

    // MARK: - Configure

    func testConfigureFetchesConversations() throws {
        let ctx = container.mainContext
        ctx.insert(Conversation(title: "X"))
        try ctx.save()
        let newVM = ConversationsViewModel()
        XCTAssertTrue(newVM.conversations.isEmpty)
        newVM.configure(with: ctx)
        XCTAssertEqual(newVM.conversations.count, 1)
    }

    // MARK: - Soft Delete

    func testFetchConversationsExcludesDeleted() throws {
        let ctx = container.mainContext
        let visible = Conversation(title: "Visible")
        let deleted = Conversation(title: "Deleted")
        ctx.insert(visible)
        ctx.insert(deleted)
        try ctx.save()
        // Soft-delete after insert so SwiftData tracks the change
        deleted.softDelete()
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertEqual(viewModel.conversations.first?.title, "Visible")
    }

    func testFetchDeletedConversationsReturnsOnlyDeleted() throws {
        let ctx = container.mainContext
        let visible = Conversation(title: "Visible")
        let deleted = Conversation(title: "Deleted")
        ctx.insert(visible)
        ctx.insert(deleted)
        try ctx.save()
        deleted.softDelete()
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
        XCTAssertEqual(viewModel.deletedConversations.first?.title, "Deleted")
    }

    func testSoftDeleteConversationMarksAsDeleted() throws {
        let ctx = container.mainContext
        let conv = Conversation(title: "To Delete")
        ctx.insert(conv)
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 1)
        viewModel.softDeleteConversation(conv)
        XCTAssertEqual(viewModel.conversations.count, 0)
        XCTAssertTrue(conv.softDeleted)
        XCTAssertNotNil(conv.deletedAt)
    }

    func testRestoreConversationRestoresToMainList() throws {
        let ctx = container.mainContext
        let conv = Conversation(title: "To Restore")
        ctx.insert(conv)
        try ctx.save()
        conv.softDelete()
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.conversations.count, 0)
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
        viewModel.restoreConversation(conv)
        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertEqual(viewModel.deletedConversations.count, 0)
        XCTAssertFalse(conv.softDeleted)
    }

    func testPermanentDeleteConversationRemovesFromStore() throws {
        let ctx = container.mainContext
        let conv = Conversation(title: "Permanent Delete")
        ctx.insert(conv)
        try ctx.save()
        conv.softDelete()
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
        viewModel.permanentDeleteConversation(conv)
        XCTAssertEqual(viewModel.deletedConversations.count, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conversation>()), 0)
    }

    func testPurgeExpiredConversationsRemovesOldOnes() throws {
        let ctx = container.mainContext
        let expired = Conversation(title: "Expired")
        ctx.insert(expired)
        try ctx.save()
        expired.softDelete()
        expired.deletedAt = Calendar.current.date(byAdding: .day, value: -31, to: Date())
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
        viewModel.purgeExpiredConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conversation>()), 0)
    }

    func testPurgeExpiredConversationsKeepsRecentOnes() throws {
        let ctx = container.mainContext
        let recent = Conversation(title: "Recent")
        ctx.insert(recent)
        try ctx.save()
        recent.softDelete()
        // deletedAt is now, so not expired
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
        viewModel.purgeExpiredConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 1)
    }

    func testPurgeAllDeletedConversationsRemovesAll() throws {
        let ctx = container.mainContext
        let conv1 = Conversation(title: "Deleted 1")
        let conv2 = Conversation(title: "Deleted 2")
        ctx.insert(conv1)
        ctx.insert(conv2)
        try ctx.save()
        conv1.softDelete()
        conv2.softDelete()
        try ctx.save()
        viewModel.fetchConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 2)
        viewModel.purgeAllDeletedConversations()
        XCTAssertEqual(viewModel.deletedConversations.count, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conversation>()), 0)
    }
}