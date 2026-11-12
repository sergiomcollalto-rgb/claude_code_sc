import SwiftUI

@main
struct RelatoApp: App {
    @StateObject private var store = MeetingStore()

    var body: some Scene {
        WindowGroup("Relato") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(store.isRecording ? "Parar e gerar ata" : "Nova reunião") {
                    store.toggleRecording()
                }
                .keyboardShortcut("n")
            }
        }
    }
}
