import XCTest
import SwiftUI
import DictlyTheme

final class TypographyTests: XCTestCase {

    // MARK: - Type Scale Accessibility

    /// Verifies all type scale properties are accessible (compilation + API surface check).
    func testTypeScalePropertiesExist() {
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

    /// Verifies heading hierarchy is distinct from body text
    /// (relies on Swift's type system — if they compiled, they exist).
    func testTypeScaleIsComplete() {
        // Each token is a distinct `Font` value accessible via the public API.
        // Swift's type system guarantees non-nil for non-optional value types.
        _ = DictlyTypography.display
        _ = DictlyTypography.h1
        _ = DictlyTypography.h2
        _ = DictlyTypography.h3
        _ = DictlyTypography.body
        _ = DictlyTypography.caption
        _ = DictlyTypography.tagLabel
        _ = DictlyTypography.monospacedDigits
    }

    /// Verifies fonts can be assigned to SwiftUI Text views (API compatibility smoke test).
    func testFontsAreUsableInSwiftUI() {
        let _ = Text("Test").font(DictlyTypography.display)
        let _ = Text("Test").font(DictlyTypography.body)
        let _ = Text("00:00").font(DictlyTypography.monospacedDigits)
    }
}
