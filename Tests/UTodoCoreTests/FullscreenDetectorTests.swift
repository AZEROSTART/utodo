import CoreGraphics
import Foundation
import Testing
@testable import UTodoCore

@Suite struct FullscreenDetectorTests {
    @Test func fullscreenWindowCoveringScreenIsDetected() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(FullscreenDetector.isFullscreen(
            frontPID: 42,
            windows: [.init(ownerPID: 42, bounds: screen)],
            screenFrame: screen
        ))
    }

    @Test func maximizedButNotFullscreenWindowIsIgnored() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 920)
        #expect(!FullscreenDetector.isFullscreen(
            frontPID: 42,
            windows: [.init(ownerPID: 42, bounds: visible)],
            screenFrame: screen
        ))
    }

    @Test func otherAppsFullscreenWindowDoesNotCount() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(!FullscreenDetector.isFullscreen(
            frontPID: 7,
            windows: [.init(ownerPID: 42, bounds: screen)],
            screenFrame: screen
        ))
    }

    @Test func nonNormalWindowLayersAreIgnored() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(!FullscreenDetector.isFullscreen(
            frontPID: 42,
            windows: [.init(ownerPID: 42, bounds: screen, layer: 25)],
            screenFrame: screen
        ))
    }

    @Test func toleranceAbsorbsOnePointRounding() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let inset = screen.insetBy(dx: 1, dy: 1)
        #expect(FullscreenDetector.isFullscreen(
            frontPID: 42,
            windows: [.init(ownerPID: 42, bounds: inset)],
            screenFrame: screen
        ))
    }
}
