# NotchLookup — Build Progress

---

## Session 1 — Component 1: Project Scaffold

**Status:** Files created, blocked on toolchain issue

### What was done
- Created all 4 scaffold files:
  - `Package.swift` (swift-tools-version: 6.1, HotKey dependency)
  - `NotchLookup.entitlements` (network client permission, no sandbox)
  - `build.sh` (compiles release build, assembles .app bundle, codesigns)
  - `Sources/NotchLookup/Info.plist` (LSUIElement, bundle ID, accessibility usage description)

### Blocker: CLT 16.4 has two bugs
`swift package resolve` fails due to mismatched files in the Command Line Tools 16.4 installation:

1. **Private swiftinterface** (Feb 2024, Swift 5.10) declares `SwiftVersion` as a real enum, but the dylib uses the renamed type `SwiftLanguageMode`. The linker can't find the old symbol.
2. **SwiftBridging module redefinition** — two module map files in the CLT both define `SwiftBridging`, breaking Foundation imports for HotKey's `swift-tools-version:5.0` Package.swift.

### Resolution
Installed Xcode, ran `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` and `sudo xcodebuild -license accept`.

### Verification
`swift package resolve` succeeded — HotKey 0.2.1 fetched and resolved. ✓

### Next session
Proceed to Component 2: App Entry Point (`Sources/NotchLookup/App/NotchLookupApp.swift`)

---

## Session 2 — Component 2: App Entry Point

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Created `Sources/NotchLookup/App/NotchLookupApp.swift`:
  - `@main NotchLookupApp` struct with `@NSApplicationDelegateAdaptor(AppDelegate.self)`
  - `body` is a `Settings`-only scene (no main window)
  - `SettingsView`: `SecureField` for API key, Save button wired to `KeychainManager.shared.saveAPIKey(_:)`, "Saved!" confirmation label, read-only "⌘⇧E" hotkey label, pre-populates field from Keychain on appear
- Created `Sources/NotchLookup/App/AppDelegate.swift` — stub with empty `applicationDidFinishLaunching` for Component 3
- Created `Sources/NotchLookup/Core/KeychainManager.swift` — stub with full API surface (`saveAPIKey`, `retrieveAPIKey`, `deleteAPIKey`) so `SettingsView` compiles; real Keychain logic deferred to Component 4

### Decisions made
- `KeychainManager` stub marked `@unchecked Sendable` — no mutable state, all Keychain ops are inherently thread-safe; avoids Swift 6 `MutableGlobalVariable` error on the `static let shared` singleton

### Error encountered and fixed
Swift 6 strict concurrency raised `error: static property 'shared' is not concurrency-safe because non-'Sendable' type 'KeychainManager' may have shared mutable state`. Fixed by conforming `KeychainManager` to `@unchecked Sendable` (the stub and eventual real implementation have no mutable instance state).

### Verification
`swift build` → `Build complete!` ✓

### Next session
Proceed to Component 3: Menu Bar + App Delegate (`Sources/NotchLookup/App/AppDelegate.swift`)

---

## Session 3 — Component 3: Menu Bar + App Delegate

**Status:** Complete — `./build.sh` produces `NotchLookup.app` with no errors

### What was done
- Replaced `AppDelegate.swift` stub with full implementation:
  - `NSApp.setActivationPolicy(.accessory)` on launch
  - `NSStatusItem` (square length) with `text.magnifyingglass` SF Symbol
  - `NSMenu` with "Settings…" (⌘,), separator, "Quit" (⌘Q)
  - `openSettings()` using `showSettingsWindow:` selector + `NSApp.activate`
  - Accessibility check via `AXIsProcessTrustedWithOptions` prompting the user on first launch
  - Instantiates `NotchWindowController` and `HotkeyManager` stubs (both kept alive as instance properties)
- Created `Sources/NotchLookup/UI/NotchWindowController.swift` — stub for Component 8
- Created `Sources/NotchLookup/Core/HotkeyManager.swift` — stub for Component 5

