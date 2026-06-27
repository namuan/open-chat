import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsViewModel.self) private var settingsViewModel

    @State private var chatViewModel: ChatViewModel
    @State private var conversationsViewModel = ConversationsViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    init() {
        // SettingsViewModel is injected via environment, so we create a placeholder
        _chatViewModel = State(initialValue: ChatViewModel(settingsViewModel: SettingsViewModel()))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationsListView(
                conversationsViewModel: conversationsViewModel,
                chatViewModel: chatViewModel
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if let _ = chatViewModel.selectedConversation {
                ChatView(viewModel: chatViewModel)
            } else {
                EmptyChatView {
                    chatViewModel.newConversation()
                }
            }
        }
        .onAppear {
            // Re-initialize chatViewModel with the actual settingsViewModel
            chatViewModel = ChatViewModel(settingsViewModel: settingsViewModel)
            chatViewModel.configure(with: modelContext)
            conversationsViewModel.configure(with: modelContext)
        }
        .onChange(of: chatViewModel.selectedConversation) { _, _ in
            conversationsViewModel.fetchConversations()
        }
        // Settings sheet is triggered from ConversationsListView toolbar
    }
}

struct EmptyChatView: View {
    var onNewChat: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Open Chat")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select a conversation or start a new one")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onNewChat) {
                Label("New Chat", systemImage: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
        .modelContainer(ChatDataStore.preview)
        .environment(SettingsViewModel())
}
