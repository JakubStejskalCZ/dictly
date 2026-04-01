import SwiftData

public enum DictlySchema {
    public static let all: [any PersistentModel.Type] = [
        Campaign.self,
        Session.self,
        Tag.self,
        TagCategory.self
    ]
}
