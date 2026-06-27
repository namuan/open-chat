import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.displayMessages) { message in
                            MessageBubbleView(message: message)
                        }

                        // Streaming message
                        if viewModel.isLoading, !viewModel.streamingContent.isEmpty {
                            MessageBubbleView(
                                role: .assistant,
                                content: viewModel.streamingContent,
                                isStreaming: true
                            )
                            .id("streaming")
                        }

                        // Loading indicator (before first token)
                        if viewModel.isLoading, viewModel.streamingContent.isEmpty {
                            HStack {
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .id("loading")
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                viewModel.errorMessage = nil
                            }
                            .id("error")
                        }

                        // Bottom spacer for scroll
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onAppear {
                    scrollProxy = proxy
                }
            }

            // Input bar
            ChatInputBar(
                text: $viewModel.inputText,
                isFocused: $isInputFocused,
                isLoading: viewModel.isLoading,
                onSend: {
                    Task { await viewModel.sendMessage() }
                },
                onStop: {
                    viewModel.stopStreaming()
                }
            )
        }
        .navigationTitle(viewModel.selectedConversation?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.newConversation() }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear { isInputFocused = true }
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var isLoading: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused(isFocused)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }

                if isLoading {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary : Color.blue
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel(settingsViewModel: SettingsViewModel()))
    }
}
