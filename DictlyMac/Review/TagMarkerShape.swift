import SwiftUI

// MARK: - MarkerShape

/// Represents the accessibility shape assigned to each tag category marker.
///
/// Each default category maps to a distinct shape (UX-DR16) so the waveform
/// is readable without relying on color alone.
enum MarkerShape: Equatable {
    case circle
    case diamond
    case square
    case triangle
    case hexagon

    /// Returns the marker shape for the given category name.
    static func shape(for categoryName: String) -> MarkerShape {
        switch categoryName.lowercased() {
        case "story":    return .circle
        case "combat":   return .diamond
        case "roleplay": return .square
        case "world":    return .triangle
        case "meta":     return .hexagon
        default:         return .circle
        }
    }
}

// MARK: - TagMarkerShapeView

/// Renders a category-specific shape filled with the given color.
struct TagMarkerShapeView: View {
    let shape: MarkerShape
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch shape {
            case .circle:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)

            case .diamond:
                Rectangle()
                    .fill(color)
                    .frame(width: size - 1, height: size - 1)
                    .rotationEffect(.degrees(45))
                    .frame(width: size, height: size)

            case .square:
                Rectangle()
                    .fill(color)
                    .frame(width: size - 1, height: size - 1)

            case .triangle:
                TriangleShape()
                    .fill(color)
                    .frame(width: size, height: size)

            case .hexagon:
                HexagonShape()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Shape Definitions

/// Equilateral triangle pointing upward.
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Regular hexagon.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let point = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
