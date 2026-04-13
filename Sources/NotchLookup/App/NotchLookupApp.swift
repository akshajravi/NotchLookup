import SwiftUI

@main
struct NotchLookupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — app lives entirely in the menu bar and notch overlay.
        // Settings scene is the only windowed UI.
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                SecureField("Anthropic API Key", text: $apiKey)
                    .textContentType(.password)

                Button("Save") {
                    // KeychainManager will be wired up in Component 4.
                    // For now this compiles cleanly as a no-op.
                    _ = KeychainManager.shared.saveAPIKey(apiKey)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                }
                .disabled(apiKey.isEmpty)

                if saved {
                    Text("Saved!")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section {
                LabeledContent("Hotkey", value: "⌘⇧E")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 360)
        .onAppear {
            // Pre-populate field if a key is already stored.
            apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        }
    }
}
