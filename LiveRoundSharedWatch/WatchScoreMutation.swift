import Foundation

struct WatchScoreMutation: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    enum Operation: Codable, Equatable, Sendable {
        case set(Int)
        case clear
    }

    let schemaVersion: Int
    let id: UUID
    let deviceSequence: Int64
    let roundID: String
    let holeNumber: Int
    let scoringUnitID: String
    let participantIDs: [String]
    let anchorParticipantID: String
    let operation: Operation
    let observedScoreRevision: String?
    let enteredAt: Date

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: UUID = UUID(),
        deviceSequence: Int64,
        roundID: String,
        holeNumber: Int,
        scoringUnitID: String,
        participantIDs: [String],
        anchorParticipantID: String,
        operation: Operation,
        observedScoreRevision: String?,
        enteredAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.deviceSequence = deviceSequence
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.scoringUnitID = scoringUnitID
        self.participantIDs = participantIDs
        self.anchorParticipantID = anchorParticipantID
        self.operation = operation
        self.observedScoreRevision = observedScoreRevision
        self.enteredAt = enteredAt
    }
}
