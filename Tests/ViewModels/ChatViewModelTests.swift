import XCTest
import SwiftData
@testable import open_chat

@MainActor
final class ChatViewModelTests: XCTestCase {

    // MARK: - Helpers

    var viewModel: ChatViewModel!
    var settingsVM: SettingsViewModel!
    var mockService: MockAIService!
    var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory SwiftData container for isolated tests
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])

        settingsVM = SettingsViewModel()
        // Configure with a valid API key so send passes the guard
        settingsVM.openRouterConfig.apiKey = "sk-test-key"
        settingsVM.openRouterConfig.model = "test-model"
        settingsVM.openRouterConfig.endpoint = "https://example.com/v1/chat/completions"
        settingsVM.setActiveProvider(.openrouter)

        mockService = MockAIService()
        // Inject the mock by overriding the service factory
        settingsVM.serviceFactory = { _ in self.mockService }

        viewModel = ChatViewModel(settingsViewModel: settingsVM)
        viewModel.configure(with: container.mainContext)
    }

    override func tearDown() async throws {
        viewModel = nil
        settingsVM = nil
        mockService = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - newConversation

    func testNewConversationCreatesInMemoryOnly() {
        viewModel.newConversation()
        XCTAssertNotNil(viewModel.selectedConversation)
        let ctx = container.mainContext
        let convs = try? ctx.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(convs?.count, 0, "New conversation should not be persisted yet")
    }

    func testNewConversationClearsPreviousState() {
        viewModel.inputText = "draft text"
        viewModel.errorMessage = "some error"
        viewModel.streamingContent = "partial..."
        viewModel.newConversation()
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.streamingContent, "")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testNewConversationCancelsStreaming() async throws {
        mockService.chunksToYield = ["Hello", "World"]
        viewModel.inputText = "Hi"
        await viewModel.sendMessage()
        viewModel.newConversation()
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.streamingContent, "")
    }

    func testNewConversationCleansUpEmptyPersistedConversation() throws {
        let ctx = container.mainContext
        let conv = Conversation(title: "Empty")
        ctx.insert(conv)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conversation>()), 1)

        viewModel.selectConversation(conv)
        // Now newConversation() should clean it up
        viewModel.newConversation()

        let count = try ctx.fetchCount(FetchDescriptor<Conversation>())
        XCTAssertEqual(count, 0, "Empty persisted conversation should be deleted")
    }

    // MARK: - selectConversation

    func testSelectConversationSetsAndClears() {
        let conv = Conversation(title: "Test")
        viewModel.selectConversation(conv)
        XCTAssertEqual(viewModel.selectedConversation?.id, conv.id)
        XCTAssertEqual(viewModel.streamingContent, "")

        viewModel.selectConversation(nil)
        XCTAssertNil(viewModel.selectedConversation)
    }

    func testSelectConversationClearsStreamingProgress() {
        viewModel.streamingContent = "partial..."
        viewModel.selectConversation(nil)
        XCTAssertEqual(viewModel.streamingContent, "")
    }

    // MARK: - Navigation round-trip preserves messages

    func testMessagesSurviveNavigateAwayAndComeBack() throws {
        // Simulate being in a chat with existing messages
        let ctx = container.mainContext
        let conv = Conversation(title: "Test")
        ctx.insert(conv)
        let msg1 = Message(role: .user, content: "Hello", conversation: conv)
        ctx.insert(msg1)
        try ctx.save()
        viewModel.selectConversation(conv)

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")

        // Navigate away (Back button)
        viewModel.selectConversation(nil)
        XCTAssertNil(viewModel.selectedConversation)

        // Navigate back — re-select from a fresh fetch (simulating the
        // ConversationsListView lookup on a freshly-fetched list)
        let fetchedConversation = try XCTUnwrap(
            ctx.fetch(FetchDescriptor<Conversation>()).first
        )
        viewModel.selectConversation(fetchedConversation)

        // The messages should still be there
        XCTAssertEqual(
            viewModel.messages.count, 1,
            "Messages lost after navigate-away-then-come-back"
        )
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
    }

    // MARK: - Streaming survives navigation away

    func testStreamingContentNotClearedOnNavigateAway() throws {
        // GIVEN a conversation mid-stream
        let conv = Conversation(title: "Test")
        viewModel.selectConversation(conv)
        viewModel.isLoading = true
        viewModel.streamingContent = "Hello"
        let streamingID = UUID()
        viewModel.streamingMessageID = streamingID

        // WHEN user presses Back
        viewModel.selectConversation(nil)

        // THEN streaming content must survive
        XCTAssertEqual(viewModel.streamingContent, "Hello",
            "streamingContent cleared on Back — next chunk overwrites saved message")
        XCTAssertNotNil(viewModel.streamingMessageID,
            "streamingMessageID cleared — duplicate-fix broken")
    }

    func testStreamingContentNotClearedWhenComingBack() throws {
        // GIVEN a conversation mid-stream
        let conv = Conversation(title: "Test")
        viewModel.selectConversation(conv)
        viewModel.isLoading = true
        viewModel.streamingContent = "Hello"
        viewModel.streamingMessageID = UUID()

        // WHEN user navigates back in (re-selects the same conversation)
        // while the stream is still running
        viewModel.selectConversation(conv)

        // THEN streaming content must survive
        XCTAssertEqual(viewModel.streamingContent, "Hello",
            "streamingContent cleared on re-entry — next chunk overwrites saved message")
    }
}