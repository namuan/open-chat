import SwiftUI
import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    var selectedProviderType: AIProviderType = .openrouter {
        didSet { save(); loadModelsIfNeeded() }
    }
    var openRouterConfig: AIProviderConfig = .default(for: .openrouter) {
        didSet { save() }
    }
    var requestyConfig: AIProviderConfig = .default(for: .requesty) {
        didSet { save() }
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
    }

    // MARK: - Provider accessors

    var activeProvider: AIProviderType { selectedProviderType }

    func config(for provider: AIProviderType) -> AIProviderConfig {
        switch provider {
        case .openrouter: openRouterConfig
        case .requesty: requestyConfig
        }
    }

    func service(for provider: AIProviderType) -> any AIServiceProtocol {
        OpenAICompatibleProvider(providerType: provider)
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
            if migrated { save() }
        }
        if let raw = defaults.string(forKey: "selected_provider"),
           let provider = AIProviderType(rawValue: raw) {
            selectedProviderType = provider
        }
    }
}
