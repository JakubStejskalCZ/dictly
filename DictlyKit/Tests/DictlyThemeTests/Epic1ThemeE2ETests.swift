import XCTest
import SwiftUI
@testable import DictlyTheme

/// End-to-end theme validation tests for Story 1.2 acceptance criteria.
/// Verifies that the complete design token system is consistent and correct.
final class Epic1ThemeE2ETests: XCTestCase {

    // MARK: - Story 1.2 AC#1: Colors, Typography, Spacing Apply Correctly

    func testAllDesignTokensAccessible() {
        // Colors
        let _ = DictlyColors.background
        let _ = DictlyColors.surface
        let _ = DictlyColors.textPrimary
        let _ = DictlyColors.textSecondary
        let _ = DictlyColors.border

        // Tag category colors
        let _ = DictlyColors.TagCategory.story
        let _ = DictlyColors.TagCategory.combat
        let _ = DictlyColors.TagCategory.roleplay
        let _ = DictlyColors.TagCategory.world
        let _ = DictlyColors.TagCategory.meta

        // Accent/state colors
        let _ = DictlyColors.recordingActive
        let _ = DictlyColors.success
        let _ = DictlyColors.warning
        let _ = DictlyColors.destructive

        // Typography
        let _ = DictlyTypography.display
        let _ = DictlyTypography.h1
        let _ = DictlyTypography.h2
        let _ = DictlyTypography.h3
        let _ = DictlyTypography.body
        let _ = DictlyTypography.caption
        let _ = DictlyTypography.tagLabel
        let _ = DictlyTypography.monospacedDigits

        // Spacing
        let _ = DictlySpacing.xs
        let _ = DictlySpacing.sm
        let _ = DictlySpacing.md
        let _ = DictlySpacing.lg
        let _ = DictlySpacing.xl
        let _ = DictlySpacing.xxl
        let _ = DictlySpacing.minTapTarget

        // Animation
        let _ = DictlyAnimation.tagPlacement
        let _ = DictlyAnimation.tagPlacementSpring
        let _ = DictlyAnimation.tagPlacementStartScale
        let _ = DictlyAnimation.recordingBreath
    }

    // MARK: - Story 1.2 AC#3: 5 Tag Category Colors Defined

    func testAllFiveTagCategoryColorsDefined() {
        let env = EnvironmentValues()
        let colors = [
            ("story", DictlyColors.TagCategory.story),
            ("combat", DictlyColors.TagCategory.combat),
            ("roleplay", DictlyColors.TagCategory.roleplay),
            ("world", DictlyColors.TagCategory.world),
            ("meta", DictlyColors.TagCategory.meta),
        ]

        XCTAssertEqual(colors.count, 5, "Exactly 5 tag category colors must be defined")

        // Verify each resolves to a distinct color
        let resolved = colors.map { $0.1.resolve(in: env) }
        for i in 0..<resolved.count {
            for j in (i+1)..<resolved.count {
                let same = abs(resolved[i].red - resolved[j].red) < 0.01
                    && abs(resolved[i].green - resolved[j].green) < 0.01
                    && abs(resolved[i].blue - resolved[j].blue) < 0.01
                XCTAssertFalse(same, "\(colors[i].0) and \(colors[j].0) should be distinct colors")
            }
        }
    }

    func testTagCategoryColorHexValues() {
        let env = EnvironmentValues()

        // Story #D97706
        assertColorHex(DictlyColors.TagCategory.story, r: 0xD9, g: 0x77, b: 0x06, in: env, name: "story")
        // Combat #DC2626
        assertColorHex(DictlyColors.TagCategory.combat, r: 0xDC, g: 0x26, b: 0x26, in: env, name: "combat")
        // Roleplay #7C3AED
        assertColorHex(DictlyColors.TagCategory.roleplay, r: 0x7C, g: 0x3A, b: 0xED, in: env, name: "roleplay")
        // World #059669
        assertColorHex(DictlyColors.TagCategory.world, r: 0x05, g: 0x96, b: 0x69, in: env, name: "world")
        // Meta #4B7BE5
        assertColorHex(DictlyColors.TagCategory.meta, r: 0x4B, g: 0x7B, b: 0xE5, in: env, name: "meta")
    }

    // MARK: - Story 1.2 AC#4: 8pt Grid Spacing Tokens

    func testSpacingTokensMatch8ptGrid() {
        XCTAssertEqual(DictlySpacing.xs, 4, "xs should be 4pt")
        XCTAssertEqual(DictlySpacing.sm, 8, "sm should be 8pt")
        XCTAssertEqual(DictlySpacing.md, 16, "md should be 16pt")
        XCTAssertEqual(DictlySpacing.lg, 24, "lg should be 24pt")
        XCTAssertEqual(DictlySpacing.xl, 32, "xl should be 32pt")
        XCTAssertEqual(DictlySpacing.xxl, 48, "2xl should be 48pt")
    }

    func testAllSpacingTokensAreMultiplesOf4() {
        let tokens: [(String, CGFloat)] = [
            ("xs", DictlySpacing.xs),
            ("sm", DictlySpacing.sm),
            ("md", DictlySpacing.md),
            ("lg", DictlySpacing.lg),
            ("xl", DictlySpacing.xl),
            ("xxl", DictlySpacing.xxl),
            ("minTapTarget", DictlySpacing.minTapTarget),
        ]

        for (name, value) in tokens {
            XCTAssertEqual(
                value.truncatingRemainder(dividingBy: 4), 0,
                "\(name) (\(value)) should be a multiple of 4"
            )
        }
    }

