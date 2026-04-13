import SwiftUI

// MARK: - NotchViewModel

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var displayText: String = ""
    @Published var mode: LookupMode = .explain
    @Published var isStreaming: Bool = false
    @Published var hasError: Bool = false
    // Drives the boring.notch-style expansion: false = collapsed pill, true = full overlay.
    @Published var isRevealed: Bool = false

    private var inputText: String = ""
    private var streamTask: Task<Void, Never>?

    /// Clears output state for a new query; preserves the current mode.
    /// Also collapses the pill so the next `reveal()` can animate it open.
    func reset(inputText: String) {
        self.inputText = inputText
        displayText = ""
        hasError = false
        isStreaming = false
        isRevealed = false
    }

    /// Triggers the collapsed → expanded spring animation in NotchView.
    func reveal() {
        isRevealed = true
    }

    /// Cancels any in-flight task, then streams chunks from AnthropicClient
    /// into displayText. Handles missingAPIKey with a user-facing message.
    func startStreaming() async {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = true

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in try AnthropicClient.shared.stream(text: inputText, mode: mode) {
                    guard !Task.isCancelled else { break }
                    displayText += chunk
                }
            } catch AnthropicError.missingAPIKey {
                hasError = true
                displayText = "No API key set — open Settings (menu bar icon) to add your Anthropic key."
            } catch is CancellationError {
                // Window was dismissed mid-stream; no message needed.
            } catch let AnthropicError.httpError(status) {
                hasError = true
                displayText = "HTTP \(status) from Anthropic API"
            } catch {
                hasError = true
                displayText = "Error: \(error.localizedDescription)"
            }
            isStreaming = false
        }
        streamTask = task
        await task.value
    }

    /// Advances to the next mode in the cycle; no-op while streaming.
    func cycleMode() {
        guard !isStreaming else { return }
        let all = LookupMode.allCases
        let idx = all.firstIndex(of: mode) ?? 0
        mode = all[(idx + 1) % all.count]
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
}

// MARK: - NotchView

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    // Collapsed size matches the MacBook Pro hardware notch footprint — when the
    // pill is collapsed it's visually indistinguishable from the notch itself.
    // Both states use explicit width AND height so SwiftUI's spring can interpolate
    // both dimensions in lockstep — using `nil`/flexible heights on one side caused
    // a visible "contract to square, then snap to notch" step during dismiss.
    private let collapsedSize = CGSize(width: 200, height: 32)
    private let expandedSize  = CGSize(width: 360, height: 150)

    // Top corners stay 0 so the pill's top edge is flush with the screen top
    // (absorbing the hardware notch). Only the bottom corners round outward.
    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 22,
            bottomTrailingRadius: 22,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        // Top-align inside the fixed-size window so the pill hugs the notch.
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Solid black fill — merges with the hardware notch bezel.
                notchShape
                    .fill(Color.black)

                VStack(alignment: .leading, spacing: 8) {
                    ModeSelector(selectedMode: viewModel.mode)

                    if viewModel.displayText.isEmpty {
                        Text("Listening…")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(viewModel.displayText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if viewModel.isStreaming {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(height: 12)
                    }
                }
                // Extra top padding pushes content below the hardware notch cutout.
                .padding(.top, 44)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                // Clip overflowing text so the content never pushes past the
                // expanded frame (critical for smooth contract — any residual
                // overflow would fight the spring during dismiss).
                .frame(
                    width: expandedSize.width,
                    height: expandedSize.height,
                    alignment: .top
                )
                .clipped()
                // Fade faster than the frame springs so content is gone by the
                // time the pill is mostly collapsed — avoids a "squished content"
                // frame during the contract.
                .opacity(viewModel.isRevealed ? 1 : 0)
                .animation(.easeInOut(duration: 0.18), value: viewModel.isRevealed)
            }
            .frame(
                width: viewModel.isRevealed ? expandedSize.width : collapsedSize.width,
                height: viewModel.isRevealed ? expandedSize.height : collapsedSize.height
            )
            .clipped()
            // Boring.notch's signature spring: response 0.42, damping 0.8 (slight overshoot).
            .animation(.spring(response: 0.42, dampingFraction: 0.8), value: viewModel.isRevealed)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
