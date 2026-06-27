import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
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
                .task {
                    // Let the VStack lay out its content, then scroll to
                    // bottom so the user sees the latest messages immediately.
                    try? await Task.sleep(for: .milliseconds(100))
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: viewModel.streamingContent) { _, _ in
                    // Keep scrolling down as new tokens arrive
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            // Queued messages bar
            if viewModel.hasQueuedMessages {
                QueuedMessagesBar(
                    items: viewModel.queuedMessagePreviews,
                    onCancel: { viewModel.cancelQueuedMessage($0) }
                )
            }

            // Input bar — ChatInputBar owns its own @FocusState and
            // observes the ViewModel's focusRequestCount to know when
            // to focus. This avoids the broken FocusState binding
            // across NavigationSplitView view recreation.
            ChatInputBar(
                text: $viewModel.inputText,
                focusRequestCount: viewModel.focusRequestCount,
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
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    var focusRequestCount: Int
    var isLoading: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
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
                }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .onChange(of: focusRequestCount) { _, _ in
            isInputFocused = true
        }
        .onAppear {
            isInputFocused = true
        }
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

// MARK: - Queued Messages Bar

/// A compact bar showing queued messages waiting to be sent after
/// the current stream finishes.  Each item can be cancelled individually.
struct QueuedMessagesBar: View {
    let items: [(id: UUID, text: String)]
    let onCancel: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ForEach(items, id: \.id) { item in
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(item.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        onCancel(item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                Divider()
            }
        }
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel(settingsViewModel: SettingsViewModel()))
    }
}
