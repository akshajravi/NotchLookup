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
