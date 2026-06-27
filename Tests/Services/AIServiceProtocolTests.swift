import XCTest
@testable import open_chat

final class AIServiceProtocolTests: XCTestCase {

    // MARK: - AIError.errorDescription

    func testMissingAPIKeyDescription() {
        XCTAssertTrue(AIError.missingAPIKey.errorDescription?.contains("API key") ?? false)
        XCTAssertTrue(AIError.missingAPIKey.errorDescription?.contains("Settings") ?? false)
    }

    func testInvalidURLDescription() {
        XCTAssertEqual(AIError.invalidURL.errorDescription, "Invalid API endpoint URL")
    }

    func testInvalidResponseWithDetail() {
        let error = AIError.invalidResponse(statusCode: 404, detail: "Model not found")
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("404"))
        XCTAssertTrue(desc.contains("Model not found"))
    }

    func testInvalidResponseWithoutDetail() {
        let error = AIError.invalidResponse(statusCode: 500)
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("500"))
        XCTAssertFalse(desc.contains(":"))
    }

    func testAPIErrorDescription() {
        let error = AIError.apiError("boom")
        XCTAssertEqual(error.errorDescription, "API error: boom")
    }

    func testDecodingErrorDescription() {
        let error = AIError.decodingError("bad json")
        XCTAssertEqual(error.errorDescription, "Failed to parse response: bad json")
    }

    func testStreamErrorDescription() {
        let error = AIError.streamError("EOF")
        XCTAssertEqual(error.errorDescription, "Stream error: EOF")
    }

    // MARK: - AIError.networkError

    func testNetworkErrorDescription() {
        let underlying = NSError(domain: "test", code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The internet connection appears to be offline."
        ])
        let error = AIError.networkError(underlying)
        XCTAssertTrue(error.errorDescription?.contains("offline") ?? false)
    }

    // MARK: - ChatMessage

    func testChatMessageInitialization() {
        let msg = ChatMessage(role: "user", content: "Hello")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "Hello")
    }

    // MARK: - AIProviderType

    func testProviderTypeDisplayNames() {
        XCTAssertEqual(AIProviderType.openrouter.displayName, "OpenRouter")
        XCTAssertEqual(AIProviderType.requesty.displayName, "Requesty")
    }

    func testProviderTypeDefaults() {
        XCTAssertFalse(AIProviderType.openrouter.defaultModel.isEmpty)
        XCTAssertFalse(AIProviderType.requesty.defaultModel.isEmpty)
        XCTAssertFalse(AIProviderType.openrouter.defaultEndpoint.isEmpty)
        XCTAssertTrue(AIProviderType.requesty.defaultEndpoint.contains("router.requesty.ai"))
    }

    func testProviderTypeAllCases() {
        XCTAssertEqual(AIProviderType.allCases.count, 2)
        XCTAssertTrue(AIProviderType.allCases.contains(.openrouter))
        XCTAssertTrue(AIProviderType.allCases.contains(.requesty))
    }
}

// MARK: - AIProviderConfig

final class AIProviderConfigTests: XCTestCase {

    func testDefaultForOpenRouter() {
        let config = AIProviderConfig.default(for: .openrouter)
        XCTAssertEqual(config.providerType, .openrouter)
        XCTAssertEqual(config.apiKey, "")
        XCTAssertEqual(config.model, AIProviderType.openrouter.defaultModel)
        XCTAssertEqual(config.endpoint, AIProviderType.openrouter.defaultEndpoint)
    }

    func testDefaultForRequesty() {
        let config = AIProviderConfig.default(for: .requesty)
        XCTAssertEqual(config.providerType, .requesty)
        XCTAssertEqual(config.endpoint, AIProviderType.requesty.defaultEndpoint)
    }

    func testEquality() {
        let a = AIProviderConfig(providerType: .openrouter, apiKey: "k", model: "m", endpoint: "e")
        let b = AIProviderConfig(providerType: .openrouter, apiKey: "k", model: "m", endpoint: "e")
        let c = AIProviderConfig(providerType: .openrouter, apiKey: "k2", model: "m", endpoint: "e")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCodableRoundTrip() throws {
        let original = AIProviderConfig(providerType: .openrouter, apiKey: "k", model: "m", endpoint: "e")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}