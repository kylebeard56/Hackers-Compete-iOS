import Foundation

enum RoundScoringSubjectBuilderError: Error, Equatable {
    case roundNotAvailable
    case participantNotAvailable
    case teeGroupNotAvailable
    case noEditableSubjects
}

struct RoundScoringSubjectBuilder {
    func build(
        snapshot: RoundSnapshot,
        participantID: String,
        competitions: [WatchRoundSnapshot.Competition] = [],
        nameDisplayFormat: NameDisplayFormat = .firstNameLastInitial,
        acknowledgedMutationIDs: Set<UUID> = [],
        generatedAt: Date = Date()
    ) throws -> WatchRoundSnapshot {
        guard snapshot.round.id.isPopulated else {
            throw RoundScoringSubjectBuilderError.roundNotAvailable
        }
        guard snapshot.round.status == .live || snapshot.round.status == .paused,
              let viewer = snapshot.participants.first(where: { $0.id == participantID }),
              isActive(viewer, in: snapshot) else {
            throw RoundScoringSubjectBuilderError.participantNotAvailable
        }
        guard let teeGroupID = viewer.groupID, teeGroupID.isPopulated else {
            throw RoundScoringSubjectBuilderError.teeGroupNotAvailable
        }

        let playOrder = LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: snapshot.holeRange,
            teeGroupID: teeGroupID,
            teeGroups: snapshot.teeGroups
        )
        let groupParticipants = snapshot.participants
            .filter { $0.groupID == teeGroupID && isActive($0, in: snapshot) }
            .sorted { lhs, rhs in
                if lhs.id == viewer.id { return true }
                if rhs.id == viewer.id { return false }
                return participantOrder(lhs, rhs)
            }
        let subjects = snapshot.isSharedScoreSource
            ? sharedSubjects(
                snapshot: snapshot,
                groupParticipants: groupParticipants,
                teeGroupID: teeGroupID,
                playOrder: playOrder
            )
            : individualSubjects(
                snapshot: snapshot,
                groupParticipants: groupParticipants,
                viewerID: viewer.id,
                teeGroupID: teeGroupID,
                playOrder: playOrder,
                nameDisplayFormat: nameDisplayFormat
            )

        guard subjects.isPopulated else {
            throw RoundScoringSubjectBuilderError.noEditableSubjects
        }

        let holes = playOrder.map { holeNumber in
            let par = par(for: holeNumber, viewer: viewer, snapshot: snapshot)
            let limits = inputLimits(par: par, snapshot: snapshot)
            return WatchRoundSnapshot.Hole(
                number: holeNumber,
                par: par,
                inputMinimum: limits.lowerBound,
                inputMaximum: limits.upperBound
            )
        }
        let scores = subjects.flatMap { subject in
            subject.holeUnits.compactMap { unit -> WatchRoundSnapshot.Score? in
                guard let entry = scoreEntry(
                    for: unit,
                    holeNumber: unit.holeNumber,
                    snapshot: snapshot
                ) else {
                    return WatchRoundSnapshot.Score(
                        holeNumber: unit.holeNumber,
                        scoringUnitID: unit.scoringUnitID,
                        value: nil,
                        revision: nil
                    )
                }
                return WatchRoundSnapshot.Score(
                    holeNumber: unit.holeNumber,
                    scoringUnitID: unit.scoringUnitID,
                    value: inputValue(
                        from: entry,
                        holeNumber: unit.holeNumber,
                        viewer: viewer,
                        snapshot: snapshot
                    ),
                    revision: revision(for: entry)
                )
            }
        }
        let selectedHole = playOrder.first { holeNumber in
            subjects.contains { subject in
                guard let unit = subject.unit(for: holeNumber) else { return false }
                return scores.first {
                    $0.holeNumber == holeNumber && $0.scoringUnitID == unit.scoringUnitID
                }?.value == nil
            }
        } ?? playOrder.last ?? 1

