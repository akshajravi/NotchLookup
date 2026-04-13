import SwiftUI
import NotchLookupCore

struct ModeSelector: View {
    let selectedMode: LookupMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LookupMode.allCases, id: \.self) { mode in
                ModePill(label: mode.rawValue, isSelected: mode == selectedMode)
            }

            Spacer()

            Text("Tab to switch")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

// A single pill label.
private struct ModePill: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
