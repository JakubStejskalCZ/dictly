import XCTest
import DictlyTheme

final class SpacingTests: XCTestCase {

    // MARK: - 8pt Grid Tokens

    func testGridTokenValues() {
        XCTAssertEqual(DictlySpacing.xs, 4)
        XCTAssertEqual(DictlySpacing.sm, 8)
        XCTAssertEqual(DictlySpacing.md, 16)
        XCTAssertEqual(DictlySpacing.lg, 24)
        XCTAssertEqual(DictlySpacing.xl, 32)
        XCTAssertEqual(DictlySpacing.xxl, 48)
    }

    func testTokensFollowEightPointGrid() {
        // Each token should be a multiple of 4
        XCTAssertEqual(DictlySpacing.xs.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DictlySpacing.sm.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DictlySpacing.md.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DictlySpacing.lg.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DictlySpacing.xl.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DictlySpacing.xxl.truncatingRemainder(dividingBy: 4), 0)
    }

    func testTokensAreStrictlyAscending() {
        XCTAssertLessThan(DictlySpacing.xs, DictlySpacing.sm)
        XCTAssertLessThan(DictlySpacing.sm, DictlySpacing.md)
        XCTAssertLessThan(DictlySpacing.md, DictlySpacing.lg)
        XCTAssertLessThan(DictlySpacing.lg, DictlySpacing.xl)
        XCTAssertLessThan(DictlySpacing.xl, DictlySpacing.xxl)
    }

    // MARK: - Tap Target

    func testMinTapTargetValue() {
        XCTAssertEqual(DictlySpacing.minTapTarget, 48)
    }

    func testMinTapTargetExceedsAppleHIG() {
        // Apple HIG minimum is 44pt; Dictly uses 48pt for mid-game tapping
        XCTAssertGreaterThan(DictlySpacing.minTapTarget, 44)
    }
}
