import SwiftUI

struct ConversationsListView: View {
    @Bindable var conversationsViewModel: ConversationsViewModel
    var chatViewModel: ChatViewModel

    @State private var showingSettings = false

    var body: some View {
        List(selection: Binding<UUID?>(
            get: { chatViewModel.selectedConversation?.id },
            set: { newID in
                if let id = newID {
                    let conversation = conversationsViewModel.conversations.first { $0.id == id }
                    chatViewModel.selectConversation(conversation)
                }
            }
        )) {
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
                        ConversationRow(
                            conversation: conversation,
                            isSelected: chatViewModel.selectedConversation?.id == conversation.id
                        )
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
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)

            Text(conversation.lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(conversation.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
