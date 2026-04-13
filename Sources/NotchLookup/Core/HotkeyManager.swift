import HotKey

/// Registers and holds the global Cmd+Shift+E hotkey.
/// The `HotKey` instance must stay alive for the Carbon registration to remain active —
/// this class is stored as a long-lived property on `AppDelegate`.
final class HotkeyManager {
    private let hotKey: HotKey

    init(handler: @escaping @Sendable () -> Void) {
        hotKey = HotKey(key: .e, modifiers: [.command, .shift])
        // Hop back to MainActor so the handler can safely touch AppKit/SwiftUI state.
        // HotKey.Handler is an unqualified () -> () so we can't mark the closure itself
        // @MainActor — dispatch via Task instead.
        hotKey.keyDownHandler = { Task { @MainActor in handler() } }
    }
}
