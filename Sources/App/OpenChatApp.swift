import SwiftUI
import SwiftData

@main
struct OpenChatApp: App {
    @State private var settingsViewModel = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsViewModel)
        }
        .modelContainer(ChatDataStore.shared.modelContainer)
    }
}
