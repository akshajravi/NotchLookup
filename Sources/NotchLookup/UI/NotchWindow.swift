import AppKit
import SwiftUI

// MARK: - NotchWindow

/// Borderless, non-activating panel that floats above all apps at the notch position.
/// Using NSPanel (not NSWindow) gives us .nonactivatingPanel — the app the user copied
/// from keeps keyboard focus, while Tab/Esc still reach us because canBecomeKey = true.
final class NotchWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Sit just above the menu bar (where the hardware notch lives) instead of
        // the extreme .screenSaver level — matches boring.notch's window-level choice.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Force dark appearance so the black pill renders consistently regardless of
        // system light/dark mode — matches boring.notch.
        appearance = NSAppearance(named: .darkAqua)
        // Visible on every Space and in fullscreen; excluded from Cmd+` window cycling.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    // Receiving Tab and Esc requires key-window status — grant it without taking main.
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: - NotchWindowController

/// Owns the NotchWindow and drives its show/dismiss lifecycle.
/// Stored as a long-lived property on AppDelegate so it is never deallocated.
@MainActor
final class NotchWindowController {
    private let window: NotchWindow
    private let viewModel: NotchViewModel
    private var hostingView: NSHostingView<NotchView>?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    init() {
        window = NotchWindow()
        viewModel = NotchViewModel()
        setupContentView()
        setupKeyMonitor()
    }

    // MARK: - Setup

    private func setupContentView() {
        let rootView = NotchView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: rootView)
        // NSHostingView adds a default opaque layer background — clear it so the
        // rounded-rectangle shape in NotchView shows through correctly.
        hosting.layer?.backgroundColor = CGColor.clear
        window.contentView = hosting
        hostingView = hosting
    }

    private func setupKeyMonitor() {
        // Local monitor intercepts key events when this window is key.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 48: // Tab — cycle mode (only before streaming starts)
                self.viewModel.cycleMode()
                return nil   // consume; don't pass to other responders
            case 53: // Esc — dismiss overlay
                self.dismiss()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Show

    /// Show the window instantly in collapsed state (indistinguishable from the
    /// hardware notch), then trigger the SwiftUI spring expansion so the notch
    /// visually grows outward. No window-level fade — the collapsed pill IS the
    /// notch, so there's nothing to hide.
    func show(with text: String) {
        viewModel.reset(inputText: text)

        // Position at the final frame — expansion happens inside SwiftUI, not at the window level.
        let targetFrame = NotchPositioner.windowFrame()
        window.setFrame(targetFrame, display: false)
        // Instant appear: the collapsed pill visually merges with the hardware notch,
        // so a fade-in would be an unnecessary flicker.
        window.alphaValue = 1.0
        window.orderFront(nil)

        // Brief pause so the eye registers the collapsed state before the expansion
        // kicks in — otherwise the spring fires simultaneously with orderFront and
        // the "grows out of the notch" effect is lost.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.viewModel.reveal()
        }

        // Global mouse monitor dismisses the window on any click outside it.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.dismiss()
        }

        Task { await viewModel.startStreaming() }
    }

    // MARK: - Dismiss

    /// Contract the pill back into the hardware notch via SwiftUI spring, then
    /// hide the window. Mirrors the show animation in reverse.
    func dismiss() {
        // Remove the click-outside monitor first to prevent re-entrant dismiss calls.
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }

        // Cancel streaming immediately so text stops appending during the contract.
        viewModel.cancelStreaming()

        // Triggering isRevealed = false runs the same spring in reverse — the pill
        // shrinks back to its collapsed (notch-sized) state.
        viewModel.isRevealed = false

        // Wait for the spring to settle before pulling the window, otherwise
        // orderOut would cut the animation off mid-contract.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.window.orderOut(nil)
        }
    }
}