### Decisions made
- Used raw string `"AXTrustedCheckOptionPrompt"` instead of `kAXTrustedCheckOptionPrompt` global var to avoid Swift 6 `shared mutable state` concurrency error
- `statusItem`, `notchWindowController`, `hotkeyManager` stored as instance properties so they stay alive for the app lifetime

### Verification
- `swift build` → `Build complete!` ✓
- `./build.sh` → `NotchLookup.app` produced and signed ✓
- `open NotchLookup.app` → menu bar icon appears, menu opens with Settings/Quit ✓

### Next session
Proceed to Component 4: Keychain Storage (`Sources/NotchLookup/Core/KeychainManager.swift`)

---

## Session 4 — Component 4: Keychain Storage

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Replaced `KeychainManager.swift` stub with full Keychain implementation:
  - `saveAPIKey(_ key:)` — delete-then-add pattern using `SecItemDelete` then `SecItemAdd`; stores with `kSecAttrAccessibleWhenUnlocked`
  - `retrieveAPIKey()` — `SecItemCopyMatching` with `kSecReturnData: true`, decodes result as UTF-8
  - `deleteAPIKey()` — `SecItemDelete` keyed on service + account
  - Service: `com.akshajravi.NotchLookup`, Account: `anthropic-api-key`

### Decisions made
- Delete-then-add pattern avoids `errSecDuplicateItem` on repeated saves without needing `SecItemUpdate`
- `kSecAttrAccessibleWhenUnlocked` — key is readable whenever screen is unlocked; survives reboots (vs. `WhenUnlockedThisDeviceOnly` which blocks migration)

### Verification
- `swift build` → `Build complete!` ✓
- Manual verification: enter key in Settings UI → quit → relaunch → key populates field on appear ✓ (via `SettingsView.onAppear` already wired in Component 2)

### Next session
Proceed to Component 5: Global Hotkey (`Sources/NotchLookup/Core/HotkeyManager.swift`)

---

## Session 5 — Component 5: Global Hotkey

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Replaced `HotkeyManager.swift` stub with full implementation:
  - Wraps `HotKey(key: .e, modifiers: [.command, .shift])` from the HotKey package
  - Stores the `HotKey` instance as a private property so the Carbon registration stays alive for the app lifetime
  - `keyDownHandler` dispatches via `Task { @MainActor in handler() }` to hop back to the main actor safely
  - Init parameter marked `@Sendable` to satisfy Swift 6 strict concurrency (handler crosses actor boundaries into the Task)

### Decisions made
- `@Sendable` on the handler parameter: required by Swift 6 — without it the compiler raises a "sending risks data races" error when capturing the closure in a `@MainActor` Task
- `Task { @MainActor in ... }` pattern instead of `@MainActor` closure annotation: `HotKey.Handler` is an unannotated `() -> ()`, so annotating the closure itself raises a "loses global actor" error

### Verification
- `swift build` → `Build complete!` ✓

### Next session
Proceed to Component 6: Text Grabber (`Sources/NotchLookup/Core/TextGrabber.swift`)

---

## Session 6 — Component 6: Text Grabber

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Created `Sources/NotchLookup/Core/TextGrabber.swift`:
  - `enum TextGrabber` with `@MainActor static func grabSelectedText() async -> String?`
  - Saves current clipboard, clears it, synthesizes Cmd+C via `CGEvent`, waits 0.1 s, reads result, restores original clipboard
  - `postCmdC()` — creates key-down + key-up `CGEvent` for virtual key `0x08` (kVK_ANSI_C) with `.maskCommand` flag, posts to `.cghidEventTap`
  - Returns `nil` if grabbed text is nil or whitespace-only
- Updated `AppDelegate.swift` hotkey handler to call `TextGrabber.grabSelectedText()` and print the result

