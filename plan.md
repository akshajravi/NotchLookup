# NotchLookup – Build Plan

**App:** macOS menu bar app. Global hotkey (Cmd+Shift+E) grabs selected text, streams an AI response into a borderless SwiftUI window in the MacBook notch. Three modes (Explain/Define/Math) toggled with Tab.

**Approach:** Swift Package Manager executable target + manual `.app` bundle assembly via `build.sh`. No Xcode GUI needed.

---

## Component Assembly Order

Build and verify each component before moving to the next.

---

## Component 1 — Project Scaffold

**Files to create:**
- `Package.swift`
- `NotchLookup.entitlements`
- `build.sh`
- `Sources/NotchLookup/Info.plist`

**`Package.swift`**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchLookup",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "NotchLookup",
            dependencies: [.product(name: "HotKey", package: "HotKey")],
            path: "Sources/NotchLookup"
        ),
    ]
)
```

**`Sources/NotchLookup/Info.plist`** — key entries:
- `LSUIElement = true` — hide Dock icon (menu bar agent only)
- `CFBundleIdentifier = com.akshajravi.NotchLookup`
- `CFBundleExecutable = NotchLookup`
- `NSPrincipalClass = NSApplication`
- `LSMinimumSystemVersion = 13.0`
- `NSAccessibilityUsageDescription` — "NotchLookup needs accessibility access to read selected text."

**`NotchLookup.entitlements`** — key entries:
- `com.apple.security.network.client = true`
- No sandbox (non-App-Store; Keychain + CGEvent work without it)

**`build.sh`**
```bash
#!/bin/bash
set -e
BUNDLE="NotchLookup.app"
swift build -c release
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp .build/release/NotchLookup "$BUNDLE/Contents/MacOS/"
cp Sources/NotchLookup/Info.plist "$BUNDLE/Contents/"
codesign --force --sign - --entitlements NotchLookup.entitlements "$BUNDLE"
echo "Done. Run: open $BUNDLE"
```

**Verify:** `swift package resolve` succeeds and fetches HotKey.

---

## Component 2 — App Entry Point

**Files to create:**
- `Sources/NotchLookup/App/NotchLookupApp.swift`

**What it does:**
- `@main` App struct with `@NSApplicationDelegateAdaptor(AppDelegate.self)`
- `body` contains only `Settings { SettingsView() }` — no main window
- `SettingsView` (defined in same file): a `Form` with a `SecureField` for the API key, a Save button that calls `KeychainManager.shared.saveAPIKey(_:)`, and a read-only "Cmd+Shift+E" shortcut label

**Verify:** `swift build` compiles (AppDelegate can be a stub at this point).

---

## Component 3 — Menu Bar + App Delegate

**Files to create:**
- `Sources/NotchLookup/App/AppDelegate.swift`

**What it does:**
- `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate`
- `applicationDidFinishLaunching`: 
  - `NSApp.setActivationPolicy(.accessory)` — belt-and-suspenders alongside `LSUIElement`
  - Creates `NSStatusItem` (square length) with SF Symbol `text.magnifyingglass`
  - Attaches `NSMenu` with: "Settings..." (`openSettings`), separator, "Quit"
  - Checks `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` — prompts user for Accessibility if not granted
  - Instantiates `NotchWindowController` and `HotkeyManager` (stubs for now)
- `openSettings()`: `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` + `NSApp.activate(ignoringOtherApps: true)`

**Verify:** `./build.sh && open NotchLookup.app` — menu bar icon appears, menu opens.

---

## Component 4 — Keychain Storage

**Files to create:**
- `Sources/NotchLookup/Core/KeychainManager.swift`

**What it does:**
- `final class KeychainManager` with `static let shared`
- Uses `kSecClassGenericPassword`, service `com.akshajravi.NotchLookup`, account `anthropic-api-key`
- `saveAPIKey(_ key: String) -> Bool` — delete-then-add pattern, `kSecAttrAccessibleWhenUnlocked`
- `retrieveAPIKey() -> String?` — `SecItemCopyMatching` returning data decoded as UTF-8
- `deleteAPIKey()` — `SecItemDelete`

**Verify:** Enter key in Settings UI → quit → relaunch → key persists (check via Settings field populating on appear).

---

## Component 5 — Global Hotkey

**Files to create:**
- `Sources/NotchLookup/Core/HotkeyManager.swift`

**What it does:**
```swift
import HotKey

final class HotkeyManager {
    private let hotKey: HotKey

