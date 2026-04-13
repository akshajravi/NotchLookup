# NotchLookup

## Project Overview
A macOS app that provides AI-powered quick lookup in the MacBook notch.
Invoked via global hotkey, grabs selected text, streams response from
Anthropic API into a minimal notch overlay.

## Tech Stack
- Swift 5.9+
- SwiftUI (macOS 13+ target)
- HotKey package — global hotkey registration
- Anthropic API (claude-haiku-3-5) with SSE streaming
- Keychain for API key storage

## Project Structure
- App/ — entry point and AppDelegate
- Core/ — business logic (hotkey, text grab, API, keychain)
- UI/ — SwiftUI views and window management
- Utils/ — helpers like notch positioning

## Key Technical Decisions
- Use CGEvent synthetic Cmd+C to grab selected text, then read NSPasteboard
- Notch window: NSWindow level .screenSaver, borderless, clear background
- Position notch window using NSScreen.main?.frame — align to top center
- Stream API responses via SSE so text appears immediately
- Never hardcode API key — always use Keychain

## Coding Conventions
- One class/struct per file
- Async/await for all API calls
- No third party dependencies beyond HotKey package
- Comments on anything non-obvious especially CGEvent and window positioning

## Current Focus
Building MVP — global hotkey → text grab → notch UI → API response

## Known Constraints
- macOS 13+ only (notch hardware + API availability)
- App will not be App Store distributed (uses private-adjacent APIs)
- Keep notch UI minimal — no scrolling, 2-3 sentence responses max

## API
- Model: claude-haiku-3-5
- Max tokens: 150 (enforces brevity)
- Streaming: enabled
- API key: stored in Keychain under "notchlookup-anthropic-key"

## Modes
- Explain (default) — 2-3 sentence concept explanation
- Define — single sentence definition
- Math — answer + key steps only
- Toggle with Tab before response loads

## Session Start
- Read progress.md and plan.md before doing anything else to understand the current projects state

## Session End
- At the end of every session, you must update progress.md with:
    - What component/feature was worked on
    - What was accomplished (bullet points)
    - Any decisions made and why
    - What's left to do or next steps
    - Any blockers or notes for the next session