        return WatchRoundSnapshot(
            revision: projectionRevision(snapshot),
            roundID: snapshot.round.id,
            title: snapshot.round.displayTitle(courseName: snapshot.courseInfo?.name),
            phase: snapshot.round.status == .paused ? .paused : .live,
            inputMode: snapshot.configuration.scoreInputMode == .friendlyRelativeToPar
                ? .relativeToPar
                : .strokes,
            selectedHole: selectedHole,
            holes: holes,
            subjects: subjects,
            scores: scores,
            competition: competitions.first,
            additionalCompetitions: Array(competitions.dropFirst()),
            acknowledgedMutationIDs: acknowledgedMutationIDs,
            generatedAt: generatedAt
        )
    }

    private func individualSubjects(
        snapshot: RoundSnapshot,
        groupParticipants: [RoundParticipant],
        viewerID: String,
        teeGroupID: String,
        playOrder: [Int],
        nameDisplayFormat: NameDisplayFormat
    ) -> [WatchRoundSnapshot.Subject] {
        groupParticipants.map { participant in
            let holeUnits = playOrder.map { holeNumber in
                let scoringUnit = snapshot.scoringUnits(forHole: holeNumber).first {
                    $0.id == participant.id || $0.ownerIDs.contains(participant.id)
                }
                return WatchRoundSnapshot.Subject.HoleUnit(
                    holeNumber: holeNumber,
                    scoringUnitID: scoringUnit?.id ?? participant.id,
                    participantIDs: resolvedParticipantIDs(
                        for: scoringUnit,
                        fallback: [participant.id],
                        snapshot: snapshot
                    ),
                    strokesReceived: strokesReceived(
                        by: participant,
                        on: holeNumber,
                        snapshot: snapshot
                    )
                )
            }
            return WatchRoundSnapshot.Subject(
                id: participant.id,
                title: participant.name.displayNameWithPlaceholder,
                compactTitle: nameDisplayFormat.displayName(for: participant.name),
                subtitle: participant.id == viewerID ? "You" : "Tee group",
                anchorParticipantID: participant.id,
                teeGroupID: teeGroupID,
                holeUnits: holeUnits
            )
        }
    }

    private func sharedSubjects(
        snapshot: RoundSnapshot,
        groupParticipants: [RoundParticipant],
        teeGroupID: String,
        playOrder: [Int]
    ) -> [WatchRoundSnapshot.Subject] {
        let groupParticipantIDs = Set(groupParticipants.map(\.id))
        var candidatesByIdentity: [String: SharedCandidate] = [:]

        for holeNumber in playOrder {
            for scoringUnit in snapshot.scoringUnits(forHole: holeNumber) {
                let participantIDs = resolvedParticipantIDs(
                    for: scoringUnit,
                    fallback: scoringUnit.ownerIDs,
                    snapshot: snapshot
                )
                guard !groupParticipantIDs.isDisjoint(with: participantIDs) else { continue }
                let identity = participantIDs.sorted().joined(separator: "|")
                guard identity.isPopulated else { continue }
                var candidate = candidatesByIdentity[identity]
                    ?? makeSharedCandidate(
                        identity: identity,
                        scoringUnit: scoringUnit,
                        participantIDs: participantIDs,
                        groupParticipants: groupParticipants,
                        teeGroupID: teeGroupID,
                        snapshot: snapshot
                    )
                candidate.holeUnits.append(
                    .init(
                        holeNumber: holeNumber,
                        scoringUnitID: scoringUnit.id,
                        participantIDs: participantIDs
                    )
                )
                candidatesByIdentity[identity] = candidate
            }
        }

        if candidatesByIdentity.isEmpty {
            for candidate in fallbackSharedCandidates(
                snapshot: snapshot,
                groupParticipants: groupParticipants,
                teeGroupID: teeGroupID,
                playOrder: playOrder
            ) {
                candidatesByIdentity[candidate.identity] = candidate
            }
        }

        return candidatesByIdentity.values
            .sorted { lhs, rhs in
                let lhsOrder = groupParticipants.firstIndex { lhs.participantIDs.contains($0.id) } ?? Int.max
                let rhsOrder = groupParticipants.firstIndex { rhs.participantIDs.contains($0.id) } ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .map { candidate in
                WatchRoundSnapshot.Subject(
                    id: candidate.identity,
                    title: candidate.title,
                    subtitle: candidate.subtitle,
                    anchorParticipantID: candidate.anchorParticipantID,
                    teeGroupID: teeGroupID,
                    holeUnits: candidate.holeUnits.sorted { $0.holeNumber < $1.holeNumber }
                )
            }
    }

    private func makeSharedCandidate(
        identity: String,
        scoringUnit: ScoringUnit,
        participantIDs: [String],
        groupParticipants: [RoundParticipant],
        teeGroupID: String,
        snapshot: RoundSnapshot
    ) -> SharedCandidate {
        let members = snapshot.participants
            .filter { participantIDs.contains($0.id) }
            .sorted(by: participantOrder)
        let anchor = groupParticipants.first { participantIDs.contains($0.id) }
            ?? members.first
            ?? groupParticipants[0]
        let title: String
        switch scoringUnit.owner {
        case .team:
            let teamID = scoringUnit.ownerIDs.first ?? scoringUnit.id
            title = snapshot.teams.first(where: { $0.id == teamID })?.name ?? "Team Score"
        case .scoreOwner:
            title = snapshot.scoringGroup(id: scoringUnit.id)?.label
                ?? (members.count == 2 ? "Partnership" : "Group Score")
        case .participant:
            title = members.first?.name.displayNameWithPlaceholder ?? "Score"
        }
        let subtitle = members
            .map { $0.name.teeGroupDisplayName }
            .filter(\.isPopulated)
            .joined(separator: ", ")
        return SharedCandidate(
            identity: identity,
            title: title,
            subtitle: subtitle.isPopulated ? subtitle : nil,
            anchorParticipantID: anchor.id,
            participantIDs: participantIDs,
            holeUnits: []
        )
    }

    private func fallbackSharedCandidates(
        snapshot: RoundSnapshot,
        groupParticipants: [RoundParticipant],
        teeGroupID: String,
        playOrder: [Int]
    ) -> [SharedCandidate] {
        let groupIDs = Set(groupParticipants.map(\.id))
        let persistedGroups = snapshot.scoringGroups.filter {
            !$0.memberIDs.isEmpty && !groupIDs.isDisjoint(with: $0.memberIDs)
        }
        if persistedGroups.isPopulated {
            return persistedGroups.map { group in
                let members = group.memberIDs
                let identity = members.sorted().joined(separator: "|")
                let title = group.label ?? (group.kind == .partnership ? "Partnership" : "Group Score")
                let subtitle = snapshot.participants
                    .filter { members.contains($0.id) }
                    .sorted(by: participantOrder)
                    .map { $0.name.teeGroupDisplayName }
                    .joined(separator: ", ")
                let unitID = canonicalScoringUnitID(
                    participantIDs: members,
                    fallback: group.id,
                    snapshot: snapshot
                )
                return SharedCandidate(
                    identity: identity,
                    title: title,
                    subtitle: subtitle,
                    anchorParticipantID: groupParticipants.first { members.contains($0.id) }?.id
                        ?? groupParticipants[0].id,
                    participantIDs: members,
                    holeUnits: playOrder.map {
                        .init(holeNumber: $0, scoringUnitID: unitID, participantIDs: members)
                    }
                )
            }
        }

        let groupedByTeam = Dictionary(grouping: groupParticipants, by: \.teamID)
        let teamCandidates = groupedByTeam.compactMap { teamID, members -> SharedCandidate? in
            guard let teamID, teamID.isPopulated else { return nil }
            let allTeamIDs = snapshot.participants.filter { $0.teamID == teamID }.map(\.id)
            let identity = allTeamIDs.sorted().joined(separator: "|")
            let title = snapshot.teams.first(where: { $0.id == teamID })?.name ?? "Team Score"
            let unitID = canonicalScoringUnitID(
                participantIDs: allTeamIDs,
                fallback: teamID,
                snapshot: snapshot
            )
            return SharedCandidate(
                identity: identity,
                title: title,
                subtitle: members.map { $0.name.teeGroupDisplayName }.joined(separator: ", "),
                anchorParticipantID: members[0].id,
                participantIDs: allTeamIDs,
                holeUnits: playOrder.map {
                    .init(holeNumber: $0, scoringUnitID: unitID, participantIDs: allTeamIDs)
                }
            )
        }
        if teamCandidates.isPopulated { return teamCandidates }

        let participantIDs = groupParticipants.map(\.id)
        return [
            SharedCandidate(
                identity: participantIDs.sorted().joined(separator: "|"),
                title: "Group Score",
                subtitle: groupParticipants.map { $0.name.teeGroupDisplayName }.joined(separator: ", "),
                anchorParticipantID: groupParticipants[0].id,
                participantIDs: participantIDs,
                holeUnits: playOrder.map {
                    .init(holeNumber: $0, scoringUnitID: teeGroupID, participantIDs: participantIDs)
                }
            )
        ]
    }

    private func resolvedParticipantIDs(
        for scoringUnit: ScoringUnit?,
        fallback: [String],
        snapshot: RoundSnapshot
    ) -> [String] {
        guard let scoringUnit else { return fallback.filter(\.isPopulated) }
        switch scoringUnit.owner {
        case .participant:
            return (scoringUnit.ownerIDs.isPopulated ? scoringUnit.ownerIDs : [scoringUnit.id])
                .filter(\.isPopulated)
        case .team:
            guard let teamID = scoringUnit.ownerIDs.first else { return fallback }
            return snapshot.participants.filter { $0.teamID == teamID }.map(\.id)
        case .scoreOwner:
            return snapshot.scoringGroup(id: scoringUnit.id)?.memberIDs
                ?? scoringUnit.ownerIDs.filter(\.isPopulated)
        }
    }

    private func canonicalScoringUnitID(
        participantIDs: [String],
        fallback: String,
        snapshot: RoundSnapshot
    ) -> String {
        let expected = Set(participantIDs)
        return snapshot.segments
            .flatMap(\.scoringUnits)
            .first { Set(resolvedParticipantIDs(for: $0, fallback: [], snapshot: snapshot)) == expected }?
            .id ?? fallback
    }

    private func scoreEntry(
        for unit: WatchRoundSnapshot.Subject.HoleUnit,
        holeNumber: Int,
        snapshot: RoundSnapshot
    ) -> ScoreEntry? {
        snapshot.scoring.first {
            $0.holeNumber == holeNumber && $0.scoringUnitID == unit.scoringUnitID
        } ?? snapshot.scoring.first {
            $0.holeNumber == holeNumber
                && !Set($0.participantIDs).isDisjoint(with: unit.participantIDs)
        }
    }

    private func inputValue(
        from entry: ScoreEntry,
        holeNumber: Int,
        viewer: RoundParticipant,
        snapshot: RoundSnapshot
    ) -> Int? {
        let holePar = par(for: holeNumber, viewer: viewer, snapshot: snapshot)
        if snapshot.configuration.scoreInputMode == .friendlyRelativeToPar {
            return entry.relativeToPar ?? entry.strokes.map { $0 - holePar }
        }
        return entry.strokes ?? entry.relativeToPar.map { max(1, holePar + $0) }
    }

    private func par(
        for holeNumber: Int,
        viewer: RoundParticipant,
        snapshot: RoundSnapshot
    ) -> Int {
        let playedTee = snapshot.tees.first { $0.id == viewer.teeBoxID }
        return playedTee?.holes.first { $0.number == holeNumber }?.par
            ?? snapshot.defaultTee?.holes.first { $0.number == holeNumber }?.par
            ?? 4
    }

    private func inputLimits(par: Int, snapshot: RoundSnapshot) -> ClosedRange<Int> {
        let maximumRule = snapshot.gameFormat.configuration.maxScoreOverPar
        if snapshot.configuration.scoreInputMode == .friendlyRelativeToPar {
            return -4...maximumRule.friendlyMaxRelativeValue(for: par)
        }
        let minimum = par == 4 ? 1 : max(1, par - 2)
        return minimum...maximumRule.maxScore(for: par)
    }

    private func strokesReceived(
        by participant: RoundParticipant,
        on holeNumber: Int,
        snapshot: RoundSnapshot
    ) -> Int? {
        guard snapshot.configuration.useHandicaps else { return nil }
        return ScoringEngine.strokesReceived(
            handicap: participant.lockedHandicapAllowance,
            holeNumber: holeNumber,
            holes: snapshot.defaultTee?.holes ?? [],
            playedHoleNumbers: snapshot.holeRange?.holeNumbers ?? Array(1...18),
            useHandicaps: true,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
    }

    private func revision(for entry: ScoreEntry) -> String {
        "\(entry.id):\(entry.lastUpdatedAt.unix)"
    }

    private func projectionRevision(_ snapshot: RoundSnapshot) -> Int64 {
        let timestamps = [snapshot.round.lastUpdatedAt.unix]
            + snapshot.participants.map(\.lastUpdatedAt.unix)
            + snapshot.teeGroups.map(\.lastUpdatedAt.unix)
            + snapshot.scoringGroups.map(\.lastUpdatedAt.unix)
            + snapshot.segments.map(\.lastUpdatedAt.unix)
            + snapshot.scoring.map(\.lastUpdatedAt.unix)
        return Int64((timestamps.max() ?? 0) * 1_000) &+ Int64(snapshot.scoring.count)
    }

    private func isActive(_ participant: RoundParticipant, in snapshot: RoundSnapshot) -> Bool {
        snapshot.configuration.attendanceConfirmationEnabled != true
            || participant.resolvedPresenceStatus != .noShow
    }

    private func participantOrder(_ lhs: RoundParticipant, _ rhs: RoundParticipant) -> Bool {
        if (lhs.teeOrder ?? Int.max) != (rhs.teeOrder ?? Int.max) {
            return (lhs.teeOrder ?? Int.max) < (rhs.teeOrder ?? Int.max)
        }
        return lhs.name.fullName.localizedStandardCompare(rhs.name.fullName) == .orderedAscending
    }
}

private struct SharedCandidate {
    let identity: String
    let title: String
    let subtitle: String?
    let anchorParticipantID: String
    let participantIDs: [String]
    var holeUnits: [WatchRoundSnapshot.Subject.HoleUnit]
}
