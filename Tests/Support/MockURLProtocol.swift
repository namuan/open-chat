import Foundation

/// A URL protocol subclass that intercepts requests for testing.
/// Configure `MockURLProtocol.cannedResponses` / `statusCode` / `error`
/// before the call you want to mock.
final class MockURLProtocol: URLProtocol {

    /// Queue of canned responses to serve (FIFO). Each request pops one.
    nonisolated(unsafe) static var cannedResponses: [CannedResponse] = []

    /// All requests received by this protocol, in order.
    nonisolated(unsafe) static var receivedRequests: [URLRequest] = []

    /// Reset all state between tests.
    static func reset() {
        cannedResponses.removeAll()
        receivedRequests.removeAll()
    }

    struct CannedResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        let error: Error?

        init(statusCode: Int = 200,
             headers: [String: String] = ["Content-Type": "text/event-stream"],
             body: Data,
             error: Error? = nil) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.error = error
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.receivedRequests.append(request)
        let canned = Self.cannedResponses.isEmpty
            ? CannedResponse(body: Data())
            : Self.cannedResponses.removeFirst()

        if let error = canned.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: canned.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: canned.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        // Deliver body in one chunk for simplicity
        client?.urlProtocol(self, didLoad: canned.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Helper to assemble a valid SSE body from a list of JSON chunk strings.
    static func sseBody(_ events: [String]) -> Data {
        let combined = events.map { "data: \($0)\n\n" }.joined() + "data: [DONE]\n\n"
        return Data(combined.utf8)
    }

    /// Helper to build a single OpenAI-style chunk JSON.
    static func sse(content: String) -> String {
        """
        {"choices":[{"delta":{"content":"\(content)"}}]}
        """
    }

    /// Helper that returns a JSON error response body.
    static func errorJSON(message: String, type: String? = nil) -> Data {
        var errorObj: [String: String] = ["message": message]
        if let type {
            errorObj["type"] = type
        }
        let dict: [String: Any] = ["error": errorObj]
        return try! JSONSerialization.data(withJSONObject: dict)
    }
}