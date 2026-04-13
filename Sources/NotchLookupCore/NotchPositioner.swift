import AppKit

/// Calculates where to place the notch overlay window on the primary display.
///
/// The window sits flush with the very top of the screen so that its top edge
/// aligns with the hardware notch — the camera cutout becomes a visual part of
/// our black pill rather than a gap above it.
public enum NotchPositioner {

    /// Returns a window frame centered horizontally at the top of the main screen,
    /// with its top edge tucked directly under the hardware notch cutout.
    ///
    /// AppKit coordinate system: y = 0 is the bottom-left of the screen, so
    /// `screenFrame.maxY` is the top edge. On a MacBook with a notch,
    /// `safeAreaInsets.top` is the notch height (~38pt); on other displays it's 0.
    public static func windowFrame(windowSize: CGSize = CGSize(width: 340, height: 120)) -> CGRect {
        guard let screen = NSScreen.main else {
            // No screen found — return a sensible default at the top of a 1440×900 display.
            return CGRect(
                x: (1440 - windowSize.width) / 2,
                y: 900 - windowSize.height,
                width: windowSize.width,
                height: windowSize.height
            )
        }

        let screenFrame = screen.frame
        let notchHeight: CGFloat
        if #available(macOS 12, *) {
            notchHeight = screen.safeAreaInsets.top
        } else {
            notchHeight = 0
        }

        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.maxY - notchHeight - windowSize.height

        return CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }

    /// `true` when the primary display has a physical notch cutout.
    public static var hasNotch: Bool {
        if #available(macOS 12, *) {
            return (NSScreen.main?.safeAreaInsets.top ?? 0) > 0
        }
        return false
    }
}