    init(handler: @escaping () -> Void) {
        hotKey = HotKey(key: .e, modifiers: [.command, .shift])
        hotKey.keyDownHandler = handler
    }
}
```
- Stores `HotKey` instance — keeping it alive keeps the Carbon registration alive
- Handler assigned as `{ @MainActor in handler() }` for Swift 6 isolation

**Wire up in AppDelegate:** Replace stub with real `HotkeyManager { print("hotkey fired") }`

**Verify:** Press Cmd+Shift+E system-wide → "hotkey fired" prints to console.

---

## Component 6 — Text Grabber

**Files to create:**
- `Sources/NotchLookup/Core/TextGrabber.swift`

**What it does:**
- `enum TextGrabber` with `static func grabSelectedText() async -> String?`

Steps inside the function (all clipboard ops via `await MainActor.run`):
1. Save current clipboard: `pasteboard.string(forType: .string)`
2. `pasteboard.clearContents()`
3. Call `postCmdC()` — synthesizes Cmd+C via CGEvent
4. `try? await Task.sleep(nanoseconds: 100_000_000)` — 0.1s for target app to respond
5. Read grabbed text: `pasteboard.string(forType: .string)`
6. Restore original clipboard
7. Return grabbed text (nil if empty)

`postCmdC()`:
```swift
let source = CGEventSource(stateID: .hidSystemState)
let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
keyDown?.flags = .maskCommand
keyUp?.flags   = .maskCommand
keyDown?.post(tap: .cghidEventTap)
keyUp?.post(tap: .cghidEventTap)
```

**Wire up in AppDelegate:** `HotkeyManager { Task { let t = await TextGrabber.grabSelectedText(); print(t ?? "nil") } }`

**Verify:** Select text anywhere → Cmd+Shift+E → grabbed text prints to console.

---

## Component 7 — Notch Positioning

**Files to create:**
- `Sources/NotchLookup/Utils/NotchPositioner.swift`

**What it does:**
- `enum NotchPositioner`
- `static func windowFrame(windowSize: CGSize = CGSize(width: 340, height: 120)) -> CGRect`
  - `notchHeight = NSScreen.main?.safeAreaInsets.top ?? 0` (~38pt on MacBook Pro with notch, 0 otherwise)
  - `x = screenFrame.midX - windowSize.width / 2`
  - `y = screenFrame.maxY - notchHeight - windowSize.height` (AppKit: y=0 is bottom-left)
- `static var hasNotch: Bool`: `(NSScreen.main?.safeAreaInsets.top ?? 0) > 0`

**Note:** `safeAreaInsets` is macOS 12+. Wrap with `#available(macOS 12, *)` guard; fall back to top-center positioning on older systems.

---

## Component 8 — Notch Window

**Files to create:**
- `Sources/NotchLookup/UI/NotchWindow.swift`

**Two types in this file:**

**`NotchWindow: NSPanel`**
- `styleMask: [.borderless, .nonactivatingPanel]` — borderless + doesn't steal focus from the app user copied from
- `level = .screenSaver` — floats above all apps
- `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`
- `canBecomeKey = true` (required to receive Tab/Esc), `canBecomeMain = false`

**`@MainActor NotchWindowController`**
- Properties: `NotchWindow`, `NotchViewModel`, `NSHostingView<NotchView>`, key monitor ref, mouse monitor ref
- `setupContentView()`: creates `NSHostingView(rootView: NotchView(viewModel:))`, sets as `window.contentView`, clears layer background
- `setupKeyMonitor()`: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` — Tab (keyCode 48) → `viewModel.cycleMode()`; Esc (keyCode 53) → `dismiss()`; other keys pass through
- `show(with text: String)`:
  1. `viewModel.reset(inputText: text)`
  2. `window.setFrame(NotchPositioner.windowFrame(), display: false)`
  3. Start 10pt above target, alphaValue = 0, `orderFront(nil)`
  4. `NSAnimationContext` spring-in (duration 0.4, cubic Bezier `0.34, 1.56, 0.64, 1.0`)
  5. Add global mouse monitor for click-outside dismiss
  6. `Task { await viewModel.startStreaming() }`
- `dismiss()`:
  1. Remove mouse monitor
  2. Fade out (duration 0.2, easeIn)
  3. On completion: `window.orderOut(nil)`, `viewModel.cancelStreaming()`

Spring animation:
```swift
var startFrame = targetFrame
startFrame.origin.y += 10
window.setFrame(startFrame, display: false)
window.alphaValue = 0
window.orderFront(nil)
NSAnimationContext.runAnimationGroup { ctx in
    ctx.duration = 0.4
    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
    window.animator().setFrame(targetFrame, display: true)
    window.animator().alphaValue = 1.0
}
```

**Verify:** Hotkey fires → empty notch window appears at correct position, dismisses on Esc/click-outside.

---

## Component 9 — Mode Selector UI

**Files to create:**
- `Sources/NotchLookup/UI/ModeSelector.swift`

**What it does:**
- `struct ModeSelector: View` — takes `selectedMode: LookupMode`
- `HStack` of pill labels for `.explain`, `.define`, `.math`
- Each pill: `Capsule` background — white 90% opacity if selected, white 8% if not
- Text: black + semibold if selected, white 45% opacity if not; size 10pt
- Animated with `.spring(response: 0.25, dampingFraction: 0.7)` on `isSelected`
- Trailing "Tab to switch" label in white 25% opacity, size 9pt

Also define `LookupMode` enum here (or in `AnthropicClient.swift` — pick one, import the other):
```swift
enum LookupMode: String, CaseIterable {
    case explain = "Explain"
    case define  = "Define"
    case math    = "Math"
}
```

---

## Component 10 — Notch View + ViewModel

**Files to create:**
- `Sources/NotchLookup/UI/NotchView.swift`

**`@MainActor NotchViewModel: ObservableObject`**
- `@Published var displayText = ""`
- `@Published var mode: LookupMode = .explain`
- `@Published var isStreaming = false`
- `@Published var hasError = false`
- `private var inputText = ""`
- `private var streamTask: Task<Void, Never>?`
- `reset(inputText:)` — clears text/error/streaming state, keeps mode
- `startStreaming()` — cancels prior task; iterates `AnthropicClient.shared.stream(text:mode:)`; appends chunks to `displayText`; handles `.missingAPIKey` with friendly message
- `cycleMode()` — cycles `LookupMode.allCases` only if `!isStreaming`
- `cancelStreaming()` — cancels and nils `streamTask`

**`NotchView: View`**
```
ZStack
└── RoundedRectangle(cornerRadius: 20)
    └── .fill(.black.opacity(0.88))
    └── .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