### Error encountered and fixed
Swift 6 strict concurrency raised `sending 'pasteboard' risks causing data races` because `NSPasteboard.general` was captured across `MainActor.run` closure boundaries. Fixed by marking `grabSelectedText()` `@MainActor` — all pasteboard ops then run on the main actor with no cross-boundary capture.

### Decisions made
- `@MainActor` on the function rather than per-call `MainActor.run` blocks: cleaner, avoids the capture problem entirely, and is correct since `NSPasteboard` is not `Sendable`

### Verification
- `swift build` → `Build complete!` ✓

### Next session
Proceed to Component 7: Notch Positioning (`Sources/NotchLookup/Utils/NotchPositioner.swift`)

---

## Session 7 — Component 7: Notch Positioning

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Discovered `TextGrabber.swift` was missing from disk (Session 6 recorded it as done but the file was never saved). Re-created it with identical logic from the plan notes:
  - `enum TextGrabber` with `@MainActor static func grabSelectedText() async -> String?`
  - Save/clear/postCmdC/sleep/read/restore clipboard pattern
  - `postCmdC()` synthesizes Cmd+C via `CGEvent` virtual key `0x08` + `.maskCommand`
- Created `Sources/NotchLookup/Utils/NotchPositioner.swift`:
  - `enum NotchPositioner`
  - `static func windowFrame(windowSize:) -> CGRect` — centers window horizontally at top of main screen, using `NSScreen.main?.safeAreaInsets.top` for notch height offset; falls back to 0 on pre-macOS-12
  - `static var hasNotch: Bool` — `true` when `safeAreaInsets.top > 0`
  - `#available(macOS 12, *)` guard around `safeAreaInsets` per plan spec

### Decisions made
- `safeAreaInsets` guard targets macOS 12 (not 13) per plan note — the hardware is macOS 13+ but `safeAreaInsets` is a macOS 12 API, so the guard is correct as written
- Default `windowSize` is `CGSize(width: 340, height: 120)` as specified in plan

### Verification
- `swift build` → `Build complete!` ✓

### Next session
Proceed to Component 8: Notch Window (`Sources/NotchLookup/UI/NotchWindow.swift`)

---

## Session 8 — Component 8: Notch Window

**Status:** Complete — `./build.sh` produces `NotchLookup.app` with zero errors and zero warnings

