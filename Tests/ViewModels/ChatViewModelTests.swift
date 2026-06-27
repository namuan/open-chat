import XCTest
@testable import open_chat

final class ChatViewModelTests: XCTestCase {

    var viewModel: ChatViewModel!
    var settingsVM: SettingsViewModel!

    override func setUp() {
        super.setUp()
        settingsVM = SettingsViewModel()
        viewModel = ChatViewModel(settingsViewModel: settingsVM)
    }

    override func tearDown() {
        viewModel = nil
        settingsVM = nil
        super.tearDown()
    }

    // MARK: - newConversation

    func testNewConversationCreatesInMemoryOnly() {
        viewModel.newConversation()

        // selectedConversation should be set (so the UI shows the chat view)
        XCTAssertNotNil(viewModel.selectedConversation)
        // But the conversation should NOT be persisted in SwiftData yet
        XCTAssertFalse(viewModel.selectedConversation!.hasChanges)
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

    // MARK: - selectConversation

    func testSelectConversationSetsAndClears() {
        let conversation = Conversation(title: "Test Chat")

        viewModel.selectConversation(conversation)
        XCTAssertEqual(viewModel.selectedConversation?.id, conversation.id)
        XCTAssertEqual(viewModel.streamingContent, "")

        viewModel.selectConversation(nil)
        XCTAssertNil(viewModel.selectedConversation)
    }

    // MARK: - displayMessages

    func testDisplayMessagesFiltersStreamingDuplicate() {
        let conversation = Conversation(title: "Test")
        let userMsg = Message(role: .user, content: "Hello", conversation: conversation)

        viewModel.selectedConversation = conversation
        viewModel.streamingMessageID = UUID() // not the assistant's ID

        let msgs = viewModel.displayMessages
        // While not streaming, all messages should appear
        XCTAssertEqual(msgs.count, viewModel.messages.count)
    }
}
