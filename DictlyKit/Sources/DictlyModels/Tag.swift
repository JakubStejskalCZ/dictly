import Foundation
import SwiftData

@Model
public final class Tag {
    public var uuid: UUID
    public var label: String
    public var categoryName: String
    public var anchorTime: TimeInterval
    public var rewindDuration: TimeInterval
    public var notes: String?
    public var transcription: String?
    public var createdAt: Date
    @Relationship(inverse: \Session.tags) public var session: Session?

    public init(
        uuid: UUID = UUID(),
        label: String,
        categoryName: String,
        anchorTime: TimeInterval,
        rewindDuration: TimeInterval,
        notes: String? = nil,
        transcription: String? = nil,
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.label = label
        self.categoryName = categoryName
        self.anchorTime = anchorTime
        self.rewindDuration = rewindDuration
        self.notes = notes
        self.transcription = transcription
        self.createdAt = createdAt
    }
}
