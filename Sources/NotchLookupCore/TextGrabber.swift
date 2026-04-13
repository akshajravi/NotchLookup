import AppKit

/// Grabs the currently selected text in the frontmost application by synthesizing
/// a Cmd+C event and reading the clipboard result.
public enum TextGrabber {

    // All pasteboard access must happen on the main thread; marking @MainActor
    // satisfies Swift 6 strict concurrency without splitting across MainActor.run calls.
    @MainActor
    public static func grabSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general

        // Step 1 — Save current clipboard contents so we can restore them.
        let previousContents = pasteboard.string(forType: .string)

        // Step 2 — Clear the clipboard so we can detect a fresh paste.
        pasteboard.clearContents()

        // Step 3 — Synthesize Cmd+C to copy the selected text.
        postCmdC()

        // Step 4 — Wait 0.1 s for the target app to respond to the copy event.
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 5 — Read the grabbed text.
        let grabbed = pasteboard.string(forType: .string)

        // Step 6 — Restore the original clipboard contents.
        pasteboard.clearContents()
        if let previous = previousContents {
            pasteboard.setString(previous, forType: .string)
        }

        // Step 7 — Return nil if nothing was grabbed or the result is empty.
        return normalize(grabbed)
    }

    // MARK: - Internal helpers (package-visible for testing)

    /// Trims whitespace and returns nil for empty/whitespace-only strings.
    /// Extracted so tests can verify this logic in isolation without CGEvent machinery.
    static func normalize(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    // MARK: - Private

    /// Synthesizes a Cmd+C key-down + key-up pair via CGEvent.
    /// Virtual key 0x08 = 'c' on the US keyboard layout (kVK_ANSI_C).
    private static func postCmdC() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        // Attach the Command modifier so the events become Cmd+C.
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand

        // Post to the HID event tap — reaches the frontmost app.
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