VStack(alignment: .leading, spacing: 8)
├── ModeSelector(selectedMode: viewModel.mode)
├── Text(viewModel.displayText)          ← response, white 90%, size 13 rounded
│   OR Text("Listening...")              ← placeholder, white 40%
└── ProgressView()                       ← shown while isStreaming, scaled 0.5x
```
- Frame: width 340, flexible height
- Padding: 16pt horizontal, 12pt vertical

---

## Component 11 — Anthropic Streaming Client

**Files to create:**
- `Sources/NotchLookup/Core/AnthropicClient.swift`

**What it does:**
- `final class AnthropicClient` with `static let shared`
- `func stream(text: String, mode: LookupMode) throws -> AsyncThrowingStream<String, Error>`

Request setup:
- URL: `https://api.anthropic.com/v1/messages`
- Method: POST
- Headers: `Content-Type: application/json`, `x-api-key: <from Keychain>`, `anthropic-version: 2023-06-01`
- Body: `model: claude-haiku-3-5`, `max_tokens: 150`, `stream: true`, system prompt, user message prefixed with mode

System prompt:
> "You are a concise study assistant. Respond in 2-3 sentences maximum. For Explain mode: explain the concept simply for a college student. For Define mode: give a single sentence dictionary-style definition. For Math mode: show the answer and key steps only."

SSE parsing (inside `AsyncThrowingStream`):
1. `URLSession.shared.bytes(for: request)` → `AsyncBytes`
2. Accumulate bytes into lines
3. Lines prefixed `data: ` → strip prefix → parse JSON
4. Extract: `obj["type"] == "content_block_delta"` → `obj["delta"]["type"] == "text_delta"` → yield `obj["delta"]["text"]`
5. `data: [DONE]` → `continuation.finish()`
6. Non-2xx HTTP status → throw `.httpError(statusCode)`

Error enum:
```swift
enum AnthropicError: Error {
    case missingAPIKey
    case httpError(Int)
}
```

**Verify:** Full end-to-end — select text, Cmd+Shift+E, response streams into notch window.

---

## Final Wiring Check

In `AppDelegate`, replace all stubs so the real flow is:
```
HotkeyManager handler
  → TextGrabber.grabSelectedText()
  → guard text not empty
  → notchWindowController.show(with: text)
      → viewModel.reset(inputText:)
      → window appears with animation
      → viewModel.startStreaming()
          → AnthropicClient.stream(text:mode:)
          → chunks append to displayText
          → NotchView updates live
```

---

## Verification Checklist

- [ ] `swift package resolve` — HotKey fetched
- [ ] `swift build` — zero errors
- [ ] `./build.sh` — `NotchLookup.app` produced
- [ ] App icon in menu bar, menu opens
- [ ] Settings → enter API key → Save → key persists after relaunch
- [ ] Accessibility permission granted
- [ ] Select text in any app → Cmd+Shift+E → notch window appears
- [ ] Response streams in within ~1s
- [ ] Tab cycles Explain → Define → Math before response loads
- [ ] Esc dismisses window
- [ ] Click outside dismisses window
- [ ] No Dock icon, no app switcher entry
