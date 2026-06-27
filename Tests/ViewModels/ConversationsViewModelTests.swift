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
}