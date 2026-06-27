import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            // MARK: - Provider Selection
            Section("AI Provider") {
                Picker("Provider", selection: $vm.selectedProviderType) {
                    ForEach(AIProviderType.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Provider Configuration
            switch viewModel.selectedProviderType {
            case .openrouter:
                providerConfigSection(
                    title: "OpenRouter",
                    config: $vm.openRouterConfig,
                    models: vm.openRouterModels,
                    freeOnly: true
                )
            case .requesty:
                providerConfigSection(
                    title: "Requesty",
                    config: $vm.requestyConfig,
                    models: vm.requestyModels,
                    freeOnly: true
                )
            }

            // MARK: - About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            viewModel.loadModelsIfNeeded()
        }
    }

    // MARK: - Provider Config Section

    @ViewBuilder
    private func providerConfigSection(
        title: String,
        config: Binding<AIProviderConfig>,
        models: [ModelFetchService.ModelInfo],
        freeOnly: Bool
    ) -> some View {
        Section(title) {
            // API Key
            HStack {
                Text("API Key")
                Spacer()
                SecureField("sk-...", text: config.apiKey)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
            }
        }

        // Model picker
        Section("Model") {
            if viewModel.isLoadingModels {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading models…")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.modelLoadError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await viewModel.loadModels() }
                    }
                    .font(.caption)
                }
            } else if models.isEmpty {
                Text("No models loaded")
                    .foregroundStyle(.secondary)
            } else {
                let displayModels = freeOnly
                    ? models.filter(\.free)
                    : models

                Picker("Model", selection: config.model) {
                    // Always show current value if not in loaded list
                    let currentId = config.wrappedValue.model
                    if !displayModels.contains(where: { $0.id == currentId }) {
                        Text(currentId)
                            .tag(currentId)
                    }
                    ForEach(displayModels) { model in
                        Text(model.displayName)
                            .tag(model.id)
                    }
                }
            }

            Button {
                Task { await viewModel.loadModels() }
            } label: {
                Label("Refresh models", systemImage: "arrow.clockwise")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SettingsViewModel())
    }
}
