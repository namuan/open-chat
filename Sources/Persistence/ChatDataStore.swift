import Foundation
import SwiftData

final class ChatDataStore {
    nonisolated(unsafe) static let shared = ChatDataStore()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            Conversation.self,
            Message.self,
        ])

        // Pre-create the Application Support directory so SwiftData can
        // open the store on the first try. Without this, the store
        // creation fails with "no such file or directory" and triggers
        // a loud CoreData recovery log on every fresh install.
        Self.ensureApplicationSupportDirectoryExists()

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    private static func ensureApplicationSupportDirectoryExists() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return
        }
        // The .applicationSupportDirectory call may not create the per-app
        // subdirectory, so make sure it exists too.
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
    }

    @MainActor
    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    /// Creates a preview container for SwiftUI previews (in-memory only).
    @MainActor
    static var preview: ModelContainer = {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Seed with sample data
            let conversation = Conversation(title: "Sample Chat")
            container.mainContext.insert(conversation)
            container.mainContext.insert(Message(role: .user, content: "Hello!", conversation: conversation))
            container.mainContext.insert(Message(role: .assistant, content: "Hi there! How can I help?", conversation: conversation))
            return container
        } catch {
            fatalError("Preview container error: \(error)")
        }
    }()
}
