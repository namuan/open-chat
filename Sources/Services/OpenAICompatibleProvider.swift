import Foundation

/// Generic OpenAI-compatible streaming provider. Used by OpenRouter, Requesty, and
/// any other service that exposes an OpenAI-compatible chat completions endpoint.
struct OpenAICompatibleProvider: AIServiceProtocol {
    let providerType: AIProviderType

    func streamResponse(
        messages: [ChatMessage],
        config: AIProviderConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamRequest(messages: messages, config: config, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func performStreamRequest(
        messages: [ChatMessage],
        config: AIProviderConfig,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: config.endpoint) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(NSError(domain: "", code: -1))
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await byte in bytes {
                errorBody += String(UnicodeScalar(byte))
            }
            throw AIError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        // Parse SSE stream (OpenAI-compatible format)
        var buffer = ""
        for try await byte in bytes {
            let char = Character(UnicodeScalar(byte))
            buffer.append(char)

            if buffer.hasSuffix("\n\n") {
                let lines = buffer.split(separator: "\n")
                buffer = ""

                for line in lines {
                    let lineStr = String(line).trimmingCharacters(in: .whitespaces)
                    guard lineStr.hasPrefix("data: ") else { continue }
                    let dataStr = String(lineStr.dropFirst(6))

                    if dataStr == "[DONE]" { return }

                    if let data = dataStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        continuation.yield(content)
                    }
                }
            }
        }
    }
}