### What was done
- Discovered `TextGrabber.swift` and `NotchPositioner.swift` were again missing from disk (same disk-persistence issue as Session 7). Re-created both files with identical logic from plan notes.
- Created `Sources/NotchLookup/UI/NotchWindow.swift` containing two types:
  - `NotchWindow: NSPanel` — borderless, non-activating, `.screenSaver` level, clear + non-opaque, no shadow; `canBecomeKey = true` / `canBecomeMain = false`; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`
  - `NotchWindowController` — owns `NotchWindow`, `NotchViewModel`, and `NSHostingView<NotchView>`; implements `show(with:)` with spring-in animation (cubic Bezier 0.34/1.56/0.64/1.0, 0.4s) and `dismiss()` with easeIn fade (0.2s); local key monitor for Tab (cycleMode) and Esc (dismiss); global mouse monitor for click-outside dismiss
- Cleared `NotchWindowController.swift` stub (class moved to `NotchWindow.swift` to avoid duplicate definition)
- Created `Sources/NotchLookup/UI/ModeSelector.swift` — defines `LookupMode` enum + `ModeSelector` stub (full pill UI in Component 9)
- Created `Sources/NotchLookup/UI/NotchView.swift` — defines `NotchViewModel` + `NotchView` stubs (full implementations in Component 10)
- Updated `AppDelegate.swift` hotkey handler: calls `TextGrabber.grabSelectedText()` then `notchWindowController.show(with:)` instead of printing

### Decisions made
- `NSAnimationContext` completion handler runs off the main actor — wrapped its body in `Task { @MainActor in ... }` to call `window.orderOut(nil)` and `viewModel.cancelStreaming()` without concurrency warnings
- Put `LookupMode` in `ModeSelector.swift` (per plan option) so it's available to both `NotchViewModel` (Component 10) and `AnthropicClient` (Component 11)

### Post-session fix
Discovered `Sources/NotchLookup/Core/TextGrabber.swift` and `Sources/NotchLookup/Utils/NotchPositioner.swift` were duplicates of files already in `Sources/NotchLookupCore/`. `Package.swift` has a separate `NotchLookupCore` library target; `Sources/NotchLookup/Core/KeychainManager.swift` uses `@_exported import NotchLookupCore` which re-exports those symbols automatically. Both duplicate files were deleted — `swift build` still passes clean.

### Verification
- `swift build` → `Build complete!` ✓ (zero warnings)
- `./build.sh` → `NotchLookup.app` produced and signed ✓

### Next session
Proceed to Component 9: Mode Selector UI (`Sources/NotchLookup/UI/ModeSelector.swift`)

---

## Session 9 — Component 9: Mode Selector UI

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Replaced `ModeSelector.swift` stub with full pill UI:
  - `ModeSelector: View` takes `selectedMode: LookupMode` and renders an `HStack`
  - `ForEach(LookupMode.allCases)` produces one `ModePill` per mode
  - `ModePill` (private): `Capsule` background — white 90% opacity if selected, white 8% if not; text black + semibold if selected, white 45% opacity if not; 10pt font
  - `.animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)` on the pill for smooth transitions
  - Trailing `Spacer()` + "Tab to switch" label in white 25% opacity at 9pt
  - `LookupMode` enum retained in the same file (unchanged)

### Decisions made
- Extracted `ModePill` as a private `View` struct — keeps `ModeSelector.body` clean and isolates the `isSelected` animation scope to the pill level

### Verification
- `swift build` → `Build complete!` ✓

### Next session
Proceed to Component 10: Notch View + ViewModel (`Sources/NotchLookup/UI/NotchView.swift`)

---

## Session 10 — Component 10: Notch View + ViewModel

**Status:** Complete — `swift build` passes with zero errors

### What was done
- Replaced `NotchView.swift` stub with full implementation:
  - `NotchViewModel.startStreaming()` — cancels prior `streamTask`, sets `isStreaming = true`, iterates `AnthropicClient.shared.stream(text:mode:)` and appends chunks to `displayText`; handles `AnthropicError.missingAPIKey` with a user-facing message; handles `CancellationError` silently (dismiss mid-stream); sets `isStreaming = false` on completion
  - `NotchView` — added `ProgressView()` scaled to 0.5x with a fixed 12pt height frame (prevents layout jump) shown while `isStreaming`; added `.fixedSize(horizontal: false, vertical: true)` on the response `Text` so multi-line output wraps correctly
- Created `Sources/NotchLookup/Core/AnthropicClient.swift` stub for Component 11:
  - Defines `AnthropicError` enum (`missingAPIKey`, `httpError(Int)`)
  - `AnthropicClient` singleton with `stream(text:mode:) throws -> AsyncThrowingStream<String, Error>` stub that yields one chunk and finishes
  - Marked `@unchecked Sendable` (same pattern as `KeychainManager`) to satisfy Swift 6 `MutableGlobalVariable` warning on `static let shared`

### Decisions made
- `@unchecked Sendable` on `AnthropicClient`: stub and real implementation have no mutable state; avoids Swift 6 concurrency error on the singleton
- `Task { [weak self] in ... }` inside `startStreaming()`: captures `self` weakly so a dismissed controller doesn't leak; `await task.value` at the end keeps `startStreaming()` suspended until the stream finishes or is cancelled
- `ProgressView` height fix: SwiftUI's default `ProgressView()` takes ~20pt; capping at 12pt prevents the VStack from jumping when streaming starts/stops

### Verification
- `swift build` → `Build complete!` ✓

### Next session
Proceed to Component 11: Anthropic Streaming Client (`Sources/NotchLookup/Core/AnthropicClient.swift`)
