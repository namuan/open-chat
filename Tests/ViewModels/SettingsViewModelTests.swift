import XCTest
@testable import open_chat

final class SettingsViewModelTests: XCTestCase {

    var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        // Wipe any stored config before each test
        UserDefaults.standard.removeObject(forKey: "ai_provider_configs")
        UserDefaults.standard.removeObject(forKey: "selected_provider")
        viewModel = SettingsViewModel()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "ai_provider_configs")
        UserDefaults.standard.removeObject(forKey: "selected_provider")
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultProviderIsOpenRouter() {
        XCTAssertEqual(viewModel.activeProvider, .openrouter)
    }

    func testDefaultModelIsFreeModel() {
        let config = viewModel.config(for: .openrouter)
        XCTAssertTrue(config.model.contains("free") || config.model.contains("gemma"))
    }

    // MARK: - hasAPIKey

    func testHasAPIKeyReturnsFalseWhenEmpty() {
        XCTAssertFalse(viewModel.hasAPIKey(for: .openrouter))
        XCTAssertFalse(viewModel.hasAPIKey(for: .requesty))
    }

    func testHasAPIKeyReturnsTrueWhenSet() {
        viewModel.openRouterConfig.apiKey = "sk-test-key"
        XCTAssertTrue(viewModel.hasAPIKey(for: .openrouter))
        XCTAssertFalse(viewModel.hasAPIKey(for: .requesty))
    }

    // MARK: - Auto-switch

    func testAutoSwitchOnKeyEntry() {
        // Start with Requesty selected, no keys set
        viewModel.setActiveProvider(.requesty)
        XCTAssertEqual(viewModel.activeProvider, .requesty)

        // Add a key to OpenRouter — should auto-switch
        viewModel.openRouterConfig.apiKey = "sk-test"
        XCTAssertEqual(viewModel.activeProvider, .openrouter)
    }

    func testNoAutoSwitchWhenActiveHasKey() {
        // Set a key for OpenRouter and select it
        viewModel.openRouterConfig.apiKey = "sk-test"
        viewModel.setActiveProvider(.openrouter)

        // Add a key to Requesty — should NOT auto-switch away from OpenRouter
        viewModel.requestyConfig.apiKey = "sk-test-2"
        XCTAssertEqual(viewModel.activeProvider, .openrouter)
    }

    // MARK: - Persistence

    func testConfigSurvivesRelaunch() {
        viewModel.openRouterConfig.apiKey = "sk-abc"
        viewModel.openRouterConfig.model = "test-model"
        viewModel.setActiveProvider(.openrouter)

        // Simulate app relaunch by creating a new instance
        let newVM = SettingsViewModel()

        XCTAssertEqual(newVM.activeProvider, .openrouter)
        XCTAssertTrue(newVM.hasAPIKey(for: .openrouter))
        XCTAssertEqual(newVM.config(for: .openrouter).model, "test-model")
    }

    // MARK: - Endpoint migration

    func testMigratesOldRequestyEndpoint() {
        viewModel.requestyConfig.endpoint = "https://api.requesty.ai/v1/chat/completions"
        // The migration runs in init(), so save + reload to trigger it
        // (migration is checked in load() which runs in init())
        let key = "ai_provider_configs"
        let data = try! JSONEncoder().encode([
            "openrouter": viewModel.openRouterConfig,
            "requesty": viewModel.requestyConfig,
        ])
        UserDefaults.standard.set(data, forKey: key)

        let reloaded = SettingsViewModel()
        XCTAssertEqual(
            reloaded.config(for: .requesty).endpoint,
            "https://router.requesty.ai/v1/chat/completions"
        )
    }
}
