import Foundation

enum AIProviderType: String, CaseIterable, Codable {
    case openrouter = "OpenRouter"
    case requesty = "Requesty"

    var displayName: String { rawValue }

    var defaultModel: String {
        switch self {
        case .openrouter: "meta-llama/llama-3.3-70b-instruct:free"
        case .requesty: "google/gemma-4-31b-it"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openrouter: "https://openrouter.ai/api/v1/chat/completions"
        case .requesty: "https://router.requesty.ai/v1/chat/completions"
        }
    }

    var requiresAPIKey: Bool {
        true
    }
}

struct AIProviderConfig: Equatable, Codable {
    var providerType: AIProviderType
    var apiKey: String
    var model: String
    var endpoint: String
    var systemPrompt: String

    static let defaultSystemPrompt = """
    You are a helpful, harmless, and honest AI assistant. \
    Today's date is {{DATE}}. \
    Be concise and clear in your responses. \
    If you're unsure about something, say so rather than guessing.
    """

    static func `default`(for type: AIProviderType) -> AIProviderConfig {
        AIProviderConfig(
            providerType: type,
            apiKey: "",
            model: type.defaultModel,
            endpoint: type.defaultEndpoint,
            systemPrompt: defaultSystemPrompt
        )
    }

    /// Returns the system prompt with {{DATE}} replaced by today's date.
    var resolvedSystemPrompt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let today = formatter.string(from: Date())
        return systemPrompt.replacingOccurrences(of: "{{DATE}}", with: today)
    }

    // Custom decoder for backward compatibility (old configs lack systemPrompt)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerType = try container.decode(AIProviderType.self, forKey: .providerType)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        model = try container.decode(String.self, forKey: .model)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        systemPrompt = (try? container.decode(String.self, forKey: .systemPrompt)) ?? Self.defaultSystemPrompt
    }

    init(providerType: AIProviderType, apiKey: String, model: String, endpoint: String, systemPrompt: String = defaultSystemPrompt) {
        self.providerType = providerType
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.systemPrompt = systemPrompt
    }
}
