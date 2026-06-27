import Foundation

enum AIError: LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case apiError(String)
    case decodingError(String)
    case networkError(Error)
    case missingAPIKey
    case streamError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API endpoint URL"
        case .invalidResponse(let code):
            "Server returned status code \(code)"
        case .apiError(let message):
            "API error: \(message)"
        case .decodingError(let detail):
            "Failed to parse response: \(detail)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .missingAPIKey:
            "API key is required. Add it in Settings."
        case .streamError(let detail):
            "Stream error: \(detail)"
        }
    }
}

struct ChatMessage {
    let role: String
    let content: String
}

protocol AIServiceProtocol {
    var providerType: AIProviderType { get }

    /// Sends messages and returns a stream of response chunks.
    func streamResponse(
        messages: [ChatMessage],
        config: AIProviderConfig
    ) -> AsyncThrowingStream<String, Error>
}
