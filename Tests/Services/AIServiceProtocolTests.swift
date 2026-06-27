import XCTest
@testable import open_chat

final class AIServiceProtocolTests: XCTestCase {

    // MARK: - AIError descriptions

    func testMissingAPIKeyError() {
        let error = AIError.missingAPIKey
        XCTAssertTrue(error.errorDescription?.contains("API key") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Settings") ?? false)
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

    func testInvalidURLError() {
        let error = AIError.invalidURL
        XCTAssertTrue(error.errorDescription?.contains("URL") ?? false)
    }

    func testNetworkError() {
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
}
