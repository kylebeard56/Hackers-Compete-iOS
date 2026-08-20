import Foundation

struct RoundScoreCommandPlanner {
    struct Plan {
        let mutation: WatchScoreMutation
        let anchorParticipant: RoundParticipant
        let previousEntry: ScoreEntry?
        let targetEntry: ScoreEntry?
        let obsoleteEntry: ScoreEntry?
    }

    func plan(
        validated: RoundScoreCommandValidator.ValidatedCommand,
        snapshot: RoundSnapshot,
        entryParticipantID: String,
        now: Time = .init()
    ) -> Plan {
        let mutation = validated.mutation
        guard case .set(let value) = mutation.operation else {
            guard var entry = validated.existingEntry else {
                return Plan(
                    mutation: mutation,
                    anchorParticipant: validated.anchorParticipant,
                    previousEntry: nil,
                    targetEntry: nil,
                    obsoleteEntry: nil
                )
            }
            entry.entryID = entryParticipantID
            entry.strokes = nil
            entry.relativeToPar = nil
            entry.entryMode = nil
            entry.value = nil
            entry.pickedUp = false
            entry.lastUpdatedAt = now
            return Plan(
                mutation: mutation,
                anchorParticipant: validated.anchorParticipant,
                previousEntry: validated.existingEntry,
                targetEntry: entry,
                obsoleteEntry: nil
            )
        }

        let segmentID = snapshot.segment(forHole: mutation.holeNumber)?.id
            ?? snapshot.roundSegment?.id
            ?? "seg0"
        let entryID = ScoreEntry.makeID(
            hole: mutation.holeNumber,
            segment: segmentID,
            scoringUnit: mutation.scoringUnitID
        )
        var entry = validated.existingEntry ?? ScoreEntry(
            id: entryID,
            holeNumber: mutation.holeNumber,
            segmentID: segmentID,
            groupID: validated.anchorParticipant.groupID ?? "",
            scoringUnitID: mutation.scoringUnitID,
            participantIDs: mutation.participantIDs,
            entryID: entryParticipantID,
            createdAt: now,
            lastUpdatedAt: now,
            parentID: mutation.roundID
        )
        let obsoleteEntry = entry.id == entryID ? nil : entry
        entry.id = entryID
        entry.holeNumber = mutation.holeNumber
        entry.segmentID = segmentID
        entry.groupID = validated.anchorParticipant.groupID ?? entry.groupID
        entry.scoringUnitID = mutation.scoringUnitID
        entry.participantIDs = mutation.participantIDs
        entry.entryID = entryParticipantID
        entry.parentID = mutation.roundID
        entry.pickedUp = false
        entry.value = nil
        entry.lastUpdatedAt = now

        if snapshot.configuration.scoreInputMode == .friendlyRelativeToPar {
            entry.strokes = nil
            entry.relativeToPar = value
            entry.entryMode = .relativeToPar
        } else {
            entry.strokes = value
            entry.relativeToPar = nil
            entry.entryMode = .strokes
        }

        return Plan(
            mutation: mutation,
            anchorParticipant: validated.anchorParticipant,
            previousEntry: validated.existingEntry,
            targetEntry: entry,
            obsoleteEntry: obsoleteEntry
        )
    }
}
