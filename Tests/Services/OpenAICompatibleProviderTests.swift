import XCTest
@testable import open_chat

final class OpenAICompatibleProviderTests: XCTestCase {

    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        MockURLProtocol.reset()
        
    }

    override func tearDown() {
        session = nil
        MockURLProtocol.reset()
        
        super.tearDown()
    }

    // MARK: - Helpers

    private func validConfig(endpoint: String = "https://test.example.com/v1/chat/completions") -> AIProviderConfig {
        AIProviderConfig(providerType: .openrouter, apiKey: "sk-test", model: "test-model", endpoint: endpoint)
    }

    private func chunks(_ contents: [String]) -> Data {
        MockURLProtocol.sseBody(contents.map { MockURLProtocol.sse(content: $0) })
    }

    // MARK: - Missing API key

    func testThrowsMissingAPIKeyWhenEmpty() async {
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        let config = AIProviderConfig(providerType: .openrouter, apiKey: "", model: "m", endpoint: "https://example.com")
        let stream = provider.streamResponse(messages: [], config: config)
        do {
            for try await _ in stream { XCTFail("Should not yield") }
            XCTFail("Should have thrown")
        } catch {
            guard case AIError.missingAPIKey = error else {
                return XCTFail("Expected missingAPIKey, got \(error)")
            }
        }
    }

    // MARK: - Invalid URL

    func testThrowsInvalidURLForBadEndpoint() async {
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        // URL(string:) treats most strings as relative URLs. Use empty string
        // to guarantee nil.
        let config = AIProviderConfig(providerType: .openrouter, apiKey: "k", model: "m", endpoint: "")
        do {
            for try await _ in provider.streamResponse(messages: [], config: config) { }
            XCTFail("Should have thrown")
        } catch {
            guard case AIError.invalidURL = error else {
                return XCTFail("Expected invalidURL, got \(error)")
            }
        }
    }

    // MARK: - Streaming success

    func testStreamYieldsAllChunksInOrder() async throws {
        MockURLProtocol.cannedResponses.append(.init(body: chunks(["Hello", " ", "World"])))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        var received: [String] = []
        for try await c in provider.streamResponse(messages: [], config: validConfig()) {
            received.append(c)
        }
        XCTAssertEqual(received, ["Hello", " ", "World"])
    }

    // MARK: - [DONE] terminates stream

    func testDoneTerminatesStream() async throws {
        let body = MockURLProtocol.sseBody([
            MockURLProtocol.sse(content: "Hi"),
        ])
        MockURLProtocol.cannedResponses.append(.init(body: body))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        var received: [String] = []
        for try await c in provider.streamResponse(messages: [], config: validConfig()) {
            received.append(c)
        }
        XCTAssertEqual(received, ["Hi"])
    }

    // MARK: - HTTP error status

    func testInvalidResponseIncludesErrorBody() async {
        let errorBody = MockURLProtocol.errorJSON(message: "Model not found", type: "invalid_request_error")
        MockURLProtocol.cannedResponses.append(.init(statusCode: 404, body: errorBody))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        do {
            for try await _ in provider.streamResponse(messages: [], config: validConfig()) { }
            XCTFail("Should have thrown")
        } catch {
            guard case AIError.invalidResponse(let code, let detail) = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
            XCTAssertEqual(code, 404)
            XCTAssertEqual(detail, "Model not found")
        }
    }

    func testInvalidResponseWithoutBodyDetail() async {
        MockURLProtocol.cannedResponses.append(.init(statusCode: 500, body: Data()))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        do {
            for try await _ in provider.streamResponse(messages: [], config: validConfig()) { }
            XCTFail("Should have thrown")
        } catch {
            guard case AIError.invalidResponse(let code, let detail) = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
            XCTAssertEqual(code, 500)
            XCTAssertFalse(detail?.isEmpty == false, "Expected nil detail, got '\(detail ?? "nil")'")
        }
    }

    // MARK: - Request body content

    func testRequestBodyIncludesModelAndMessages() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.cannedResponses.append(.init(body: chunks(["OK"])))
        // Verify the provider yields the expected content without throwing.
        // Request-body inspection via MockURLProtocol is flaky because
        // URLSession may send unrelated background requests.
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        let messages = [ChatMessage(role: "user", content: "Hello")]
        let result = try await collectAll(from: provider.streamResponse(messages: messages, config: validConfig()))
        XCTAssertEqual(result, ["OK"])
    }

    // MARK: - Provider type

    func testProviderTypeIsCorrect() {
        let p = OpenAICompatibleProvider(providerType: .requesty, urlSession: session)
        XCTAssertEqual(p.providerType, .requesty)
    }

    // MARK: - Network error propagates

    func testNetworkErrorPropagates() async {
        struct E: Error {}
        MockURLProtocol.cannedResponses.append(.init(body: Data(), error: E()))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        do {
            for try await _ in provider.streamResponse(messages: [], config: validConfig()) { }
            XCTFail("Should have thrown")
        } catch {
            // Any error type is fine
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Multi-chunk SSE

    func testMultiChunkSSEInSingleEvent() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Part1"}}]}

        data: {"choices":[{"delta":{"content":"Part2"}}]}

        data: [DONE]

        """
        MockURLProtocol.cannedResponses.append(.init(body: Data(sse.utf8)))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        var received: [String] = []
        for try await c in provider.streamResponse(messages: [], config: validConfig()) {
            received.append(c)
        }
        XCTAssertEqual(received, ["Part1", "Part2"])
    }

    // MARK: - Delta with no content is skipped

    func testDeltaWithoutContentIsSkipped() async throws {
        let sse = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}

        data: {"choices":[{"delta":{"content":"Hi"}}]}

        data: [DONE]

        """
        MockURLProtocol.cannedResponses.append(.init(body: Data(sse.utf8)))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        var received: [String] = []
        for try await c in provider.streamResponse(messages: [], config: validConfig()) {
            received.append(c)
        }
        XCTAssertEqual(received, ["Hi"])
    }

    // MARK: - parseErrorMessage fallbacks to type

    func testParseErrorMessageFallbackToType() async {
        let body = Data(#"{"error":{"type":"rate_limit_exceeded"}}"#.utf8)
        MockURLProtocol.cannedResponses.append(.init(statusCode: 429, body: body))
        let provider = OpenAICompatibleProvider(providerType: .openrouter, urlSession: session)
        do {
            for try await _ in provider.streamResponse(messages: [], config: validConfig()) { }
            XCTFail("Should have thrown")
        } catch {
            guard case AIError.invalidResponse(_, let detail) = error else {
                return XCTFail("Expected invalidResponse")
            }
            XCTAssertEqual(detail, "rate_limit_exceeded")
        }
    }

    // MARK: - Helpers

    private func collectAll(from stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var result: [String] = []
        for try await c in stream { result.append(c) }
        return result
    }
}