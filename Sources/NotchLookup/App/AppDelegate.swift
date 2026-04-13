import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Kept alive for the app lifetime — releasing these tears down the menu bar item / hotkey.
    private var statusItem: NSStatusItem?
    private var notchWindowController: NotchWindowController?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders alongside LSUIElement = true in Info.plist.
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        requestAccessibilityIfNeeded()

        notchWindowController = NotchWindowController()
        hotkeyManager = HotkeyManager { [weak self] in
            Task { @MainActor in
                guard let text = await TextGrabber.grabSelectedText() else {
                    print("NotchLookup: nothing was selected")
                    return
                }
                self?.notchWindowController?.show(with: text)
            }
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "text.magnifyingglass",
                accessibilityDescription: "NotchLookup"
            )
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit NotchLookup",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        // Triggers the SwiftUI Settings scene.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        // Passing kAXTrustedCheckOptionPrompt: true shows the system prompt
        // the first time the app launches without Accessibility permission.
        // kAXTrustedCheckOptionPrompt is a global C var; use its raw string value to
        // avoid Swift 6 shared-mutable-state concurrency errors.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("NotchLookup: Accessibility permission not yet granted — user prompted.")
        }
    }
}
