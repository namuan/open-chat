import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var conversationsViewModel: ConversationsViewModel?

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            // MARK: - Active Provider
            Section {
                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    ProviderRow(
                        provider: provider,
                        hasKey: viewModel.hasAPIKey(for: provider),
                        isActive: viewModel.selectedProviderType == provider,
                        onSelect: { viewModel.setActiveProvider(provider) }
                    )
                }
            } header: {
                Text("Active Provider")
            } footer: {
                if !viewModel.isActiveProviderReady {
                    if let ready = viewModel.firstProviderWithKey {
                        Text("Add an API key for \(viewModel.selectedProviderType.displayName), or tap \(ready.displayName) above to switch.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Add an API key below to start chatting.")
                            .foregroundStyle(.orange)
                    }
                }
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

            // MARK: - Recently Deleted
            if let conversationsViewModel {
                RecentlyDeletedSection(conversationsViewModel: conversationsViewModel)
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
            // Use a regular TextField (not SecureField) so pasting works
            // reliably. Show a masked preview when the field isn't focused
            // so the key isn't fully exposed on-screen.
            APIKeyField(config: config)
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

        // System Prompt
        Section {
            TextEditor(text: config.systemPrompt)
                .font(.callout)
                .frame(minHeight: 120)
            Text("Use {{DATE}} as a placeholder for today's date. It will be replaced automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("System Prompt")
        } footer: {
            if config.wrappedValue.systemPrompt.isEmpty {
                Text("No system prompt set. The assistant will respond without special instructions.")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: AIProviderType
    let hasKey: Bool
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: hasKey ? "key.fill" : "key")
                            .font(.caption2)
                        Text(hasKey ? "API key set" : "No API key")
                            .font(.caption)
                    }
                    .foregroundStyle(hasKey ? .green : .orange)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Field

/// A plain `TextField` for editing an API key, with a masked preview
/// (`sk-or-v…abcd`) shown when the field isn't focused. Avoids the
/// iOS 18 `SecureField` paste bug by using a regular TextField.
///
/// The TextField is always in the view hierarchy (never conditionally
/// swapped out), so focus transfers cleanly when the user taps anywhere
/// on the row.
struct APIKeyField: View {
    @Binding var config: AIProviderConfig
    @FocusState private var isFocused: Bool

    /// Masked preview, e.g. `sk-or-v…abcd`.
    private var maskedText: String {
        let key = config.apiKey
        guard !key.isEmpty else { return "Not set" }
        if key.count <= 12 { return key }
        let head = key.prefix(7)
        let tail = key.suffix(4)
        return "\(head)…\(tail)"
    }

    var body: some View {
        HStack {
            Text("API Key")
            Spacer()

            TextField(
                "Paste or type your API key",
                text: Binding(
                    get: { config.apiKey },
                    set: { config.apiKey = $0 }
                )
            )
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 200)
            .font(.system(.body, design: .monospaced))
            .opacity(isFocused ? 1 : 0)
            .overlay(alignment: .trailing) {
                if !isFocused {
                    Text(maskedText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(config.apiKey.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsHitTesting(false)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SettingsViewModel())
    }
}

// MARK: - Recently Deleted Section

struct RecentlyDeletedSection: View {
    @Bindable var conversationsViewModel: ConversationsViewModel
    @State private var showingPurgeAllConfirmation = false
    @State private var conversationToDeletePermanently: Conversation?

    var body: some View {
        Section("Recently Deleted") {
            if conversationsViewModel.deletedConversations.isEmpty {
                Text("No deleted conversations")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(conversationsViewModel.deletedConversations) { conversation in
                    DeletedConversationRow(
                        conversation: conversation,
                        onRestore: {
                            conversationsViewModel.restoreConversation(conversation)
                        },
                        onDeleteForever: {
                            conversationToDeletePermanently = conversation
                        }
                    )
                }

                Button(role: .destructive) {
                    showingPurgeAllConfirmation = true
                } label: {
                    Label("Purge All Deleted", systemImage: "trash")
                }
            }
        }
        .alert("Delete Forever?", isPresented: $showingPurgeAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                conversationsViewModel.purgeAllDeletedConversations()
            }
        } message: {
            Text("This will permanently delete all conversations in the trash. This action cannot be undone.")
        }
        .alert("Delete Forever?", isPresented: Binding(
            get: { conversationToDeletePermanently != nil },
            set: { if !$0 { conversationToDeletePermanently = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                conversationToDeletePermanently = nil
            }
            Button("Delete", role: .destructive) {
                if let conv = conversationToDeletePermanently {
                    conversationsViewModel.permanentDeleteConversation(conv)
                    conversationToDeletePermanently = nil
                }
            }
        } message: {
            Text("This will permanently delete this conversation. This action cannot be undone.")
        }
    }
}

// MARK: - Deleted Conversation Row

struct DeletedConversationRow: View {
    let conversation: Conversation
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button {
                        onRestore()
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                    }

                    Button(role: .destructive) {
                        onDeleteForever()
                    } label: {
                        Label("Delete Forever", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(deletionInfoText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var deletionInfoText: String {
        guard let deletedAt = conversation.deletedAt else {
            return "Recently deleted"
        }
        let daysSince = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        let daysRemaining = max(30 - daysSince, 0)

        if daysRemaining <= 0 {
            return "Expires soon"
        } else if daysRemaining == 1 {
            return "Expires tomorrow"
        } else {
            return "Expires in \(daysRemaining) days"
        }
    }
}
