import Foundation

/// Fetches available models from provider APIs.
/// OpenRouter returns pricing data so we can filter for free models;
/// Requesty returns all routed models.
enum ModelFetchService {

    struct ModelInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let free: Bool

        var displayName: String { free ? "\(name) · free" : name }
    }

    /// Fetch models for the given provider. Pass the API key if the endpoint requires auth.
    static func fetch(
        provider: AIProviderType,
        apiKey: String?
    ) async throws -> [ModelInfo] {
        switch provider {
        case .openrouter:
            return try await fetchOpenRouterModels()
        case .requesty:
            return try await fetchRequestyModels()
        }
    }

    // MARK: - OpenRouter

    private static func fetchOpenRouterModels() async throws -> [ModelInfo] {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = json?["data"] as? [[String: Any]] ?? []

        return models.compactMap { model in
            guard let id = model["id"] as? String else { return nil }
            let name = model["name"] as? String ?? id
            let pricing = model["pricing"] as? [String: String]
            let promptCost = pricing?["prompt"] ?? "1"
            let completionCost = pricing?["completion"] ?? "1"
            let free = promptCost == "0" && completionCost == "0"
            return ModelInfo(id: id, name: name, free: free)
        }
    }

    // MARK: - Requesty (no auth required for models endpoint)

    private static func fetchRequestyModels() async throws -> [ModelInfo] {
        let url = URL(string: "https://router.requesty.ai/v1/models")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // Models endpoint does not require auth

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = json?["data"] as? [[String: Any]] ?? []

        return models.compactMap { model in
            guard let id = model["id"] as? String else { return nil }
            let name = model["id"] as? String ?? id
            // Requesty pricing is numeric, 0 = free
            let inputPrice  = (model["input_price"] as? NSNumber)?.doubleValue ?? -1
            let outputPrice = (model["output_price"] as? NSNumber)?.doubleValue ?? -1
            let free = inputPrice == 0.0 && outputPrice == 0.0
            return ModelInfo(id: id, name: name, free: free)
        }
    }
}
