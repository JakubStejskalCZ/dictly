import Foundation
import SwiftData

@Model
public final class Campaign {
    public var uuid: UUID
    public var name: String
    public var descriptionText: String
    public var createdAt: Date
    @Relationship(deleteRule: .cascade) public var sessions: [Session]

    public init(
        uuid: UUID = UUID(),
        name: String,
        descriptionText: String = "",
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.name = name
        self.descriptionText = descriptionText
        self.createdAt = createdAt
        self.sessions = []
    }
}
