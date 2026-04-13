import AppKit
import Testing
import NotchLookupCore

// MARK: - windowFrame() tests
//
// These run against the real NSScreen.main in a test process (usually headless,
// with a single 1440×900 or similar virtual display). The exact pixel values
// vary by machine, so every assertion checks structural invariants — not hard-coded
// pixel positions.

@Suite("NotchPositioner.windowFrame")
struct WindowFrameTests {

    // MARK: - Size

    @Test("frame has the requested width and height")
    func frameSizeMatchesRequest() {
        let size = CGSize(width: 400, height: 100)
        let frame = NotchPositioner.windowFrame(windowSize: size)
        #expect(frame.width == 400)
        #expect(frame.height == 100)
    }

    @Test("frame uses default size (340 × 120) when called with no arguments")
    func defaultWindowSize() {
        let frame = NotchPositioner.windowFrame()
        #expect(frame.width == 340)
        #expect(frame.height == 120)
    }

    // MARK: - Horizontal centering

    @Test("frame is horizontally centered on the main screen")
    func horizontallyCenteredOnMainScreen() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let size = CGSize(width: 340, height: 120)
        let frame = NotchPositioner.windowFrame(windowSize: size)

        let expectedMidX = screen.frame.midX
        #expect(abs(frame.midX - expectedMidX) < 1,
                "midX \(frame.midX) should equal screen.frame.midX \(expectedMidX)")
    }

    // MARK: - Vertical positioning

    @Test("frame top edge is at or below the screen top edge (AppKit coords)")
    func frameTopEdgeBelowScreenTop() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let frame = NotchPositioner.windowFrame()

        // frame.maxY is the top of the window in AppKit coordinates.
        // It must not exceed the screen's top edge.
        #expect(frame.maxY <= screen.frame.maxY,
                "window top \(frame.maxY) must not exceed screen top \(screen.frame.maxY)")
    }

    @Test("frame bottom edge is above the lower portion of the screen")
    func frameBottomEdgeInTopRegion() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let frame = NotchPositioner.windowFrame()

        // The window should be in the top quarter of the screen at most.
        let topQuarter = screen.frame.maxY - screen.frame.height / 4
        #expect(frame.minY >= topQuarter,
                "window bottom \(frame.minY) should be in the top quarter of the screen")
    }

    // MARK: - On-screen bounds

    @Test("entire frame fits within the main screen bounds")
    func frameFitsWithinScreen() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let frame = NotchPositioner.windowFrame()

        #expect(frame.minX >= screen.frame.minX)
        #expect(frame.maxX <= screen.frame.maxX)
        #expect(frame.minY >= screen.frame.minY)
        #expect(frame.maxY <= screen.frame.maxY)
    }

    // MARK: - Custom sizes

    @Test("centering is correct for various window widths")
    func centeringForVariousWidths() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let widths: [CGFloat] = [200, 340, 500, 600]

        for width in widths {
            let frame = NotchPositioner.windowFrame(windowSize: CGSize(width: width, height: 80))
            let expectedMidX = screen.frame.midX
            #expect(abs(frame.midX - expectedMidX) < 1,
                    "width \(width): midX \(frame.midX) ≠ screen.frame.midX \(expectedMidX)")
        }
    }

    @Test("y position shifts up correctly for taller windows")
    func tallerWindowShiftsYDown() throws {
        try #require(NSScreen.main != nil, "no main screen in test environment")

        let shortFrame = NotchPositioner.windowFrame(windowSize: CGSize(width: 340, height: 80))
        let tallFrame  = NotchPositioner.windowFrame(windowSize: CGSize(width: 340, height: 200))

        // Both windows share the same top edge (maxY). The taller one has a lower minY.
        #expect(abs(shortFrame.maxY - tallFrame.maxY) < 1,
                "both windows should share the same top edge")
        #expect(tallFrame.minY < shortFrame.minY,
                "taller window bottom edge should be lower than shorter window's")
    }
}

// MARK: - hasNotch tests

@Suite("NotchPositioner.hasNotch")
struct HasNotchTests {

    @Test("hasNotch returns a Bool without crashing")
    func hasNotchReturnsBool() {
        // We can't assert a specific value since it depends on the hardware/display.
        // What we verify: it doesn't crash and returns the right type.
        let result: Bool = NotchPositioner.hasNotch
        // On headless CI there is typically no notch; on a physical MacBook Pro there is.
        // Either outcome is valid — just confirm the call succeeds.
        _ = result
    }

    @Test("hasNotch is consistent across repeated calls")
    func hasNotchIsStable() {
        let first  = NotchPositioner.hasNotch
        let second = NotchPositioner.hasNotch
        #expect(first == second, "hasNotch must return the same value on repeated calls")
    }

    @Test("windowFrame notch offset matches hasNotch")
    func notchOffsetConsistentWithHasNotch() throws {
        let screen = try #require(NSScreen.main, "no main screen in test environment")
        let frame = NotchPositioner.windowFrame()

        let frameTopEdge = frame.maxY
        let screenTopEdge = screen.frame.maxY

        if NotchPositioner.hasNotch {
            // With a notch, the window top must sit below the screen top.
            #expect(frameTopEdge < screenTopEdge,
                    "notch detected: window top \(frameTopEdge) should be below screen top \(screenTopEdge)")
        } else {
            // Without a notch, the window top should be flush with the screen top.
            #expect(abs(frameTopEdge - screenTopEdge) < 1,
                    "no notch: window top \(frameTopEdge) should equal screen top \(screenTopEdge)")
        }
    }
}