    // MARK: - Story 1.2 AC#1: Typography Platform Tokens

    func testTypographyTokenCount() {
        let fonts: [Font] = [
            DictlyTypography.display,
            DictlyTypography.h1,
            DictlyTypography.h2,
            DictlyTypography.h3,
            DictlyTypography.body,
            DictlyTypography.caption,
            DictlyTypography.tagLabel,
            DictlyTypography.monospacedDigits,
        ]
        XCTAssertEqual(fonts.count, 8, "Type scale should expose 8 font tokens")
    }

    func testTypographyUsableWithSwiftUIText() {
        // Smoke test that each font token can be applied to a Text view
        let tokens: [Font] = [
            DictlyTypography.display,
            DictlyTypography.h1,
            DictlyTypography.h2,
            DictlyTypography.h3,
            DictlyTypography.body,
            DictlyTypography.caption,
            DictlyTypography.tagLabel,
            DictlyTypography.monospacedDigits,
        ]

        for font in tokens {
            let _ = Text("Test").font(font)
        }
    }

    // MARK: - Animation Accessibility

    func testAnimationsRespectReduceMotion() {
        // When reduceMotion is true, animations should return nil
        XCTAssertNil(DictlyAnimation.tagPlacement(reduceMotion: true), "tagPlacement should be nil with reduceMotion")
        XCTAssertNil(DictlyAnimation.tagPlacementSpring(reduceMotion: true), "tagPlacementSpring should be nil with reduceMotion")
        XCTAssertNil(DictlyAnimation.recordingBreath(reduceMotion: true), "recordingBreath should be nil with reduceMotion")
    }

    func testAnimationsReturnedWhenMotionEnabled() {
        // When reduceMotion is false, animations should return non-nil
        XCTAssertNotNil(DictlyAnimation.tagPlacement(reduceMotion: false))
        XCTAssertNotNil(DictlyAnimation.tagPlacementSpring(reduceMotion: false))
        XCTAssertNotNil(DictlyAnimation.recordingBreath(reduceMotion: false))
    }

    func testTagPlacementStartScale() {
        XCTAssertEqual(DictlyAnimation.tagPlacementStartScale, 0.95, "Tag placement should start at 0.95 scale")
    }

    // MARK: - Accent/State Color Values

    func testAccentStateColorValues() {
        let env = EnvironmentValues()

        // recordingActive #EF4444
        assertColorHex(DictlyColors.recordingActive, r: 0xEF, g: 0x44, b: 0x44, in: env, name: "recordingActive")
        // success #16A34A
        assertColorHex(DictlyColors.success, r: 0x16, g: 0xA3, b: 0x4A, in: env, name: "success")
        // warning #F59E0B
        assertColorHex(DictlyColors.warning, r: 0xF5, g: 0x9E, b: 0x0B, in: env, name: "warning")
        // destructive #DC2626
        assertColorHex(DictlyColors.destructive, r: 0xDC, g: 0x26, b: 0x26, in: env, name: "destructive")
    }

    // MARK: - Base Palette Existence

    func testBasePaletteColorsResolve() {
        let env = EnvironmentValues()
        // These are adaptive colors — we just verify they resolve without crashing
        let colors: [(String, Color)] = [
            ("background", DictlyColors.background),
            ("surface", DictlyColors.surface),
            ("textPrimary", DictlyColors.textPrimary),
            ("textSecondary", DictlyColors.textSecondary),
            ("border", DictlyColors.border),
        ]

        for (name, color) in colors {
            let resolved = color.resolve(in: env)
            // Verify components are in valid range
            XCTAssertGreaterThanOrEqual(resolved.red, 0, "\(name) red out of range")
            XCTAssertLessThanOrEqual(resolved.red, 1, "\(name) red out of range")
            XCTAssertGreaterThanOrEqual(resolved.green, 0, "\(name) green out of range")
            XCTAssertLessThanOrEqual(resolved.green, 1, "\(name) green out of range")
            XCTAssertGreaterThanOrEqual(resolved.blue, 0, "\(name) blue out of range")
            XCTAssertLessThanOrEqual(resolved.blue, 1, "\(name) blue out of range")
        }
    }

    // MARK: - Cross-Token Consistency

    func testMinTapTargetMatchesXXLSpacing() {
        XCTAssertEqual(DictlySpacing.minTapTarget, DictlySpacing.xxl,
                       "minTapTarget (48) should equal xxl (48) for consistent 48pt sizing")
    }

    func testSpacingTokensArePositive() {
        let tokens: [CGFloat] = [
            DictlySpacing.xs, DictlySpacing.sm, DictlySpacing.md,
            DictlySpacing.lg, DictlySpacing.xl, DictlySpacing.xxl,
            DictlySpacing.minTapTarget,
        ]
        for token in tokens {
            XCTAssertGreaterThan(token, 0, "All spacing tokens must be positive")
        }
    }

    // MARK: - Helpers

    private func assertColorHex(
        _ color: Color,
        r: UInt8, g: UInt8, b: UInt8,
        in env: EnvironmentValues,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = color.resolve(in: env)
        let expected = Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0).resolve(in: env)
        XCTAssertEqual(actual.red, expected.red, accuracy: 0.01, "\(name) red mismatch", file: file, line: line)
        XCTAssertEqual(actual.green, expected.green, accuracy: 0.01, "\(name) green mismatch", file: file, line: line)
        XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.01, "\(name) blue mismatch", file: file, line: line)
    }
}
