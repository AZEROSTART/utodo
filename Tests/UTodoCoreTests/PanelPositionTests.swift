import CoreGraphics
import Foundation
import Testing
@testable import UTodoCore

@Suite struct PanelPositionTests {
    @Test func defaultPlacementSitsUnderTheMenuBar() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let r = PanelPosition.resolve(nil, panelSize: CGSize(width: 268, height: 240),
                                      screens: [("A", screen)], mainScreenID: "A")
        #expect(r.placement == PanelPlacement(displayID: "A", offsetFromRight: 16, offsetFromTop: 24))
        #expect(r.origin == CGPoint(x: 1920 - 16 - 268, y: 1080 - 24 - 240))
    }

    @Test func storedPlacementOnMissingDisplayFallsBackToMain() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let stored = PanelPlacement(displayID: "GONE", offsetFromRight: 40, offsetFromTop: 60)
        let r = PanelPosition.resolve(stored, panelSize: CGSize(width: 268, height: 240),
                                      screens: [("MAIN", screen)], mainScreenID: "MAIN")
        #expect(r.placement.displayID == "MAIN")
        #expect(r.origin.x == CGFloat(1132))
    }

    @Test func dragRoundTripsToPlacement() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let p = PanelPosition.placement(forOrigin: CGPoint(x: 100, y: 500),
                                        panelSize: CGSize(width: 268, height: 240),
                                        screens: [("A", screen)])
        #expect(p?.displayID == "A")
        #expect(p?.offsetFromRight == CGFloat(1144))
        #expect(p?.offsetFromTop == CGFloat(242))
    }
}
