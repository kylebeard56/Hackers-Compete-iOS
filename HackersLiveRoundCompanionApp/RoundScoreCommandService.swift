import Foundation

@MainActor
struct RoundScoreCommandService: Loggable {
    private let validator = RoundScoreCommandValidator()
    private let planner = RoundScoreCommandPlanner()

    func execute(
        _ mutation: WatchScoreMutation,
        in roundSession: RoundSession,
        participantID: String
    ) async -> WatchScoreAcknowledgement {
        let snapshot = roundSession.snapshot
        let validated: RoundScoreCommandValidator.ValidatedCommand
        do {
            validated = try validator.validate(
                mutation,
                snapshot: snapshot,
                participantID: participantID
            )
        } catch let error as RoundScoreCommandValidator.ValidationError {
            return rejection(for: mutation, error: error)
        } catch {
            return acknowledgement(
                for: mutation,
                status: .rejected,
                errorCategory: .invalidSubject,
                message: "This score is no longer editable."
            )
        }

        let plan = planner.plan(
            validated: validated,
            snapshot: snapshot,
            entryParticipantID: participantID
        )
        guard let targetEntry = plan.targetEntry else {
            return acknowledgement(for: mutation, status: .accepted)
        }

        var optimistic = roundSession.snapshot
        if let obsolete = plan.obsoleteEntry {
            optimistic.scoring.removeAll { $0.id == obsolete.id }
        }
        optimistic.scoring.upsert(targetEntry)
        roundSession.snapshot = optimistic

        do {
            let persisted = try await targetEntry.put().get()
            if persisted.hasRecordedScore {
                await roundSession.markFirstScoredIfNeeded(at: persisted.createdAt)
            }
            if let obsolete = plan.obsoleteEntry {
                _ = try? await obsolete.delete().get()
            }
            var canonical = roundSession.snapshot
            canonical.scoring.upsert(persisted)
            roundSession.snapshot = canonical
            emitTelemetry(plan: plan, snapshot: canonical, entry: persisted)
            let projection = try? RoundScoringSubjectBuilder().build(
                snapshot: canonical,
                participantID: participantID
            )
            let canonicalScore = projection?.score(
                for: mutation.scoringUnitID,
                holeNumber: mutation.holeNumber
            )
            return acknowledgement(
                for: mutation,
                status: .accepted,
                canonicalValue: canonicalScore?.value,
                canonicalRevision: canonicalScore?.revision
            )
        } catch {
            var rollback = roundSession.snapshot
            rollback.scoring.removeAll { $0.id == targetEntry.id }
            if let previous = plan.previousEntry {
                rollback.scoring.upsert(previous)
            }
            roundSession.snapshot = rollback
            addBreadcrumb(level: .error, message: "Apple Watch score command failed", error: error)
            return acknowledgement(
                for: mutation,
                status: .failed,
                errorCategory: .persistence,
                message: "The score could not be saved. Try again."
            )
        }
    }

    private func rejection(
        for mutation: WatchScoreMutation,
        error: RoundScoreCommandValidator.ValidationError
    ) -> WatchScoreAcknowledgement {
        if case .staleScore(let value, let revision) = error {
            return acknowledgement(
                for: mutation,
                status: .conflict,
                canonicalValue: value,
                canonicalRevision: revision,
                errorCategory: error.acknowledgementCategory,
                message: "Score changed on another device. Review it before saving again."
            )
        }
        let message: String
        switch error {
        case .roundUnavailable: message = "This round is no longer available."
        case .roundNotLive: message = "Scoring is not available while this round is paused or finished."
        case .unauthorized: message = "You no longer have permission to score this tee group."
        case .invalidHole: message = "This hole is not part of the round."
        case .invalidScore: message = "Choose a valid score."
        case .incompatibleSchema, .invalidSubject: message = "Refresh the Watch round before scoring."
        case .staleScore: message = "Score changed on another device."
        }
        return acknowledgement(
            for: mutation,
            status: .rejected,
            errorCategory: error.acknowledgementCategory,
            message: message
        )
    }

    private func acknowledgement(
        for mutation: WatchScoreMutation,
        status: WatchScoreAcknowledgement.Status,
        canonicalValue: Int? = nil,
        canonicalRevision: String? = nil,
        errorCategory: WatchScoreAcknowledgement.ErrorCategory? = nil,
        message: String? = nil
    ) -> WatchScoreAcknowledgement {
        WatchScoreAcknowledgement(
            id: mutation.id,
            roundID: mutation.roundID,
            status: status,
            canonicalValue: canonicalValue,
            canonicalRevision: canonicalRevision,
            errorCategory: errorCategory,
            message: message,
            acknowledgedAt: Date()
        )
    }

    private func emitTelemetry(
        plan: RoundScoreCommandPlanner.Plan,
        snapshot: RoundSnapshot,
        entry: ScoreEntry
    ) {
        let holeNumbers = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: snapshot.holeRange)
        let completed = holeNumbers.filter { holeNumber in
            snapshot.scoring.contains {
                $0.holeNumber == holeNumber
                    && ($0.scoringUnitID == plan.mutation.scoringUnitID
                        || $0.participantIDs.contains(plan.anchorParticipant.id))
                    && $0.hasRecordedScore
            }
        }.count
        let eventName = entry.hasRecordedScore
            ? "live_round.score_saved"
            : "live_round.score_cleared"
        addEvent(
            eventName,
            eventProps: TelemetryEventProps.scoring(
                snapshot: snapshot,
                participant: plan.anchorParticipant,
                entryParticipantID: entry.entryID,
                holeNumber: plan.mutation.holeNumber,
                strokes: entry.strokes,
                entryMethod: .appleWatch,
                scoreEntryMode: entry.resolvedEntryMode,
                friendlyRelativeToPar: entry.relativeToPar,
                participantHolesScoredCount: completed,
                totalHoles: holeNumbers.count,
                participantCompletionPct: TelemetryEventProps.completionPercentage(
                    completedCount: completed,
                    totalCount: holeNumbers.count
                )
            )
        )
    }
}
