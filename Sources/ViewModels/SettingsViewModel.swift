import SwiftUI
import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    var selectedProviderType: AIProviderType = .openrouter {
        didSet {
            guard oldValue != selectedProviderType else { return }
            save()
            loadModelsIfNeeded()
        }
    }
    var openRouterConfig: AIProviderConfig = .default(for: .openrouter) {
        didSet {
            // If the user just added an API key to a non-active provider,
            // and the active provider has no key, switch to this one.
            maybeAutoSwitchToProvider(with: .openrouter)
            save()
        }
    }
    var requestyConfig: AIProviderConfig = .default(for: .requesty) {
        didSet {
            maybeAutoSwitchToProvider(with: .requesty)
            save()
        }
    }

    // Model fetching
    var openRouterModels: [ModelFetchService.ModelInfo] = []
    var requestyModels: [ModelFetchService.ModelInfo] = []
    var isLoadingModels = false
    var modelLoadError: String?

    private let defaults = UserDefaults.standard
    private let storageKey = "ai_provider_configs"

    init() {
        load()
        // After load, if the active provider has no key but another does, switch.
        if !hasAPIKey(for: selectedProviderType) {
            if hasAPIKey(for: .openrouter) {
                selectedProviderType = .openrouter
            } else if hasAPIKey(for: .requesty) {
                selectedProviderType = .requesty
            }
        }
    }

    // MARK: - Provider accessors

    var activeProvider: AIProviderType { selectedProviderType }

    /// True if the given provider has a non-empty API key configured.
    func hasAPIKey(for provider: AIProviderType) -> Bool {
        !config(for: provider).apiKey.isEmpty
    }

    /// True if the currently-active provider is ready to use (has a key).
    var isActiveProviderReady: Bool {
        hasAPIKey(for: selectedProviderType)
    }

    /// The first provider (in the enum's order) that has an API key, if any.
    var firstProviderWithKey: AIProviderType? {
        AIProviderType.allCases.first(where: { hasAPIKey(for: $0) })
    }

    func config(for provider: AIProviderType) -> AIProviderConfig {
        switch provider {
        case .openrouter: openRouterConfig
        case .requesty: requestyConfig
        }
    }

    func setActiveProvider(_ provider: AIProviderType) {
        selectedProviderType = provider
    }

    func service(for provider: AIProviderType) -> any AIServiceProtocol {
        OpenAICompatibleProvider(providerType: provider)
    }

    // MARK: - Auto-switch

    private func maybeAutoSwitchToProvider(with provider: AIProviderType) {
        // Don't auto-switch if user already has this provider active
        guard selectedProviderType != provider else { return }
        // Only auto-switch if the current active provider has NO key,
        // and the one the user just edited now HAS a key.
        guard !hasAPIKey(for: selectedProviderType), hasAPIKey(for: provider) else { return }
        selectedProviderType = provider
    }

    // MARK: - Models

    var modelsForCurrentProvider: [ModelFetchService.ModelInfo] {
        switch selectedProviderType {
        case .openrouter: openRouterModels
        case .requesty: requestyModels
        }
    }

    var freeModelsForCurrentProvider: [ModelFetchService.ModelInfo] {
        modelsForCurrentProvider.filter(\.free)
    }

    func loadModelsIfNeeded() {
        let models = modelsForCurrentProvider
        guard models.isEmpty else { return }
        Task { await loadModels() }
    }

    func loadModels() async {
        isLoadingModels = true
        modelLoadError = nil
        do {
            let cfg = config(for: selectedProviderType)
            let models = try await ModelFetchService.fetch(
                provider: selectedProviderType,
                apiKey: cfg.apiKey.isEmpty ? nil : cfg.apiKey
            )
            switch selectedProviderType {
            case .openrouter: openRouterModels = models
            case .requesty: requestyModels = models
            }
        } catch {
            modelLoadError = error.localizedDescription
        }
        isLoadingModels = false
    }

    // MARK: - Persistence

    private func save() {
        let configs: [String: AIProviderConfig] = [
            "openrouter": openRouterConfig,
            "requesty": requestyConfig,
        ]
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: storageKey)
        }
        defaults.set(selectedProviderType.rawValue, forKey: "selected_provider")
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let configs = try? JSONDecoder().decode([String: AIProviderConfig].self, from: data) {
            openRouterConfig = configs["openrouter"] ?? .default(for: .openrouter)
            requestyConfig = configs["requesty"] ?? .default(for: .requesty)

            // Migrate away from old default model (openai/gpt-4o)
            let oldDefault = "openai/gpt-4o"
            var migrated = false
            if openRouterConfig.model == oldDefault {
                openRouterConfig.model = AIProviderType.openrouter.defaultModel
                migrated = true
            }
            if requestyConfig.model == oldDefault {
                requestyConfig.model = AIProviderType.requesty.defaultModel
                migrated = true
            }

            // Migrate Requesty endpoint: api.requesty.ai → router.requesty.ai
            // (Requesty moved their inference router; the old host now 404s)
            let oldRequestyEndpoint = "https://api.requesty.ai/v1/chat/completions"
            if requestyConfig.endpoint == oldRequestyEndpoint
                || requestyConfig.endpoint.contains("api.requesty.ai") {
                requestyConfig.endpoint = AIProviderType.requesty.defaultEndpoint
                migrated = true
            }

            // Migrate OpenRouter endpoint similarly in case of stale data
            let oldOpenRouterEndpoint = "https://api.openrouter.ai/api/v1/chat/completions"
            if openRouterConfig.endpoint == oldOpenRouterEndpoint
                || openRouterConfig.endpoint.contains("api.openrouter.ai/api/v1/chat") {
                openRouterConfig.endpoint = AIProviderType.openrouter.defaultEndpoint
                migrated = true
            }

            if migrated { save() }
        }
        if let raw = defaults.string(forKey: "selected_provider"),
           let provider = AIProviderType(rawValue: raw) {
            selectedProviderType = provider
        }
    }
}
