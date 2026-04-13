# NotchLookup

AI-powered quick lookup that lives in the MacBook notch.

<!-- Add a screenshot here: docs/screenshot.png -->

## What it does

Press **⌘⇧E** anywhere in macOS. NotchLookup grabs whatever text you have selected, sends it to Claude, and streams a 2–3 sentence response into a borderless window tucked directly under the hardware notch. Three modes, cycled with `Tab` before the response starts loading:

- **Explain** — concise explanation for a college student
- **Define** — one-sentence dictionary-style definition
- **Math** — answer plus key steps

Press `Esc` or click outside to dismiss.

## Requirements

- macOS 13 or newer
- A MacBook with a hardware notch (technically works without one — the pill just sits at the top of the screen)
- Xcode (or just the Swift toolchain, 5.9+)
- An Anthropic API key — [get one here](https://console.anthropic.com/)

## Build

This is a Swift Package executable assembled into a `.app` bundle by `build.sh`. No Xcode project, no GUI clicks — just the terminal.

**One-time setup:** create a self-signed code-signing cert so Keychain ACLs persist across rebuilds.

1. Open **Keychain Access**
2. Menu bar → **Keychain Access** → **Certificate Assistant** → **Create a Certificate…**
3. Name: `NotchLookup Dev`, Identity Type: `Self Signed Root`, Certificate Type: `Code Signing`
4. Click **Create** → **Continue** → **Done**

Then build and run:

```bash
./build.sh
open NotchLookup.app
```

## First-run setup

1. macOS will prompt for **Accessibility** permission — grant it (required so the app can synthesize ⌘C to read selected text from other apps)
2. Click the 🔍 icon in the menu bar → **Settings…**
3. Paste your Anthropic API key, click **Save**

The key is stored in the macOS Keychain. You only need to do this once.

## Tests

```bash
swift test
```

39 tests across `KeychainManager`, `TextGrabber`, `NotchPositioner`, and `AnthropicClient` (SSE parser mocked via `URLProtocol` — no API key or network needed).

## Tech stack

- Swift 5.9, SwiftUI, AppKit
- [`HotKey`](https://github.com/soffes/HotKey) — global hotkey registration (only external dependency)
- Anthropic Messages API with SSE streaming, model `claude-haiku-4-5`
- macOS Keychain for API key storage
- `CGEvent` for synthetic ⌘C, `NSPanel` for the borderless notch overlay

## Project layout

```
Sources/
  NotchLookup/          # Executable target — App entry, AppDelegate, SwiftUI views
  NotchLookupCore/      # Testable library — KeychainManager, AnthropicClient,
                        # TextGrabber, NotchPositioner, LookupMode
Tests/NotchLookupTests/ # Swift Testing suite
build.sh                # Builds the executable and assembles NotchLookup.app
```

## Known limitations

- Not intended for App Store distribution — uses non-sandboxed Keychain access and synthetic keyboard events
- Responses are capped at 150 tokens to keep the notch UI tiny
- No scrolling — if a response overflows, it's clipped
