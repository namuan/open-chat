import SwiftUI

struct ConversationsListView: View {
    @Bindable var conversationsViewModel: ConversationsViewModel
    var chatViewModel: ChatViewModel

    @State private var showingSettings = false
    @State private var selectedConversationID: UUID?

    var body: some View {
        List(selection: $selectedConversationID) {
            Section {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $conversationsViewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                // New chat button
                Button(action: { chatViewModel.newConversation() }) {
                    Label("New Chat", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Section("Conversations") {
                if conversationsViewModel.filteredConversations.isEmpty {
                    Text("No conversations yet")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(conversationsViewModel.filteredConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation.id)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                conversationsViewModel.deleteConversation(conversation)
                                chatViewModel.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onChange(of: selectedConversationID) { _, newID in
            guard let id = newID else {
                chatViewModel.selectConversation(nil)
                return
            }
            // If the conversation isn't in the sidebar list yet (e.g. a
            // brand-new chat that hasn't been persisted), don't clear the
            // selection — the ViewModel already holds the right reference.
            guard let conversation = conversationsViewModel.conversations.first(where: { $0.id == id }) else {
                return
            }
            chatViewModel.selectConversation(conversation)
        }
        .onChange(of: chatViewModel.selectedConversation) { _, _ in
            // Sync the List selection highlight with the ViewModel.
            // (e.g. when newConversation() creates and selects a chat)
            selectedConversationID = chatViewModel.selectedConversation?.id
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)

            Text(conversation.lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationSplitView {
        ConversationsListView(
            conversationsViewModel: ConversationsViewModel(),
            chatViewModel: ChatViewModel(settingsViewModel: SettingsViewModel())
        )
    } detail: {
        EmptyChatView {}
    }
    .modelContainer(ChatDataStore.preview)
}
