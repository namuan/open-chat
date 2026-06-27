import XCTest
@testable import open_chat

@MainActor
final class SettingsViewModelTests: XCTestCase {

    var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
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
        let openRouterModel = viewModel.config(for: .openrouter).model
        XCTAssertTrue(openRouterModel.contains("free") || openRouterModel.contains("gemma"),
                      "Default OpenRouter model should be free")
    }

    func testDefaultEndpoint() {
        XCTAssertTrue(viewModel.config(for: .openrouter).endpoint.contains("openrouter.ai"))
        XCTAssertTrue(viewModel.config(for: .requesty).endpoint.contains("router.requesty.ai"))
    }

    // MARK: - hasAPIKey

    func testHasAPIKeyReturnsFalseWhenEmpty() {
        XCTAssertFalse(viewModel.hasAPIKey(for: .openrouter))
        XCTAssertFalse(viewModel.hasAPIKey(for: .requesty))
    }

    func testHasAPIKeyReturnsTrueWhenSet() {
        viewModel.openRouterConfig.apiKey = "sk-test"
        XCTAssertTrue(viewModel.hasAPIKey(for: .openrouter))
        XCTAssertFalse(viewModel.hasAPIKey(for: .requesty))
    }

    func testIsActiveProviderReady() {
        XCTAssertFalse(viewModel.isActiveProviderReady)
        viewModel.openRouterConfig.apiKey = "sk-test"
        XCTAssertTrue(viewModel.isActiveProviderReady)
    }

    // MARK: - Auto-switch

    func testAutoSwitchOnKeyEntry() {
        viewModel.setActiveProvider(.requesty)
        XCTAssertEqual(viewModel.activeProvider, .requesty)
        viewModel.openRouterConfig.apiKey = "sk-test"
        XCTAssertEqual(viewModel.activeProvider, .openrouter)
    }

    func testNoAutoSwitchWhenActiveHasKey() {
        viewModel.openRouterConfig.apiKey = "sk-test-1"
        viewModel.setActiveProvider(.openrouter)
        viewModel.requestyConfig.apiKey = "sk-test-2"
        XCTAssertEqual(viewModel.activeProvider, .openrouter)
    }

    func testAutoSwitchOnInitIfActiveMissingKey() {
        viewModel.setActiveProvider(.requesty)
        viewModel.openRouterConfig.apiKey = "sk-test"
        let reloaded = SettingsViewModel()
        XCTAssertEqual(reloaded.activeProvider, .openrouter)
    }

    // MARK: - Persistence

    func testConfigSurvivesRelaunch() {
        viewModel.openRouterConfig.apiKey = "sk-abc"
        viewModel.openRouterConfig.model = "test-model"
        viewModel.setActiveProvider(.openrouter)
        let reloaded = SettingsViewModel()
        XCTAssertEqual(reloaded.activeProvider, .openrouter)
        XCTAssertTrue(reloaded.hasAPIKey(for: .openrouter))
        XCTAssertEqual(reloaded.config(for: .openrouter).model, "test-model")
    }

    // MARK: - Endpoint migration

    func testMigratesOldRequestyEndpoint() {
        viewModel.requestyConfig.endpoint = "https://api.requesty.ai/v1/chat/completions"
        let data = try! JSONEncoder().encode([
            "openrouter": viewModel.openRouterConfig,
            "requesty": viewModel.requestyConfig,
        ])
        UserDefaults.standard.set(data, forKey: "ai_provider_configs")
        let reloaded = SettingsViewModel()
        XCTAssertEqual(reloaded.config(for: .requesty).endpoint,
                       "https://router.requesty.ai/v1/chat/completions")
    }

    func testMigratesOldOpenAIModel() {
        viewModel.openRouterConfig.model = "openai/gpt-4o"
        let data = try! JSONEncoder().encode([
            "openrouter": viewModel.openRouterConfig,
            "requesty": viewModel.requestyConfig,
        ])
        UserDefaults.standard.set(data, forKey: "ai_provider_configs")
        let reloaded = SettingsViewModel()
        XCTAssertNotEqual(reloaded.config(for: .openrouter).model, "openai/gpt-4o")
    }

    // MARK: - firstProviderWithKey

    func testFirstProviderWithKeyReturnsNilWhenNoKeys() {
        XCTAssertNil(viewModel.firstProviderWithKey)
    }

    func testFirstProviderWithKeyReturnsRightProvider() {
        viewModel.requestyConfig.apiKey = "sk-test"
        XCTAssertEqual(viewModel.firstProviderWithKey, .requesty)
    }

    // MARK: - Models

    func testFreeModelsForCurrentProviderReturnsEmptyByDefault() {
        XCTAssertTrue(viewModel.freeModelsForCurrentProvider.isEmpty)
    }

    func testModelsForCurrentProviderReturnsRightList() {
        let openRouterModels = [ModelFetchService.ModelInfo(id: "a", name: "A", free: true)]
        let requestyModels = [ModelFetchService.ModelInfo(id: "b", name: "B", free: false)]
        viewModel.openRouterModels = openRouterModels
        viewModel.requestyModels = requestyModels
        XCTAssertEqual(viewModel.modelsForCurrentProvider.count, 1)
        XCTAssertEqual(viewModel.modelsForCurrentProvider.first?.id, "a")
        viewModel.setActiveProvider(.requesty)
        XCTAssertEqual(viewModel.modelsForCurrentProvider.first?.id, "b")
    }
}