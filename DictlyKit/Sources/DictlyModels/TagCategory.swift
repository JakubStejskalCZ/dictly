import Foundation
import SwiftData

@Model
public final class TagCategory {
    public var uuid: UUID
    public var name: String
    public var colorHex: String
    public var iconName: String
    public var sortOrder: Int
    public var isDefault: Bool

    public init(
        uuid: UUID = UUID(),
        name: String,
        colorHex: String,
        iconName: String,
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.uuid = uuid
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}
