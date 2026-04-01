import XCTest
import SwiftUI
@testable import DictlyTheme

final class ColorsTests: XCTestCase {

    // MARK: - Tag Category Colors

    func testTagCategoryColorsCount() {
        // Verify all 5 tag category colors are accessible
        let colors: [Color] = [
            DictlyColors.TagCategory.story,
            DictlyColors.TagCategory.combat,
            DictlyColors.TagCategory.roleplay,
            DictlyColors.TagCategory.world,
            DictlyColors.TagCategory.meta,
        ]
        XCTAssertEqual(colors.count, 5)
    }

    func testTagCategoryColorValues() {
        let env = EnvironmentValues()

        assertColorMatchesHex(
            DictlyColors.TagCategory.story,
            r: 0xD9, g: 0x77, b: 0x06,
            in: env,
            name: "story"
        )
        assertColorMatchesHex(
            DictlyColors.TagCategory.combat,
            r: 0xDC, g: 0x26, b: 0x26,
            in: env,
            name: "combat"
        )
        assertColorMatchesHex(
            DictlyColors.TagCategory.roleplay,
            r: 0x7C, g: 0x3A, b: 0xED,
            in: env,
            name: "roleplay"
        )
        assertColorMatchesHex(
            DictlyColors.TagCategory.world,
            r: 0x05, g: 0x96, b: 0x69,
            in: env,
            name: "world"
        )
        assertColorMatchesHex(
            DictlyColors.TagCategory.meta,
            r: 0x4B, g: 0x7B, b: 0xE5,
            in: env,
            name: "meta"
        )
    }

    func testTagCategoryColorsAreDistinct() {
        let env = EnvironmentValues()
        let story = DictlyColors.TagCategory.story.resolve(in: env)
        let combat = DictlyColors.TagCategory.combat.resolve(in: env)
        let roleplay = DictlyColors.TagCategory.roleplay.resolve(in: env)
        let world = DictlyColors.TagCategory.world.resolve(in: env)
        let meta = DictlyColors.TagCategory.meta.resolve(in: env)

        // Each tag category should resolve to a distinct color
        XCTAssertNotEqual(story.red, combat.red, accuracy: 0.01)
        XCTAssertNotEqual(roleplay.blue, world.blue, accuracy: 0.01)
        XCTAssertNotEqual(world.green, meta.green, accuracy: 0.01)
    }

    // MARK: - Accent / State Colors

    func testAccentStateColorsExist() {
        // Verify all accent/state colors are accessible (compilation + accessibility check)
        let env = EnvironmentValues()
        let _ = DictlyColors.recordingActive.resolve(in: env)
        let _ = DictlyColors.success.resolve(in: env)
        let _ = DictlyColors.warning.resolve(in: env)
        let _ = DictlyColors.destructive.resolve(in: env)
    }

    func testAccentStateColorValues() {
        let env = EnvironmentValues()

        assertColorMatchesHex(DictlyColors.recordingActive, r: 0xEF, g: 0x44, b: 0x44, in: env, name: "recordingActive")
        assertColorMatchesHex(DictlyColors.success, r: 0x16, g: 0xA3, b: 0x4A, in: env, name: "success")
        assertColorMatchesHex(DictlyColors.warning, r: 0xF5, g: 0x9E, b: 0x0B, in: env, name: "warning")
        assertColorMatchesHex(DictlyColors.destructive, r: 0xDC, g: 0x26, b: 0x26, in: env, name: "destructive")
    }

    // MARK: - Adaptive Base Palette (existence check)

    func testBasePaletteColorsExist() {
        let env = EnvironmentValues()
        let _ = DictlyColors.background.resolve(in: env)
        let _ = DictlyColors.surface.resolve(in: env)
        let _ = DictlyColors.textPrimary.resolve(in: env)
        let _ = DictlyColors.textSecondary.resolve(in: env)
        let _ = DictlyColors.border.resolve(in: env)
    }

    // MARK: - Helpers

    /// Asserts that a color resolves to the expected sRGB hex component values.
    ///
    /// Both the actual and expected colors are resolved in the same environment so
    /// the comparison is in the same linear-light color space.
    private func assertColorMatchesHex(
        _ color: Color,
        r: UInt8, g: UInt8, b: UInt8,
        in env: EnvironmentValues,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = color.resolve(in: env)
        let expected = Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0).resolve(in: env)
        XCTAssertEqual(actual.red, expected.red, accuracy: 0.001, "\(name) red channel mismatch", file: file, line: line)
        XCTAssertEqual(actual.green, expected.green, accuracy: 0.001, "\(name) green channel mismatch", file: file, line: line)
        XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.001, "\(name) blue channel mismatch", file: file, line: line)
    }
}
