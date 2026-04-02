import Foundation

// MARK: - Transfer DTOs
// Codable Data Transfer Objects for .dictly bundle serialization.
// @Model macro conflicts with Codable synthesis — use separate DTOs.
// See: CategorySyncService.swift → SyncableCategory for the same pattern.

public struct SessionDTO: Codable, Equatable {
    public let uuid: UUID
    public let title: String
    public let sessionNumber: Int
    public let date: Date
    public let duration: TimeInterval
    public let locationName: String?
    public let locationLatitude: Double?
    public let locationLongitude: Double?
    public let summaryNote: String?
    public let pauseIntervals: [PauseInterval]

    public init(
        uuid: UUID,
        title: String,
        sessionNumber: Int,
        date: Date,
        duration: TimeInterval,
        locationName: String?,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        summaryNote: String?,
        pauseIntervals: [PauseInterval]
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
        self.pauseIntervals = pauseIntervals
    }
}

public struct TagDTO: Codable, Equatable {
    public let uuid: UUID
    public let label: String
    public let categoryName: String
    public let anchorTime: TimeInterval
    public let rewindDuration: TimeInterval
    public let notes: String?
    public let transcription: String?
    public let createdAt: Date

    public init(
        uuid: UUID,
        label: String,
        categoryName: String,
        anchorTime: TimeInterval,
        rewindDuration: TimeInterval,
        notes: String?,
        transcription: String?,
        createdAt: Date
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

public struct CampaignDTO: Codable, Equatable {
    public let uuid: UUID
    public let name: String
    public let descriptionText: String
    public let createdAt: Date

    public init(
        uuid: UUID,
        name: String,
        descriptionText: String,
        createdAt: Date
    ) {
        self.uuid = uuid
        self.name = name
        self.descriptionText = descriptionText
        self.createdAt = createdAt
    }
}

/// Root structure for the .dictly bundle's session.json file.
/// Contains a format version, session metadata, all tags, and optional campaign association.
public struct TransferBundle: Codable, Equatable {
    public let version: Int
    public let session: SessionDTO
    public let tags: [TagDTO]
    public let campaign: CampaignDTO?

    public init(
        version: Int = 1,
        session: SessionDTO,
        tags: [TagDTO],
        campaign: CampaignDTO?
    ) {
        self.version = version
        self.session = session
        self.tags = tags
        self.campaign = campaign
    }
}

// MARK: - Model → DTO Conversions

public extension Session {
    func toDTO() -> SessionDTO {
        SessionDTO(
            uuid: uuid,
            title: title,
            sessionNumber: sessionNumber,
            date: date,
            duration: duration,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            summaryNote: summaryNote,
            pauseIntervals: pauseIntervals
        )
    }
}

public extension Tag {
    func toDTO() -> TagDTO {
        TagDTO(
            uuid: uuid,
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: rewindDuration,
            notes: notes,
            transcription: transcription,
            createdAt: createdAt
        )
    }
}

public extension Campaign {
    func toDTO() -> CampaignDTO {
        CampaignDTO(
            uuid: uuid,
            name: name,
            descriptionText: descriptionText,
            createdAt: createdAt
        )
    }
}

// MARK: - DTO → Model Factory Methods
// @Model classes don't support convenience init in extensions (macro limitation).
// Use static factory methods as the import path instead.

public extension Session {
    static func from(_ dto: SessionDTO) -> Session {
        let session = Session(
            uuid: dto.uuid,
            title: dto.title,
            sessionNumber: dto.sessionNumber,
            date: dto.date,
            duration: dto.duration,
            locationName: dto.locationName,
            locationLatitude: dto.locationLatitude,
            locationLongitude: dto.locationLongitude,
            summaryNote: dto.summaryNote
        )
        session.pauseIntervals = dto.pauseIntervals
        return session
    }
}

public extension Tag {
    static func from(_ dto: TagDTO) -> Tag {
        Tag(
            uuid: dto.uuid,
            label: dto.label,
            categoryName: dto.categoryName,
            anchorTime: dto.anchorTime,
            rewindDuration: dto.rewindDuration,
            notes: dto.notes,
            transcription: dto.transcription,
            createdAt: dto.createdAt
        )
    }
}

public extension Campaign {
    static func from(_ dto: CampaignDTO) -> Campaign {
        Campaign(
            uuid: dto.uuid,
            name: dto.name,
            descriptionText: dto.descriptionText,
            createdAt: dto.createdAt
        )
    }
}
