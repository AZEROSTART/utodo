import CoreGraphics
import Testing
@testable import UTodoCore

@Suite struct CardDragZoneTests {
    private let size = CGSize(width: 268, height: 240)

    @Test func headerIsAHandle() {
        #expect(CardDragZone.isHandle(at: CGPoint(x: 134, y: 0), cardSize: size))
        #expect(CardDragZone.isHandle(at: CGPoint(x: 20, y: 30), cardSize: size))
    }

    @Test func inputRowAndBodyAreNotHandles() {
        // 输入行 y≈38…66，中间是文本选区
        #expect(!CardDragZone.isHandle(at: CGPoint(x: 134, y: 50), cardSize: size))
        // 行正文
        #expect(!CardDragZone.isHandle(at: CGPoint(x: 134, y: 120), cardSize: size))
    }

    @Test func sideAndBottomInsetsAreHandles() {
        #expect(CardDragZone.isHandle(at: CGPoint(x: 3, y: 120), cardSize: size))
        #expect(CardDragZone.isHandle(at: CGPoint(x: 265, y: 120), cardSize: size))
        #expect(CardDragZone.isHandle(at: CGPoint(x: 134, y: 235), cardSize: size))
    }

    @Test func outsideTheCardIsNotAHandle() {
        #expect(!CardDragZone.isHandle(at: CGPoint(x: -5, y: 120), cardSize: size))
        #expect(!CardDragZone.isHandle(at: CGPoint(x: 134, y: 260), cardSize: size))
    }
}
