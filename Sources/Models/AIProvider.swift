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

    static func `default`(for type: AIProviderType) -> AIProviderConfig {
        AIProviderConfig(
            providerType: type,
            apiKey: "",
            model: type.defaultModel,
            endpoint: type.defaultEndpoint
        )
    }
}
