import Foundation
@testable import open_chat

/// Mock implementation of `AIServiceProtocol` for testing ViewModels.
/// Yields configurable chunks (or throws a configurable error).
final class MockAIService: AIServiceProtocol {
    let providerType: AIProviderType

    /// The chunk sequence to yield when `streamResponse` is called.
    var chunksToYield: [String] = ["Hello", " ", "World", "!"]

    /// If non-nil, the stream finishes by throwing this error.
    var errorToThrow: Error?

    /// All messages passed to `streamResponse` across calls.
    private(set) var receivedMessages: [[ChatMessage]] = []

    /// All configs passed to `streamResponse` across calls.
    private(set) var receivedConfigs: [AIProviderConfig] = []

    /// Number of times `streamResponse` was called.
    private(set) var callCount = 0

    init(providerType: AIProviderType = .openrouter) {
        self.providerType = providerType
    }

    func streamResponse(
        messages: [ChatMessage],
        config: AIProviderConfig
    ) -> AsyncThrowingStream<String, Error> {
        callCount += 1
        receivedMessages.append(messages)
        receivedConfigs.append(config)

        let chunks = chunksToYield
        let error = errorToThrow

        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    await Task.yield()
                    continuation.yield(chunk)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}