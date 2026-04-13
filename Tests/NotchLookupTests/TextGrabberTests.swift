import AppKit
import Testing
@testable import NotchLookupCore

// MARK: - normalize() unit tests
//
// These tests exercise the pure trimming logic without touching the pasteboard
// or synthesizing any CGEvents. They run instantly and without side effects.

@Suite("TextGrabber.normalize")
struct NormalizeTests {

    @Test("returns nil for nil input")
    func nilInput() {
        #expect(TextGrabber.normalize(nil) == nil)
    }

    @Test("returns nil for empty string")
    func emptyString() {
        #expect(TextGrabber.normalize("") == nil)
    }

    @Test("returns nil for whitespace-only string")
    func whitespaceOnly() {
        #expect(TextGrabber.normalize("   ") == nil)
        #expect(TextGrabber.normalize("\t\n") == nil)
        #expect(TextGrabber.normalize("\n\n\n") == nil)
    }

    @Test("returns the string unchanged when it has non-whitespace content")
    func validText() {
        #expect(TextGrabber.normalize("hello") == "hello")
    }

    @Test("preserves internal whitespace and leading/trailing content")
    func internalWhitespace() {
        // We only strip for the nil-check; the raw string is returned as-is.
        #expect(TextGrabber.normalize("  hello world  ") == "  hello world  ")
    }

    @Test("handles newlines embedded in real content")
    func embeddedNewlines() {
        #expect(TextGrabber.normalize("line1\nline2") == "line1\nline2")
    }

    @Test("handles unicode content")
    func unicodeContent() {
        #expect(TextGrabber.normalize("こんにちは") == "こんにちは")
        #expect(TextGrabber.normalize("🔑 secret") == "🔑 secret")
    }
}

// MARK: - grabSelectedText() integration tests
//
// These tests run the full async function against the real NSPasteboard.
// In a headless test runner no app responds to Cmd+C, so grabbing always
// yields nil — but we can still verify the two observable guarantees:
//   1. The function returns nil (nothing was copied).
//   2. Whatever was on the clipboard before is restored afterwards.

@Suite("TextGrabber.grabSelectedText")
final class GrabSelectedTextTests {

    // MARK: - Restore

    @Test("restores a pre-existing string to the clipboard after the grab")
    @MainActor
    func restoresClipboardAfterGrab() async {
        let sentinel = "notchlookup-test-sentinel-\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)

        _ = await TextGrabber.grabSelectedText()

        #expect(NSPasteboard.general.string(forType: .string) == sentinel)

        // Clean up.
        NSPasteboard.general.clearContents()
    }

    @Test("leaves clipboard empty when it was empty before the grab")
    @MainActor
    func leavesClipboardEmptyWhenEmpty() async {
        NSPasteboard.general.clearContents()

        _ = await TextGrabber.grabSelectedText()

        #expect(NSPasteboard.general.string(forType: .string) == nil)
    }

    // MARK: - Return value

    @Test("returns nil in a headless environment where no app responds to Cmd+C")
    @MainActor
    func returnsNilWhenNothingResponds() async {
        NSPasteboard.general.clearContents()

        let result = await TextGrabber.grabSelectedText()

        // In a test process, Cmd+C is synthesized but no app responds —
        // the clipboard stays empty and the function returns nil.
        #expect(result == nil)
    }
}
