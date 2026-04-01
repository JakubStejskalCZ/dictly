import SwiftUI

// MARK: - DictlySpacing

/// Design token namespace for Dictly's 8-point spacing grid.
///
/// All values are `CGFloat` base constants — multiply or use `@ScaledMetric` in
/// views when spacing should scale with Dynamic Type.
public enum DictlySpacing {

    // MARK: Grid Tokens

    /// Extra-small — 4pt
    public static let xs: CGFloat = 4
    /// Small — 8pt
    public static let sm: CGFloat = 8
    /// Medium — 16pt
    public static let md: CGFloat = 16
    /// Large — 24pt
    public static let lg: CGFloat = 24
    /// Extra-large — 32pt
    public static let xl: CGFloat = 32
    /// 2× Extra-large — 48pt
    public static let xxl: CGFloat = 48

    // MARK: Tap Targets

    /// Minimum interactive tap target — 48pt.
    ///
    /// Larger than Apple HIG minimum (44pt) to accommodate one-handed mid-game tapping.
    public static let minTapTarget: CGFloat = 48
}
