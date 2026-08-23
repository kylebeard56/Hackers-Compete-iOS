import Foundation

struct RoundScoreCommandValidator {
    struct ValidatedCommand {
        let mutation: WatchScoreMutation
        let anchorParticipant: RoundParticipant
        let unit: WatchRoundSnapshot.Subject.HoleUnit
        let existingEntry: ScoreEntry?
    }

    enum ValidationError: Error, Equatable {
        case incompatibleSchema
        case roundUnavailable
        case roundNotLive
        case unauthorized
        case invalidSubject
        case invalidHole
        case invalidScore
        case staleScore(canonicalValue: Int?, canonicalRevision: String?)

        var acknowledgementCategory: WatchScoreAcknowledgement.ErrorCategory {
            switch self {
            case .incompatibleSchema, .invalidSubject: .invalidSubject
            case .roundUnavailable: .roundUnavailable
            case .roundNotLive: .roundNotLive
            case .unauthorized: .unauthorized
            case .invalidHole: .invalidHole
            case .invalidScore: .invalidScore
            case .staleScore: .staleScore
            }
        }
    }

    private let subjectBuilder = RoundScoringSubjectBuilder()

    func validate(
        _ mutation: WatchScoreMutation,
        snapshot: RoundSnapshot,
        participantID: String
    ) throws -> ValidatedCommand {
        guard mutation.schemaVersion == WatchScoreMutation.currentSchemaVersion else {
            throw ValidationError.incompatibleSchema
        }
        guard snapshot.round.id == mutation.roundID else {
            throw ValidationError.roundUnavailable
        }
        guard snapshot.round.status == .live else {
            throw ValidationError.roundNotLive
        }
        guard let viewer = snapshot.participants.first(where: { $0.id == participantID }),
              viewer.groupID?.isPopulated == true,
              snapshot.configuration.attendanceConfirmationEnabled != true
                || viewer.resolvedPresenceStatus != .noShow else {
            throw ValidationError.unauthorized
        }

        let projection: WatchRoundSnapshot
        do {
            projection = try subjectBuilder.build(snapshot: snapshot, participantID: participantID)
        } catch {
            throw ValidationError.unauthorized
        }
        guard projection.holes.contains(where: { $0.number == mutation.holeNumber }) else {
            throw ValidationError.invalidHole
        }
        guard let subject = projection.subjects.first(where: { subject in
            subject.anchorParticipantID == mutation.anchorParticipantID
                && subject.unit(for: mutation.holeNumber)?.scoringUnitID == mutation.scoringUnitID
        }),
        let unit = subject.unit(for: mutation.holeNumber),
        Set(unit.participantIDs) == Set(mutation.participantIDs),
        let anchor = snapshot.participants.first(where: { $0.id == mutation.anchorParticipantID }),
        anchor.groupID == viewer.groupID else {
            throw ValidationError.invalidSubject
        }

        let canonical = projection.score(
            for: unit.scoringUnitID,
            holeNumber: mutation.holeNumber
        )
        guard canonical?.revision == mutation.observedScoreRevision else {
            throw ValidationError.staleScore(
                canonicalValue: canonical?.value,
                canonicalRevision: canonical?.revision
            )
        }
        switch mutation.operation {
        case .set(let value):
            let isValid = projection.inputMode == .strokes
                ? (1...20).contains(value)
                : (-4...16).contains(value)
            guard isValid else { throw ValidationError.invalidScore }
        case .clear:
            break
        }

        let existingEntry = snapshot.scoring.first {
            $0.holeNumber == mutation.holeNumber && $0.scoringUnitID == mutation.scoringUnitID
        } ?? snapshot.scoring.first {
            $0.holeNumber == mutation.holeNumber
                && !Set($0.participantIDs).isDisjoint(with: mutation.participantIDs)
        }
        return ValidatedCommand(
            mutation: mutation,
            anchorParticipant: anchor,
            unit: unit,
            existingEntry: existingEntry
        )
    }
}
