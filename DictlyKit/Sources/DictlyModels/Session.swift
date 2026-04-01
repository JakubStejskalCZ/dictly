import Foundation
import SwiftData

@Model
public final class Session {
    public var uuid: UUID
    public var title: String
    public var sessionNumber: Int
    public var date: Date
    public var duration: TimeInterval
    public var locationName: String?
    public var locationLatitude: Double?
    public var locationLongitude: Double?
    public var summaryNote: String?
    @Relationship(deleteRule: .cascade) public var tags: [Tag]
    @Relationship(inverse: \Campaign.sessions) public var campaign: Campaign?

    public init(
        uuid: UUID = UUID(),
        title: String,
        sessionNumber: Int,
        date: Date = Date(),
        duration: TimeInterval = 0,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        summaryNote: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.sessionNumber = sessionNumber
        self.date = date
        self.duration = duration
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.summaryNote = summaryNote
        self.tags = []
    }
}
