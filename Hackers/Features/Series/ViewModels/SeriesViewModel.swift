//
//  SeriesViewModel.swift
//  Hackers
//

import SwiftUI

struct SeriesScoreCorrectionChange: Identifiable, Hashable {
    let participantID: String
    let holeNumber: Int
    let strokes: Int?

    var id: String { "\(participantID)_\(holeNumber)" }
}

struct SeriesRoundCorrectionContext {
    let seriesRound: SeriesRound
    let snapshot: RoundSnapshot
    let holes: [Hole]
    let entriesByParticipantID: [String: [Int: ScoreEntry]]
}

struct SeriesRoundCSVDocument: Equatable {
    var header: String
    var rows: [String]

    var content: String {
        ([header] + rows).joined(separator: "\n")
    }
}

enum SeriesRoundCSVExporter {
    static func document(seriesRound: SeriesRound, snapshot: RoundSnapshot, members: [SeriesMember]) -> SeriesRoundCSVDocument {
        let holeNumbers = snapshot.holeRange?.holeNumbers ?? snapshot.holeSegment.holeRange.holeNumbers
        let usesHandicaps = snapshot.configuration.useHandicaps
        let header = csvHeader(holeNumbers: holeNumbers, includesHandicap: usesHandicaps)
        let rows = csvRows(
            seriesRound: seriesRound,
            snapshot: snapshot,
            members: members,
            holeNumbers: holeNumbers,
            includesHandicap: usesHandicaps
        )
        return .init(header: header, rows: rows)
    }

    private struct ParticipantCSVContext {
        var matchupIndex: Int?
        var matchupID: String
        var matchupSide: String
        var matchupSideID: String
        var teeGroupIndex: Int?
        var teeGroupID: String
        var teeGroupName: String
        var teeTime: String
        var startingHole: Int?
        var teamName: String
    }

    private static func csvRows(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        members: [SeriesMember],
        holeNumbers: [Int],
        includesHandicap: Bool
    ) -> [String] {
        let scoreEntriesByParticipant = Dictionary(grouping: snapshot.scoring, by: \.scoringUnitID)
        let teamsByID = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
        let groupsByID = Dictionary(uniqueKeysWithValues: snapshot.teeGroups.map { ($0.id, $0) })
        let contexts = participantContexts(snapshot: snapshot, teamsByID: teamsByID, groupsByID: groupsByID)

        return snapshot.participants.sorted { lhs, rhs in
            let lc = contexts[lhs.id]
            let rc = contexts[rhs.id]
            if (lc?.matchupIndex ?? Int.max) != (rc?.matchupIndex ?? Int.max) {
                return (lc?.matchupIndex ?? Int.max) < (rc?.matchupIndex ?? Int.max)
            }
            if (lc?.teeGroupIndex ?? Int.max) != (rc?.teeGroupIndex ?? Int.max) {
                return (lc?.teeGroupIndex ?? Int.max) < (rc?.teeGroupIndex ?? Int.max)
            }
            if (lhs.teeOrder ?? Int.max) != (rhs.teeOrder ?? Int.max) {
                return (lhs.teeOrder ?? Int.max) < (rhs.teeOrder ?? Int.max)
            }
            return lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName) == .orderedAscending
        }.map { participant in
            let context = contexts[participant.id] ?? ParticipantCSVContext(
                matchupIndex: nil,
                matchupID: "",
                matchupSide: "",
                matchupSideID: "",
                teeGroupIndex: nil,
                teeGroupID: participant.groupID ?? "",
                teeGroupName: participant.groupID.flatMap { groupsByID[$0]?.name } ?? "",
                teeTime: participant.groupID.flatMap { groupsByID[$0]?.teeTime } ?? "",
                startingHole: participant.groupID.flatMap { groupsByID[$0]?.startingHole },
                teamName: participant.teamID.flatMap { teamsByID[$0]?.name } ?? ""
            )
            let entriesByHole = Dictionary(uniqueKeysWithValues: (scoreEntriesByParticipant[participant.id] ?? []).map { ($0.holeNumber, $0) })
            let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID)
                ?? snapshot.courseSegment?.tee(from: snapshot.courseSegment?.defaultTee ?? "")
                ?? snapshot.courseSegment?.courseInfo.tees.first
            var totalToPar = 0
            var holeValues: [String] = []

            for holeNumber in holeNumbers {
                if let strokes = entriesByHole[holeNumber]?.strokes {
                    let par = tee?.holes.first(where: { $0.number == holeNumber })?.par ?? 4
                    let toPar = strokes - par
                    totalToPar += toPar
                    holeValues.append(String(toPar))
                } else {
                    holeValues.append("")
                }
            }

            let memberID = participant.seriesMemberID ?? members.first(where: { $0.playerID == participant.playerID })?.id ?? ""
            var columns = [
                seriesRound.id,
                snapshot.round.id,
                memberID,
                participant.playerID ?? "",
                participant.name.fullName,
                participant.teamID ?? "",
                context.teamName,
                context.matchupIndex.map { String($0 + 1) } ?? "",
                context.matchupID,
                context.matchupSide,
                context.matchupSideID,
                context.teeGroupIndex.map { String($0 + 1) } ?? "",
                context.teeGroupID,
                context.teeGroupName,
                context.teeTime,
                context.startingHole.map(String.init) ?? ""
            ]
            if includesHandicap {
                columns.append(String(participant.adjustedHandicap))
            }
            columns += holeValues + [String(totalToPar)]
            return columns.map(escapedCSV).joined(separator: ",")
        }
    }

    private static func participantContexts(
        snapshot: RoundSnapshot,
        teamsByID: [String: RoundTeam],
        groupsByID: [String: TeeTimeGroup]
    ) -> [String: ParticipantCSVContext] {
        var contexts: [String: ParticipantCSVContext] = [:]
        let scoringGroupsByID = Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })
        let matchups = snapshot.roundSegment?.matchups ?? []

        for participant in snapshot.participants {
            let teeGroup = participant.groupID.flatMap { groupsByID[$0] }
            let matchupContext = matchups.enumerated().compactMap { index, matchup -> (Int, String, String, String)? in
                let sideIDs = matchup.pairingIDs()
                for (sideIndex, sideID) in sideIDs.enumerated() {
                    let contains: Bool
                    switch matchup.effectiveMode {
                    case .team:
                        contains = participant.teamID == sideID
                    case .individual:
                        contains = participant.id == sideID
                    case .partnership, .teeGroup, .scoreOwner:
                        contains = scoringGroupsByID[sideID]?.memberIDs.contains(participant.id) == true
                    }
                    if contains {
                        return (index, matchup.id, sideIndex == 0 ? "A" : "B", sideID)
                    }
                }
                return nil
            }.first

            contexts[participant.id] = ParticipantCSVContext(
                matchupIndex: matchupContext?.0,
                matchupID: matchupContext?.1 ?? "",
                matchupSide: matchupContext?.2 ?? "",
                matchupSideID: matchupContext?.3 ?? "",
                teeGroupIndex: teeGroup?.index,
                teeGroupID: teeGroup?.id ?? participant.groupID ?? "",
                teeGroupName: teeGroup?.name ?? "",
                teeTime: teeGroup?.teeTime ?? "",
                startingHole: teeGroup?.startingHole,
                teamName: participant.teamID.flatMap { teamsByID[$0]?.name } ?? ""
            )
        }
        return contexts
    }

    private static func csvHeader(holeNumbers: [Int], includesHandicap: Bool) -> String {
        var base = [
            "series_round_id",
            "round_id",
            "series_member_id",
            "player_id",
            "player_name",
            "team_id",
            "team_name",
            "matchup_index",
            "matchup_id",
            "matchup_side",
            "matchup_side_id",
            "tee_group_index",
            "tee_group_id",
            "tee_group_name",
            "tee_time",
            "starting_hole"
        ]
        if includesHandicap {
            base.append("handicap_strokes")
        }
        return (base + holeNumbers.map { "hole_\($0)_to_par" } + ["total_to_par"]).joined(separator: ",")
    }

    private static func escapedCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

struct SeriesRoundOutcomeNarrative: Equatable {
    let markdown: String

    var paragraph: String { markdown }

    init(markdown: String) {
        self.markdown = markdown
    }

    init(paragraph: String) {
        self.markdown = paragraph
    }
}

enum SeriesRoundOutcomeNarrativeBuilder {
    struct PriorRoundSnapshot {
        let seriesRound: SeriesRound
        let snapshot: RoundSnapshot
    }

    private struct PlayerResult {
        let participant: RoundParticipant
        let memberID: String?
        let name: String
        let grossStrokes: Int
        let grossToPar: Int
        let netStrokes: Int
        let netToPar: Int
        let handicapUsed: Int
        let currentHandicap: Double?
        let nextHandicap: Double?
        let teamName: String?
    }

    static func build(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        priorRoundSnapshots: [PriorRoundSnapshot],
        members: [SeriesMember],
        handicapScores _: [SeriesHandicapScore],
        memberHandicaps: [String: SeriesMemberHandicap],
        pointAwards: [SeriesPointAward] = [],
        standings: [SeriesStanding] = [],
        teams: [SeriesTeam] = []
    ) -> SeriesRoundOutcomeNarrative? {
        let results = playerResults(
            snapshot: snapshot,
            members: members,
            memberHandicaps: memberHandicaps,
            teams: teams
        )
        guard results.isPopulated else { return nil }

        let ordered = results.sorted {
            if $0.netStrokes != $1.netStrokes { return $0.netStrokes < $1.netStrokes }
            if $0.grossStrokes != $1.grossStrokes { return $0.grossStrokes < $1.grossStrokes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        let title = seriesRound.title.isPopulated ? seriesRound.title : "Round \(seriesRound.index + 1)"
        let placeLabels = placementLabels(for: ordered)
        let leaderboard = ordered.enumerated().map { offset, result in
            let teamSuffix = result.teamName.map { ", \($0)" } ?? ""
            return """
            **\(placeLabels[offset]) - \(markdownEscaped(result.name))\(teamSuffix)**
            Score: \(scoreToParLabel(result.netToPar)) (Net \(result.netStrokes) / Gross \(result.grossStrokes))
            \(handicapLine(
                participant: result.participant,
                currentHandicap: result.currentHandicap,
                currentCourseHandicap: result.handicapUsed,
                nextHandicap: result.nextHandicap,
                snapshot: snapshot
            ))
            """
        }.joined(separator: "\n\n")

        let scoreHighlights = birdieAndEagleHighlights(snapshot: snapshot)
        let scoreHighlightsText = scoreHighlights.isEmpty
            ? "No birdies or eagles were recorded."
            : scoreHighlights.joined(separator: "\n")
        let absentText = absentPlayerLines(
            snapshot: snapshot,
            members: members,
            memberHandicaps: memberHandicaps
        )
        let teamContext = teamContextParagraph(
            seriesRound: seriesRound,
            pointAwards: pointAwards,
            standings: standings,
            teams: teams
        )

        let best = ordered[0]
        var highlights = ["Best round: **\(markdownEscaped(best.name))** with net \(best.netStrokes) (\(scoreToParLabel(best.netToPar)))."]

        if let bounceBack = bounceBackResult(
            currentResults: results,
            priorRoundSnapshots: priorRoundSnapshots,
            members: members,
            memberHandicaps: memberHandicaps,
            teams: teams
        ) {
            highlights.append("Bounce-back player: **\(markdownEscaped(bounceBack.name))**, improving \(bounceBack.improvement) \(strokeUnit(bounceBack.improvement)) from the prior Series round.")
        }

        if let strongestFinish = strongestFinishResult(snapshot: snapshot) {
            let names = strongestFinish.names.map { "**\(markdownEscaped($0))**" }.joined(separator: ", ")
            highlights.append("Strongest finish: \(names) at \(scoreToParLabel(strongestFinish.netToPar)) over the final four holes.")
        }

        let teamContextBlock = teamContext.map { "\n\n**Team context**\n\($0)" } ?? ""
        let absentBlock = absentText.isEmpty ? "" : "\n\n**Absent players**\n\(absentText.joined(separator: "\n"))"

        return SeriesRoundOutcomeNarrative(
            markdown: """
            **\(markdownEscaped(title)) is scored.**

            **Leaderboard (low-to-high net)**
            \(leaderboard)

            **Birdies and Eagles**
            \(scoreHighlightsText)\(absentBlock)\(teamContextBlock)

            **Highlights**
            \(highlights.joined(separator: "\n"))
            """
        )
    }

    private static func playerResults(
        snapshot: RoundSnapshot,
        members: [SeriesMember],
        memberHandicaps: [String: SeriesMemberHandicap],
        teams: [SeriesTeam]
    ) -> [PlayerResult] {
        let teamsByID = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.name) })
        let roundTeamsByID = Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0.name) })
        return snapshot.participants
            .filter(\.isPresenceActive)
            .compactMap { participant -> PlayerResult? in
                guard let totals = totals(for: participant, snapshot: snapshot) else { return nil }
                let memberID = memberID(for: participant, members: members)
                let nextHandicap = memberID.flatMap { memberHandicaps[$0]?.effectiveIndex }
                let teamName = participant.teamID.flatMap { teamsByID[$0] ?? roundTeamsByID[$0] }
                return PlayerResult(
                    participant: participant,
                    memberID: memberID,
                    name: displayName(for: participant),
                    grossStrokes: totals.gross,
                    grossToPar: totals.grossToPar,
                    netStrokes: totals.gross - participant.adjustedHandicap,
                    netToPar: totals.grossToPar - participant.adjustedHandicap,
                    handicapUsed: participant.adjustedHandicap,
                    currentHandicap: participant.handicapIndex ?? participant.leagueHandicapStrokesAtCreation.map(Double.init),
                    nextHandicap: nextHandicap,
                    teamName: teamName
                )
            }
    }

    private static func totals(
        for participant: RoundParticipant,
        snapshot: RoundSnapshot
    ) -> (gross: Int, grossToPar: Int)? {
        let entriesByHole = Dictionary(
            grouping: snapshot.scoring.filter { $0.scoringUnitID == participant.id },
            by: \.holeNumber
        ).compactMapValues(\.first)
        guard entriesByHole.isPopulated else { return nil }

        let tee = playedTee(for: participant, snapshot: snapshot)
        var gross = 0
        var grossToPar = 0
        var hasScore = false

        for holeNumber in holeNumbers(for: snapshot) {
            guard let entry = entriesByHole[holeNumber],
                  let par = par(for: holeNumber, tee: tee),
                  let strokes = grossStrokes(from: entry, par: par) else {
                continue
            }
            hasScore = true
            gross += strokes
            grossToPar += strokes - par
        }

        return hasScore ? (gross, grossToPar) : nil
    }

    private static func birdieAndEagleHighlights(snapshot: RoundSnapshot) -> [String] {
        snapshot.participants
            .filter(\.isPresenceActive)
            .flatMap { participant -> [String] in
                let tee = playedTee(for: participant, snapshot: snapshot)
                let entries = snapshot.scoring.filter { $0.scoringUnitID == participant.id }
                let entriesByHole = Dictionary(grouping: entries, by: \.holeNumber).compactMapValues(\.first)
                let highlights = holeNumbers(for: snapshot).compactMap { holeNumber -> (hole: Int, label: String)? in
                    guard let entry = entriesByHole[holeNumber],
                          let par = par(for: holeNumber, tee: tee),
                          let strokes = grossStrokes(from: entry, par: par) else {
                        return nil
                    }
                    let diff = strokes - par
                    if diff <= -2 { return (holeNumber, "eagle") }
                    if diff == -1 { return (holeNumber, "birdie") }
                    return nil
                }
                guard highlights.isPopulated else { return [] }
                let name = displayName(for: participant)
                let eagleHoles = highlights.filter { $0.label == "eagle" }.map { "#\($0.hole)" }
                let birdieHoles = highlights.filter { $0.label == "birdie" }.map { "#\($0.hole)" }
                var lines: [String] = []
                if eagleHoles.isPopulated {
                    lines.append("**\(markdownEscaped(name))** eagle-or-better on \(eagleHoles.joined(separator: ", "))")
                }
                if birdieHoles.isPopulated {
                    lines.append("**\(markdownEscaped(name))** birdie on \(birdieHoles.joined(separator: ", "))")
                }
                return lines
            }
            .sorted()
    }

    private static func bounceBackResult(
        currentResults: [PlayerResult],
        priorRoundSnapshots: [PriorRoundSnapshot],
        members: [SeriesMember],
        memberHandicaps: [String: SeriesMemberHandicap],
        teams: [SeriesTeam]
    ) -> (name: String, improvement: Int)? {
        let priorByMemberID = priorRoundSnapshots
            .sorted { $0.seriesRound.index > $1.seriesRound.index }
            .reduce(into: [String: PlayerResult]()) { result, prior in
                for playerResult in playerResults(
                    snapshot: prior.snapshot,
                    members: members,
                    memberHandicaps: memberHandicaps,
                    teams: teams
                ) {
                    guard let memberID = playerResult.memberID,
                          result[memberID] == nil else { continue }
                    result[memberID] = playerResult
                }
            }

        return currentResults
            .compactMap { current -> (name: String, improvement: Int, netToPar: Int)? in
                guard let memberID = current.memberID,
                      let prior = priorByMemberID[memberID] else { return nil }
                let improvement = prior.netToPar - current.netToPar
                guard improvement > 0 else { return nil }
                return (current.name, improvement, current.netToPar)
            }
            .sorted {
                if $0.improvement != $1.improvement { return $0.improvement > $1.improvement }
                if $0.netToPar != $1.netToPar { return $0.netToPar < $1.netToPar }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .first
            .map { ($0.name, $0.improvement) }
    }

    private static func memberID(for participant: RoundParticipant, members: [SeriesMember]) -> String? {
        if let memberID = participant.seriesMemberID, memberID.isPopulated {
            return memberID
        }
        guard let playerID = participant.playerID else { return nil }
        return members.first { $0.playerID == playerID }?.id
    }

    private static func playedTee(for participant: RoundParticipant, snapshot: RoundSnapshot) -> Tee? {
        if participant.teeBoxID.isPopulated,
           let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID) ?? snapshot.tees.first(where: { $0.id == participant.teeBoxID }) {
            return tee
        }
        return snapshot.defaultTee ?? snapshot.tees.first
    }

    private static func holeNumbers(for snapshot: RoundSnapshot) -> [Int] {
        snapshot.holeRange?.holeNumbers ?? snapshot.holeSegment.holeRange.holeNumbers
    }

    private static func par(for holeNumber: Int, tee: Tee?) -> Int? {
        tee?.holes.first { $0.number == holeNumber }?.par
    }

    private static func grossStrokes(from entry: ScoreEntry, par: Int) -> Int? {
        if let strokes = entry.strokes { return strokes }
        if let relative = entry.relativeToPar { return par + relative }
        return nil
    }

    private static func displayName(for participant: RoundParticipant) -> String {
        let fullName = participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isPopulated ? fullName : "Player"
    }

    private static func scoreToParLabel(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private static func handicapLabel(_ value: Double?) -> String {
        guard let value else { return "unavailable" }
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded(.towardZero)) < 0.000_001 {
            return "\(Int(rounded.rounded(.towardZero)))"
        }
        return String(format: "%.1f", rounded)
    }

    private static func placementLabels(for ordered: [PlayerResult]) -> [String] {
        var labels = Array(repeating: "", count: ordered.count)
        var index = 0
        var place = 1

        while index < ordered.count {
            let net = ordered[index].netStrokes
            let start = index
            while index < ordered.count, ordered[index].netStrokes == net {
                index += 1
            }
            let tied = index - start > 1
            let label = "\(tied ? "T-" : "")\(ordinal(place))"
            for i in start..<index {
                labels[i] = label
            }
            place += index - start
        }

        return labels
    }

    private static func ordinal(_ value: Int) -> String {
        let ones = value % 10
        let tens = (value / 10) % 10
        let suffix: String
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(value)\(suffix)"
    }

    private static func absentPlayerLines(
        snapshot: RoundSnapshot,
        members: [SeriesMember],
        memberHandicaps: [String: SeriesMemberHandicap]
    ) -> [String] {
        snapshot.participants
            .filter { !$0.isPresenceActive }
            .sorted { displayName(for: $0) < displayName(for: $1) }
            .map { participant in
                let memberID = memberID(for: participant, members: members)
                let next = memberID.flatMap { memberHandicaps[$0]?.effectiveIndex }
                let current = participant.handicapIndex ?? participant.leagueHandicapStrokesAtCreation.map(Double.init) ?? Double(participant.adjustedHandicap)
                let line = handicapLine(
                    participant: participant,
                    currentHandicap: current,
                    currentCourseHandicap: participant.adjustedHandicap,
                    nextHandicap: next,
                    snapshot: snapshot
                )
                return "**\(markdownEscaped(displayName(for: participant)))** - \(line)"
            }
    }

    private static func handicapLine(
        participant: RoundParticipant,
        currentHandicap: Double?,
        currentCourseHandicap: Int,
        nextHandicap: Double?,
        snapshot: RoundSnapshot
    ) -> String {
        if snapshot.configuration.handicapEntryFormat == .courseHandicap {
            let nextCourseHandicap = nextHandicap.flatMap {
                HandicapCalculator.courseHandicap(
                    index: $0,
                    participant: participant,
                    courseSegment: snapshot.courseSegment,
                    handicapStrokeBasis: snapshot.handicapStrokeBasis
                )
            }
            return "Course HCP: \(currentCourseHandicap) -> \(courseHandicapLabel(nextCourseHandicap)) next week"
        }

        return "HCP: \(handicapLabel(currentHandicap ?? Double(currentCourseHandicap))) -> \(handicapLabel(nextHandicap)) next week"
    }

    private static func courseHandicapLabel(_ value: Int?) -> String {
        value.map(String.init) ?? "unavailable"
    }

    private static func strongestFinishResult(snapshot: RoundSnapshot) -> (names: [String], netToPar: Int)? {
        let finalHoles = Array(holeNumbers(for: snapshot).suffix(4))
        guard finalHoles.isPopulated else { return nil }

        let results = snapshot.participants
            .filter(\.isPresenceActive)
            .compactMap { participant -> (name: String, netToPar: Int)? in
                let tee = playedTee(for: participant, snapshot: snapshot)
                let entriesByHole = Dictionary(
                    grouping: snapshot.scoring.filter { $0.scoringUnitID == participant.id },
                    by: \.holeNumber
                ).compactMapValues(\.first)
                var total = 0

                for holeNumber in finalHoles {
                    guard let entry = entriesByHole[holeNumber],
                          let par = par(for: holeNumber, tee: tee),
                          let strokes = grossStrokes(from: entry, par: par) else {
                        return nil
                    }
                    let received = ScoringEngine.strokesReceived(
                        handicap: participant.adjustedHandicap,
                        holeNumber: holeNumber,
                        holes: tee?.holes ?? [],
                        playedHoleNumbers: holeNumbers(for: snapshot),
                        useHandicaps: true,
                        handicapStrokeBasis: snapshot.handicapStrokeBasis
                    )
                    total += strokes - par - received
                }

                return (displayName(for: participant), total)
            }

        guard let best = results.map(\.netToPar).min() else { return nil }
        let names = results
            .filter { $0.netToPar == best }
            .map(\.name)
            .sorted()
        return (names, best)
    }

    private static func teamContextParagraph(
        seriesRound: SeriesRound,
        pointAwards: [SeriesPointAward],
        standings: [SeriesStanding],
        teams: [SeriesTeam]
    ) -> String? {
        let currentAwards = pointAwards.filter { $0.seriesRoundID == seriesRound.id && $0.awardTrack == .team }
        let teamStandings = standings.filter { $0.awardTrack == .team }
        guard currentAwards.isPopulated, teamStandings.isPopulated else { return nil }

        let awardPoints = Dictionary(grouping: currentAwards, by: \.competitorID)
            .mapValues { $0.reduce(0.0) { $0 + $1.totalPoints } }
        let awardsByTeam = Dictionary(grouping: currentAwards, by: \.competitorID)
        let teamNames = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.name) })

        struct StandingContext {
            let id: String
            let name: String
            let before: Double
            let after: Double
            let beforeRank: Int
            let afterRank: Int
            let roundPoints: Double
            let result: String
        }

        let beforeEntries = teamStandings.map {
            ($0.competitorID, max(0, $0.totalPoints - (awardPoints[$0.competitorID] ?? 0)), $0.competitorName)
        }
        let afterEntries = teamStandings.map {
            ($0.competitorID, $0.totalPoints, $0.competitorName)
        }
        let beforeRanks = ranks(for: beforeEntries)
        let afterRanks = ranks(for: afterEntries)

        let contexts = teamStandings.map { standing in
            let awards = awardsByTeam[standing.competitorID] ?? []
            let result: String
            if awards.contains(where: { ($0.tieGroupSize ?? 1) > 1 }) {
                result = "tied"
            } else if awards.contains(where: { $0.placement == 1 }) {
                result = "won"
            } else if awards.contains(where: { $0.placement == 2 }) {
                result = "lost"
            } else if let placement = awards.compactMap(\.placement).min() {
                result = "placed \(ordinal(placement))"
            } else {
                result = "earned points"
            }

            return StandingContext(
                id: standing.competitorID,
                name: teamNames[standing.competitorID] ?? standing.competitorName,
                before: max(0, standing.totalPoints - (awardPoints[standing.competitorID] ?? 0)),
                after: standing.totalPoints,
                beforeRank: beforeRanks[standing.competitorID] ?? standing.rank ?? 0,
                afterRank: afterRanks[standing.competitorID] ?? standing.rank ?? 0,
                roundPoints: awardPoints[standing.competitorID] ?? 0,
                result: result
            )
        }

        guard contexts.isPopulated else { return nil }

        let leaderBefore = contexts.sorted {
            if $0.before != $1.before { return $0.before > $1.before }
            return $0.name < $1.name
        }.first
        let leadersAfter = contexts
            .filter { context in
                guard let maxAfter = contexts.map(\.after).max() else { return false }
                return abs(context.after - maxAfter) < 0.000_001
            }
            .sorted { $0.name < $1.name }

        var sentences: [String] = []
        if let leaderBefore, let firstAfter = leadersAfter.first {
            if leadersAfter.contains(where: { $0.id == leaderBefore.id }) && leadersAfter.count == 1 {
                sentences.append("**\(markdownEscaped(leaderBefore.name))** stayed on top after \(leaderBefore.result) and adding \(leaderBefore.roundPoints.seriesPointsDisplayString) points.")
            } else if leadersAfter.count == 1 {
                sentences.append("**\(markdownEscaped(firstAfter.name))** moved into first after \(firstAfter.result), while **\(markdownEscaped(leaderBefore.name))** slipped from the lead.")
            } else {
                let names = leadersAfter.map { "**\(markdownEscaped($0.name))**" }.joined(separator: ", ")
                sentences.append("\(names) now share first place after this round.")
            }
        }

        let movers = contexts
            .filter { $0.beforeRank != $0.afterRank }
            .sorted { lhs, rhs in
                let lhsMove = abs(lhs.beforeRank - lhs.afterRank)
                let rhsMove = abs(rhs.beforeRank - rhs.afterRank)
                if lhsMove != rhsMove { return lhsMove > rhsMove }
                return lhs.afterRank < rhs.afterRank
            }
        if let mover = movers.first {
            let direction = mover.afterRank < mover.beforeRank ? "climbed" : "dropped"
            sentences.append("**\(markdownEscaped(mover.name))** \(direction) from \(ordinal(mover.beforeRank)) to \(ordinal(mover.afterRank)) with a \(mover.result) worth \(mover.roundPoints.seriesPointsDisplayString) points.")
        }

        return sentences.isPopulated ? sentences.joined(separator: " ") : nil
    }

    private static func ranks(for entries: [(id: String, points: Double, name: String)]) -> [String: Int] {
        let ordered = entries.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.name < $1.name
        }
        var ranks: [String: Int] = [:]
        var index = 0
        var rank = 1
        while index < ordered.count {
            let points = ordered[index].points
            let start = index
            while index < ordered.count, abs(ordered[index].points - points) < 0.000_001 {
                index += 1
            }
            for i in start..<index {
                ranks[ordered[i].id] = rank
            }
            rank += index - start
        }
        return ranks
    }

    private static func markdownEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func strokeUnit(_ count: Int) -> String {
        count == 1 ? "stroke" : "strokes"
    }
}

struct SeriesRoundMatchupMemberOption: Identifiable, Hashable {
    let memberID: String
    let teamID: String?
    let title: String
    let subtitle: String?

    var id: String { memberID }
}

struct SeriesRoundMatchupMemberOptionSection: Identifiable, Hashable {
    let id: String
    let title: String
    let options: [SeriesRoundMatchupMemberOption]
}

enum SeriesRoundMatchupMemberOptionBuilder {
    static func sortedMembers(
        _ members: [SeriesMember],
        handicapFor: (String) -> Double?
    ) -> [SeriesMember] {
        members.sorted { lhs, rhs in
            let leftHandicap = handicapFor(lhs.id)
            let rightHandicap = handicapFor(rhs.id)

            switch (leftHandicap, rightHandicap) {
            case let (left?, right?) where abs(left - right) > 0.000_001:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                let byName = lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName)
                if byName != .orderedSame { return byName == .orderedAscending }
                return lhs.id < rhs.id
            }
        }
    }

    static func sections(
        members: [SeriesMember],
        teams: [SeriesTeam],
        usesTeams: Bool,
        handicapFor: (String) -> Double?
    ) -> [SeriesRoundMatchupMemberOptionSection] {
        let sorted = sortedMembers(members, handicapFor: handicapFor)
        guard usesTeams else {
            return [
                SeriesRoundMatchupMemberOptionSection(
                    id: "all-members",
                    title: "Players",
                    options: sorted.map { option(for: $0, handicapFor: handicapFor) }
                ),
            ]
        }

        let membersByTeamID = Dictionary(grouping: sorted) { member in
            guard let teamID = member.teamID, teamID.isPopulated else { return "no-team" }
            return teamID
        }

        var sections: [SeriesRoundMatchupMemberOptionSection] = teams.compactMap { team in
            guard let members = membersByTeamID[team.id], members.isPopulated else { return nil }
            return SeriesRoundMatchupMemberOptionSection(
                id: team.id,
                title: team.name,
                options: members.map { option(for: $0, handicapFor: handicapFor) }
            )
        }

        if let unassigned = membersByTeamID["no-team"], unassigned.isPopulated {
            sections.append(
                SeriesRoundMatchupMemberOptionSection(
                    id: "no-team",
                    title: "No team",
                    options: unassigned.map { option(for: $0, handicapFor: handicapFor) }
                )
            )
        }

        return sections
    }

    static func handicapText(for handicap: Double?) -> String? {
        guard let handicap else { return nil }
        return String(format: "%.1f HCP", handicap)
    }

    private static func option(
        for member: SeriesMember,
        handicapFor: (String) -> Double?
    ) -> SeriesRoundMatchupMemberOption {
        SeriesRoundMatchupMemberOption(
            memberID: member.id,
            teamID: member.teamID,
            title: member.name.fullName,
            subtitle: handicapText(for: handicapFor(member.id))
        )
    }
}

enum SeriesLeagueRulesConfirmationState {
    case notConfirmed
    case confirmed(Time)
    case needsReconfirmation(Time?)
}

private struct SeriesLeagueRulesSignaturePayload: Codable, Hashable {
    var formatTemplateID: String
    var competitionScope: CompetitionScope?
    var teamScoring: RoundTeamScoringConfiguration
    var matchupResolutionStyle: RoundMatchupResolutionStyle
    var sequentialTeeStartsEnabled: Bool
    var sharedScoreHandicapConfig: HandicapConfiguration?
    var defaultTeamScoringProfileID: String?
    var defaultIndividualScoringProfileID: String?
    var handicapConfig: SeriesHandicapConfig
    var allowRoundEditsAfterLobbyCreation: Bool
    var allowManualAwardOverrides: Bool
    var attendanceDefault: SeriesRoundAttendanceStatus
    var podGroupingDefault: SeriesPodGroupingStrategy
    var useTeams: Bool
    var useIndividualStandings: Bool
    var useTeamStandings: Bool

    init(settings: SeriesSettings) {
        formatTemplateID = settings.defaultRoundConfig.formatTemplateID
        competitionScope = settings.defaultRoundConfig.competitionScope
        teamScoring = settings.defaultRoundConfig.teamScoring
        matchupResolutionStyle = settings.defaultRoundConfig.matchupResolutionStyle
        sequentialTeeStartsEnabled = settings.defaultRoundConfig.sequentialTeeStartsEnabled ?? false
        sharedScoreHandicapConfig = settings.defaultRoundConfig.sharedScoreHandicapConfig
        defaultTeamScoringProfileID = settings.defaultTeamScoringProfileID
        defaultIndividualScoringProfileID = settings.defaultIndividualScoringProfileID
        handicapConfig = settings.handicapConfig
        allowRoundEditsAfterLobbyCreation = settings.allowRoundEditsAfterLobbyCreation
        allowManualAwardOverrides = settings.allowManualAwardOverrides
        attendanceDefault = settings.attendanceDefault
        podGroupingDefault = settings.podGroupingDefault
        useTeams = settings.useTeams
        useIndividualStandings = settings.useIndividualStandings
        useTeamStandings = settings.useTeamStandings
    }
}

@MainActor
final class SeriesViewModel: ObservableObject, Loggable {
    @Published var series: Series = .init()
    @Published var members: [SeriesMember] = []
    @Published var invites: [SeriesInvite] = []
    @Published var teams: [SeriesTeam] = []
    @Published var pods: [SeriesTeamPod] = []
    @Published var rounds: [SeriesRound] = []
    @Published var announcements: [SeriesAnnouncement] = []
    @Published var scoringProfiles: [SeriesScoringProfile] = []
    @Published var pointAwards: [SeriesPointAward] = []
    @Published var standings: [SeriesStanding] = []
    @Published var handicapScores: [SeriesHandicapScore] = []
    @Published var handicapOverrides: [SeriesHandicapOverride] = []
    @Published var memberHandicaps: [String: SeriesMemberHandicap] = [:]
    /// Score row IDs: rolling pool vs scores that count toward the computed index (handicap enabled).
    @Published var memberHandicapScoreSelections: [String: (poolIDs: Set<String>, countingIDs: Set<String>)] = [:]
    @Published var attendanceByMember: [String: SeriesRoundAttendance] = [:]
    @Published var attendanceByRound: [String: [SeriesRoundAttendance]] = [:]
    @Published var linkedRounds: [String: Round] = [:]
    private var linkedRoundSnapshotCache: [String: RoundSnapshot] = [:]
    @Published var isLoading = true
    @Published var isEnriching = false
    @Published var isSaving = false
    @Published var creatingRoundID: String?
    @Published var correctingRoundID: String?
    @Published var exportingRoundID: String?
    @Published var exportedCSVURL: URL?
    @Published var seriesCourseTeesByCourseID: [String: [Tee]] = [:]
    @Published var isRebuildingIndividualStandings = false

    var seriesID: String { series.id }
    var currentUserID: String?
    var currentPlayerID: String?
    private var isHydratingHandicapScoreMetadata = false

    var isCommissioner: Bool {
        guard let userID = currentUserID else { return false }
        if series.commissionerUserID == userID { return true }
        guard let playerID = currentPlayerID else { return false }
        return activeMembers.first { $0.playerID == playerID }?.role == .commissioner
    }

    var currentMemberID: String? {
        guard let playerID = currentPlayerID else { return nil }
        return activeMembers.first { $0.playerID == playerID }?.id
    }

    /// Roster row for the signed-in player, if they are on the series.
    var currentMemberRecord: SeriesMember? {
        guard let playerID = currentPlayerID else { return nil }
        return activeMembers.first { $0.playerID == playerID }
    }

    /// Stored role on the roster; series owner with a non-commissioner row is still covered by `isCommissioner`.
    var isCaptain: Bool {
        currentMemberRecord?.role == .captain
    }

    var activeMembers: [SeriesMember] {
        members
            .filter(\.isActive)
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
    }

    var eligibleMembers: [SeriesMember] {
        activeMembers.filter { $0.role != .spectator }
    }

    var sortedTeams: [SeriesTeam] {
        teams.sorted { a, b in
            let byName = a.name.localizedCaseInsensitiveCompare(b.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.index < b.index
        }
    }

    var sortedPods: [SeriesTeamPod] {
        pods.sorted {
            if $0.teamID != $1.teamID { return $0.teamID < $1.teamID }
            return $0.index < $1.index
        }
    }

    var activeAnnouncements: [SeriesAnnouncement] {
        announcements
            .filter { $0.isActive() }
            .sorted {
                if $0.startsAt.unix != $1.startsAt.unix { return $0.startsAt.unix > $1.startsAt.unix }
                return $0.createdAt.unix > $1.createdAt.unix
            }
    }

    private func sortRoundsByScheduleThenIndex(_ lhs: SeriesRound, _ rhs: SeriesRound) -> Bool {
        let lhsT = lhs.scheduledAt?.unix ?? .greatestFiniteMagnitude
        let rhsT = rhs.scheduledAt?.unix ?? .greatestFiniteMagnitude
        if lhsT != rhsT { return lhsT < rhsT }
        return lhs.index < rhs.index
    }

    var inProgressRounds: [SeriesRound] {
        rounds
            .filter {
                let status = effectiveStatus(for: $0)
                return status == .lobby || status == .live
            }
            .sorted(by: sortRoundsByScheduleThenIndex)
    }

    var plannedRounds: [SeriesRound] {
        rounds
            .filter { effectiveStatus(for: $0) == .planned }
            .sorted(by: sortRoundsByScheduleThenIndex)
    }

    var completedRounds: [SeriesRound] {
        rounds
            .filter { effectiveStatus(for: $0) == .complete }
            .sorted { ($0.completedAt?.unix ?? 0) > ($1.completedAt?.unix ?? 0) }
    }

    var canceledRounds: [SeriesRound] {
        rounds
            .filter { effectiveStatus(for: $0) == .canceled }
            .sorted { ($0.scheduledAt?.unix ?? 0) > ($1.scheduledAt?.unix ?? 0) }
    }

    var teamStandings: [SeriesStanding] {
        standings
            .filter { $0.awardTrack == .team }
            .sorted(by: standingsSort)
    }

    var individualStandings: [SeriesStanding] {
        standings
            .filter { $0.awardTrack == .individual }
            .sorted(by: standingsSort)
    }

    var canRebuildIndividualStandings: Bool {
        isCommissioner
            && individualStandings.isEmpty
            && completedRounds.contains(where: hasIndividualPlacementAwardsConfigured)
    }

    var hasTeams: Bool {
        series.settings.useTeams || !teams.isEmpty
    }

    var usesTeams: Bool {
        series.settings.useTeams
    }

    /// League default uses fixed pairs for pod-aligned grouping instead of fully manual tee-group suggestions.
    var isPodPairGroupingEnabled: Bool {
        series.settings.podGroupingDefault.usesPodAlignment
    }

    var hasPlayers: Bool { eligibleMembers.count > 2 }
    var hasScheduledRound: Bool { rounds.isPopulated }
    var hasScoringRules: Bool { isLeagueRulesConfirmed(for: series.settings) }
    var hasDefaultCourse: Bool { series.settings.defaultCourse?.isConfigured == true }
    var isSeriesScoreboardEligible: Bool {
        SeriesScoreboardEligibility.isEligible(teams: teams)
    }
    var scoreboardSnapshot: SeriesScoreboardSnapshot? {
        guard series.settings.showScoreboardTile, isSeriesScoreboardEligible else { return nil }
        return SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: rounds,
            scoringProfiles: scoringProfiles,
            pointAwards: pointAwards,
            teams: teams,
            members: members
        )
    }
    var skippedDefaultCourse: Bool { false }
    var checklistComplete: Bool { hasPlayers && hasScheduledRound && hasScoringRules }

    /// Common PostHog props for `series.*` events (no PII).
    private func seriesTelemetryProps(_ extra: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = ["series_id": seriesID, "is_commissioner": isCommissioner]
        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    var leagueRulesConfirmationState: SeriesLeagueRulesConfirmationState {
        leagueRulesConfirmationState(for: series.settings)
    }

    func materialLeagueRulesSignature(for settings: SeriesSettings) -> String {
        let payload = SeriesLeagueRulesSignaturePayload(settings: settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload),
              let signature = String(data: data, encoding: .utf8) else {
            return ""
        }
        return signature
    }

    func isLeagueRulesConfirmed(for settings: SeriesSettings) -> Bool {
        guard series.leagueRulesConfirmedAt != nil else { return false }
        return series.leagueRulesSignature == materialLeagueRulesSignature(for: settings)
    }

    func leagueRulesConfirmationState(for settings: SeriesSettings) -> SeriesLeagueRulesConfirmationState {
        guard let confirmedAt = series.leagueRulesConfirmedAt else { return .notConfirmed }
        let signature = materialLeagueRulesSignature(for: settings)
        return series.leagueRulesSignature == signature ? .confirmed(confirmedAt) : .needsReconfirmation(confirmedAt)
    }

    func effectiveStatus(for seriesRound: SeriesRound) -> SeriesRoundStatus {
        guard let roundID = seriesRound.roundID,
              let linkedRound = linkedRounds[roundID] else { return seriesRound.status }
        return SeriesRoundStatus(linkedRoundStatus: linkedRound.status)
    }

    func effectiveRoundConfig(for seriesRound: SeriesRound) -> SeriesRoundConfiguration {
        guard let roundID = seriesRound.roundID,
              let linkedRound = linkedRounds[roundID],
              shouldUseLinkedRoundConfiguration(for: seriesRound, linkedRound: linkedRound)
        else { return seriesRound.roundConfig }
        return roundConfig(from: linkedRound, fallback: seriesRound.roundConfig)
    }

    func shouldUseLinkedRoundConfiguration(for seriesRound: SeriesRound, linkedRound: Round) -> Bool {
        guard seriesRound.roundConfig.allowLobbyBackPropagation else { return false }
        switch linkedRound.status {
        case .lobby, .live, .paused, .complete:
            return true
        case .archived:
            return false
        }
    }

    func roundTileFormatCaption(for seriesRound: SeriesRound) -> String {
        SeriesRoundTileCopy.formatCaption(
            config: effectiveRoundConfig(for: seriesRound),
            series: series
        )
    }

    func roundTileOpponentSummary(for seriesRound: SeriesRound) -> SeriesRoundTileOpponentSummary? {
        SeriesRoundTileCopy.opponentSummary(
            seriesRound: seriesRound,
            configuration: effectiveRoundConfig(for: seriesRound),
            currentMemberID: currentMemberID,
            members: activeMembers,
            teams: teams,
            pods: sortedPods,
            hasTeamsInLeague: hasTeams
        )
    }

    func roundTileTeeGroupContext(for seriesRound: SeriesRound) -> String? {
        guard seriesRound.plannedTeeGroups.isPopulated,
              let memberID = currentMemberID else { return nil }

        guard let group = seriesRound.plannedTeeGroups.first(where: { $0.memberIDs.contains(memberID) })
        else { return nil }

        var parts: [String] = []

        if let teeTime = group.teeTime, !teeTime.isEmpty {
            parts.append(teeTime)
        }
        if group.startingHole > 0 {
            parts.append("Hole \(group.startingHole)")
        }

        let partnerNames = group.memberIDs
            .filter { $0 != memberID }
            .compactMap { id in activeMembers.first(where: { $0.id == id })?.name.givenName }
            .filter { !$0.isEmpty }

        if !partnerNames.isEmpty {
            parts.append("with \(partnerNames.joined(separator: ", "))")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " \(kDot) ")
    }

    func handicapParticipationMembers(for seriesRound: SeriesRound?) -> [SeriesMember] {
        guard let seriesRound,
              let linked = linkedRound(for: seriesRound),
              linked.players.isPopulated else {
            return eligibleMembers
        }

        let playerIDs = Set(linked.players)
        let linkedMembers = eligibleMembers.filter { member in
            guard let playerID = member.playerID else { return false }
            return playerIDs.contains(playerID)
        }
        return linkedMembers.isPopulated ? linkedMembers : eligibleMembers
    }

    /// Returns `true` when all participants in the linked round have submitted completion entries.
    func allScoresComplete(for seriesRound: SeriesRound) -> Bool {
        guard let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID],
              linked.players.isPopulated else { return false }
        let completedIDs = Set(linked.completedPlayers.map(\.playerID))
        return linked.players.allSatisfy { completedIDs.contains($0) }
    }

    /// Returns `true` once a live linked round has at least one completed player available for score review.
    func canReviewScores(for seriesRound: SeriesRound) -> Bool {
        guard effectiveStatus(for: seriesRound) == .live,
              let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID] else { return false }
        return linked.completedPlayers.contains { $0.playerID.isPopulated }
    }

    /// Linked round for a given series round, if available.
    func linkedRound(for seriesRound: SeriesRound) -> Round? {
        guard let roundID = seriesRound.roundID else { return nil }
        return linkedRounds[roundID]
    }

    /// Series list navigation target for a linked round (aligned with `DashboardView.handleRoundTap`).
    enum LinkedRoundNavigationTarget {
        case lobby
        case liveRound
        case roundOutcome
    }

    func linkedRoundNavigationTarget(for seriesRound: SeriesRound) -> LinkedRoundNavigationTarget {
        guard let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID] else {
            return .lobby
        }
        switch linked.status {
        case .complete, .paused:
            return .roundOutcome
        case .live:
            if allScoresComplete(for: seriesRound) { return .roundOutcome }
            if let pid = currentPlayerID,
               linked.completedPlayers.contains(where: { $0.playerID == pid }) {
                return .roundOutcome
            }
            return .liveRound
        case .lobby:
            return .lobby
        case .archived:
            return .lobby
        }
    }

    func openLinkedRoundButtonTitle(for seriesRound: SeriesRound) -> String {
        switch linkedRoundNavigationTarget(for: seriesRound) {
        case .roundOutcome:
            return "View results"
        case .liveRound:
            return "Continue playing"
        case .lobby:
            return "Open lobby"
        }
    }

    func openLinkedRoundButtonColor(for seriesRound: SeriesRound) -> Color {
        switch linkedRoundNavigationTarget(for: seriesRound) {
        case .roundOutcome:
            return .accentYellow
        case .liveRound:
            return .accentPurple
        case .lobby:
            return .accentGreen
        }
    }

    func isRSVPEligible(for seriesRound: SeriesRound) -> Bool {
        guard series.settings.isAttendanceEnabled else { return false }
        let status = effectiveStatus(for: seriesRound)
        return status == .planned && seriesRound.roundID == nil
    }

    /// Returns whether the current user participated in the linked round and their score label.
    /// Score label is the gross total relative to par (e.g. "+5", "E", "-2").
    /// Returns `nil` when there is no linked round or the current player cannot be identified.
    func currentUserScoreContext(for seriesRound: SeriesRound) -> (played: Bool, scoreLabel: String?)? {
        guard let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID],
              let playerID = currentPlayerID else { return nil }

        let played = linked.players.contains(playerID)

        guard played,
              let memberID = currentMemberID,
              let hs = handicapScores.first(where: { $0.sourceRoundID == roundID && $0.memberID == memberID })
        else { return (played: played, scoreLabel: nil) }

        let diff = Int(hs.score) - Int(hs.par)
        let label = diff == 0 ? "E" : diff > 0 ? "+\(diff)" : "\(diff)"
        return (played: true, scoreLabel: label)
    }

    /// Force-completes all remaining players for a live round (commissioner action).
    func forceCompleteRound(_ seriesRound: SeriesRound) async {
        guard isCommissioner,
              let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID] else { return }

        let completedIDs = Set(linked.completedPlayers.map(\.playerID))
        let remaining = linked.players.filter { !completedIDs.contains($0) }

        guard remaining.isPopulated else {
            await refreshLinkedRoundState()
            return
        }

        let entries = remaining.map { playerID in
            CompletedPlayer(
                playerID: playerID,
                completedAt: .init(),
                type: .commissionerOverride,
                scorecardStorageID: nil
            )
        }

        do {
            try await FirebaseService.shared.markPlayersComplete(roundID: roundID, completedPlayers: entries)
        } catch {
            addBreadcrumb(level: .error, message: "forceCompleteRound batch mark failed", error: error)
            return
        }

        addEvent(
            "series.round_force_completed",
            eventProps: seriesTelemetryProps([
                "series_round_id": seriesRound.id,
                "round_id": roundID,
                "players_marked_complete": entries.count
            ])
        )

        if case .success(let refreshed) = await FirebaseService.shared.getRoundByID(roundID) {
            linkedRounds[roundID] = refreshed
        }

        await refreshLinkedRoundState()
    }

    func suggestedCourseSelectionForNextRound() -> SeriesCourseSelection? {
        resolvedDefaultCourseSelection(forRoundIndex: rounds.nextIndex)
    }

    func suggestedCourseSelection(forRoundIndex roundIndex: Int) -> SeriesCourseSelection? {
        resolvedDefaultCourseSelection(forRoundIndex: roundIndex)
    }

    func suggestedMatchupPlans(
        pairGroupingStrategy: SeriesPodGroupingStrategy? = nil,
        preserving existingPlans: [SeriesRoundMatchupPlan] = []
    ) -> [SeriesRoundMatchupPlan] {
        guard usesTeams else { return [] }

        let orderedTeams = sortedTeams
        var plans: [SeriesRoundMatchupPlan] = []
        var pairIndex = 0
        var teamCursor = 0

        while teamCursor + 1 < orderedTeams.count {
            let teamAID = orderedTeams[teamCursor].id
            let teamBID = orderedTeams[teamCursor + 1].id
            let existing = existingPlans.first {
                Set([$0.teamAID, $0.teamBID]) == Set([teamAID, teamBID])
            }

            plans.append(
                SeriesRoundMatchupPlan(
                    id: existing?.id ?? HackersID.string(),
                    teamAID: teamAID,
                    teamBID: teamBID,
                    index: pairIndex,
                    podGroupingStrategy: existing?.podGroupingStrategy ?? pairGroupingStrategy ?? series.settings.podGroupingDefault,
                    notes: existing?.notes,
                    isLocked: existing?.isLocked ?? false,
                    createdAt: existing?.createdAt ?? .init(),
                    lastUpdatedAt: .init()
                )
            )

            pairIndex += 1
            teamCursor += 2
        }

        return plans
    }

    func pairGroupingTitle(
        for strategy: SeriesPodGroupingStrategy,
        matchupPlans: [SeriesRoundMatchupPlan]? = nil
    ) -> String {
        switch strategy {
        case .disabled:
            return "Manual"
        case .alignByIndex:
            return "Align pairs"
        case .swapPairs:
            return shouldPresentRotatePairs(for: matchupPlans) ? "Rotate pairs" : "Swap pairs"
        }
    }

    func pairGroupingSubtitle(
        for strategy: SeriesPodGroupingStrategy,
        matchupPlans: [SeriesRoundMatchupPlan]? = nil
    ) -> String {
        switch strategy {
        case .disabled:
            return "Pairs do not affect tee-group suggestions."
        case .alignByIndex:
            return "Team 1 A vs Team 2 A, Team 1 B vs Team 2 B."
        case .swapPairs:
            if shouldPresentRotatePairs(for: matchupPlans) {
                return "Each Team 1 pair shifts to the next Team 2 pair, wrapping at the end."
            }
            return "Team 1 A vs Team 2 B, Team 1 B vs Team 2 A."
        }
    }

    private func shouldPresentRotatePairs(for matchupPlans: [SeriesRoundMatchupPlan]? = nil) -> Bool {
        let relevantPlans: [SeriesRoundMatchupPlan]
        if let matchupPlans, matchupPlans.isPopulated {
            relevantPlans = matchupPlans.filter { $0.teamAID.isPopulated && $0.teamBID.isPopulated }
        } else {
            let orderedTeams = sortedTeams
            var plans: [SeriesRoundMatchupPlan] = []
            var teamCursor = 0
            var index = 0
            while teamCursor + 1 < orderedTeams.count {
                plans.append(
                    SeriesRoundMatchupPlan(
                        teamAID: orderedTeams[teamCursor].id,
                        teamBID: orderedTeams[teamCursor + 1].id,
                        index: index,
                        podGroupingStrategy: .swapPairs
                    )
                )
                teamCursor += 2
                index += 1
            }
            relevantPlans = plans
        }

        guard relevantPlans.isPopulated else { return false }
        let podsByTeam = Dictionary(grouping: pods.filter(\.isSchedulable)) { $0.teamID }

        return relevantPlans.contains { plan in
            let podsA = (podsByTeam[plan.teamAID] ?? []).count
            let podsB = (podsByTeam[plan.teamBID] ?? []).count
            return podsA == podsB && podsA > 2
        }
    }

    func suggestedIndividualMatchupPlans(
        preserving existingPlans: [SeriesRoundMatchupPlan] = []
    ) -> [SeriesRoundMatchupPlan] {
        let orderedMembers = eligibleMembers
        guard usesTeams else {
            return sequentialIndividualMatchupPlans(
                orderedMembers: orderedMembers,
                preserving: existingPlans
            )
        }

        let sortedMembers = SeriesRoundMatchupMemberOptionBuilder.sortedMembers(orderedMembers) { [weak self] memberID in
            self?.effectiveHandicap(for: memberID)
        }
        let membersByTeamID = Dictionary(grouping: sortedMembers) { $0.teamID ?? "" }
        let orderedTeamIDs = sortedTeams.map(\.id).filter { membersByTeamID[$0]?.isPopulated == true }

        guard orderedTeamIDs.count >= 2 else {
            return sequentialIndividualMatchupPlans(
                orderedMembers: sortedMembers,
                preserving: existingPlans
            )
        }

        var remainingByTeamID = Dictionary(uniqueKeysWithValues: orderedTeamIDs.map { teamID in
            (teamID, membersByTeamID[teamID] ?? [])
        })
        var plans: [SeriesRoundMatchupPlan] = []
        var matchupIndex = 0

        while true {
            let availableTeamIDs = orderedTeamIDs.filter { remainingByTeamID[$0]?.isPopulated == true }
            guard availableTeamIDs.count >= 2 else { break }
            let teamAID = availableTeamIDs[0]
            let teamBID = availableTeamIDs[1]
            guard let memberA = remainingByTeamID[teamAID]?.first,
                  let memberB = remainingByTeamID[teamBID]?.first else {
                break
            }
            remainingByTeamID[teamAID]?.removeFirst()
            remainingByTeamID[teamBID]?.removeFirst()

            let memberAID = memberA.id
            let memberBID = memberB.id
            let existing = existingPlans.first {
                Set([$0.memberAID ?? "", $0.memberBID ?? ""]) == Set([memberAID, memberBID])
            }

            plans.append(
                SeriesRoundMatchupPlan(
                    id: existing?.id ?? HackersID.string(),
                    memberAID: memberAID,
                    memberBID: memberBID,
                    index: matchupIndex,
                    podGroupingStrategy: .disabled,
                    notes: existing?.notes,
                    isLocked: existing?.isLocked ?? false,
                    createdAt: existing?.createdAt ?? .init(),
                    lastUpdatedAt: .init()
                )
            )

            matchupIndex += 1
        }

        return plans
    }

    private func sequentialIndividualMatchupPlans(
        orderedMembers: [SeriesMember],
        preserving existingPlans: [SeriesRoundMatchupPlan]
    ) -> [SeriesRoundMatchupPlan] {
        var plans: [SeriesRoundMatchupPlan] = []
        var matchupIndex = 0
        var memberCursor = 0

        while memberCursor + 1 < orderedMembers.count {
            let memberAID = orderedMembers[memberCursor].id
            let memberBID = orderedMembers[memberCursor + 1].id
            let existing = existingPlans.first {
                Set([$0.memberAID ?? "", $0.memberBID ?? ""]) == Set([memberAID, memberBID])
            }

            plans.append(
                SeriesRoundMatchupPlan(
                    id: existing?.id ?? HackersID.string(),
                    memberAID: memberAID,
                    memberBID: memberBID,
                    index: matchupIndex,
                    podGroupingStrategy: .disabled,
                    notes: existing?.notes,
                    isLocked: existing?.isLocked ?? false,
                    createdAt: existing?.createdAt ?? .init(),
                    lastUpdatedAt: .init()
                )
            )

            matchupIndex += 1
            memberCursor += 2
        }

        return plans
    }

    func effectiveHandicap(for memberID: String) -> Double? {
        memberHandicaps[memberID]?.effectiveIndex
    }

    // MARK: - Loading

    func load(seriesID: String) async {
        isLoading = true
        isEnriching = false
        defer {
            isLoading = false
            isEnriching = false
        }

        if let user = await AppData.shared.user {
            currentUserID = user.id
        }
        if let player = await AppData.shared.getPrimaryPlayer() {
            currentPlayerID = player.id
        }

        switch await FirebaseService.shared.fetchSeries(id: seriesID) {
        case .success(let loadedSeries):
            series = loadedSeries
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to load series", error: error)
            return
        }

        async let membersTask = FirebaseService.shared.fetchSeriesMembers(seriesID: seriesID)
        async let invitesTask = FirebaseService.shared.fetchSeriesInvites(seriesID: seriesID)
        async let teamsTask = FirebaseService.shared.fetchSeriesTeams(seriesID: seriesID)
        async let podsTask = FirebaseService.shared.fetchSeriesPods(seriesID: seriesID)
        async let roundsTask = FirebaseService.shared.fetchSeriesRounds(seriesID: seriesID)
        async let announcementsTask = FirebaseService.shared.fetchSeriesAnnouncements(seriesID: seriesID)
        async let profilesTask = FirebaseService.shared.fetchScoringProfiles(seriesID: seriesID)
        async let pointAwardsTask = FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        async let standingsTask = FirebaseService.shared.fetchStandings(seriesID: seriesID)
        async let scoresTask = FirebaseService.shared.fetchHandicapScores(seriesID: seriesID)
        async let overridesTask = FirebaseService.shared.fetchHandicapOverrides(seriesID: seriesID)

        members = await membersTask
        invites = await invitesTask
        teams = await teamsTask
        pods = await podsTask
        rounds = await roundsTask
        announcements = await announcementsTask
        scoringProfiles = await profilesTask
        pointAwards = await pointAwardsTask
        standings = await standingsTask
        handicapScores = await scoresTask
        handicapOverrides = await overridesTask

        isLoading = false
        isEnriching = true

        await loadLinkedRounds()
        await syncLinkedRoundState()
        await loadAttendanceForRSVPEligibleRounds()
        recomputeAllHandicaps()
        await hydrateRoundHandicapScoreMetadataIfNeeded()
        await backfillOfflineMemberUserIDs()
        await createBuiltInScoringProfilesIfNeeded()
    }

    private func backfillOfflineMemberUserIDs() async {
        let offlineIDs = members.enumerated().compactMap { (i, m) -> (Int, String)? in
            guard m.userID == nil, let pid = m.playerID, pid.isPopulated else { return nil }
            return (i, pid)
        }
        guard offlineIDs.isPopulated else { return }

        let playerIDs = offlineIDs.map(\.1)
        guard case .success(let players) = await FirebaseService.shared.getPlayersByIDs(playerIDs) else { return }

        let userIDByPlayerID = Dictionary(
            uniqueKeysWithValues: players.compactMap { p -> (String, String)? in
                guard let uid = p.userID, uid.isPopulated else { return nil }
                return (p.id, uid)
            }
        )
        for (index, playerID) in offlineIDs {
            guard let uid = userIDByPlayerID[playerID] else { continue }
            members[index].userID = uid
            members[index].lastUpdatedAt = .init()
            _ = await FirebaseService.shared.updateSeriesMember(members[index])
        }
    }

    private func loadLinkedRounds() async {
        let roundIDs = Array(Set(rounds.compactMap(\.roundID).filter(\.isPopulated)))
        guard roundIDs.isPopulated else {
            linkedRounds = [:]
            linkedRoundSnapshotCache = [:]
            return
        }

        let fetched = await FirebaseService.shared.getRoundsByIDs(roundIDs)
        linkedRounds = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        linkedRoundSnapshotCache = linkedRoundSnapshotCache.filter { roundIDs.contains($0.key) }
    }

    func shouldPreloadAttendance(for seriesRound: SeriesRound) -> Bool {
        isRSVPEligible(for: seriesRound)
    }

    func loadAttendanceForRSVPEligibleRounds() async {
        guard series.settings.isAttendanceEnabled else {
            attendanceByRound = [:]
            return
        }

        var dictionary = attendanceByRound
        for round in rounds where shouldPreloadAttendance(for: round) {
            dictionary[round.id] = await FirebaseService.shared.fetchSeriesRoundAttendance(
                seriesID: seriesID,
                seriesRoundID: round.id
            )
        }
        attendanceByRound = dictionary
    }

    func loadAttendance(for seriesRoundID: String) async {
        let list = await FirebaseService.shared.fetchSeriesRoundAttendance(seriesID: seriesID, seriesRoundID: seriesRoundID)
        attendanceByRound[seriesRoundID] = list
        attendanceByMember = Dictionary(uniqueKeysWithValues: list.map { ($0.memberID, $0) })
    }

    private func refreshSeriesCachesIfNeeded() async {
        let newRoundCount = rounds.count
        let newCompletedCount = rounds.filter { effectiveStatus(for: $0) == .complete }.count
        let newAnnouncementCount = activeAnnouncements.count
        let newStatus: SeriesStatus = {
            if rounds.contains(where: { effectiveStatus(for: $0) == .live || effectiveStatus(for: $0) == .lobby }) {
                return .active
            }
            if newRoundCount > 0 && newRoundCount == newCompletedCount {
                return .completed
            }
            if newRoundCount > 0 { return .active }
            return .draft
        }()

        guard series.roundCount != newRoundCount
                || series.completedRoundCount != newCompletedCount
                || series.activeAnnouncementCount != newAnnouncementCount
                || series.status != newStatus else { return }

        series.roundCount = newRoundCount
        series.completedRoundCount = newCompletedCount
        series.activeAnnouncementCount = newAnnouncementCount
        series.status = newStatus
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
    }

    // MARK: - Series Mutations

    func updateName(_ newName: String) async {
        series.name = newName
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        addEvent("series.name_updated", eventProps: seriesTelemetryProps())
    }

    func saveLeagueDetailsAndSettings(name: String, description: String, settings: SeriesSettings) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isPopulated else { return false }

        let previousSettings = series.settings
        let sanitized = sanitizedLeagueSettings(settings)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        series.name = trimmedName
        series.description = trimmedDescription.isPopulated ? trimmedDescription : nil
        series.settings = sanitized
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: sanitized)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        await createBuiltInScoringProfilesIfNeeded()
        await refreshSeriesCachesIfNeeded()
        addEvent("series.league_details_saved", eventProps: seriesTelemetryProps([
            "has_description": trimmedDescription.isPopulated
        ]))
        return true
    }

    func updateDefaultCourse(
        courseID: String,
        cachedName: String,
        defaultTeeID: String?,
        holeSegment: HoleSegment = .full18
    ) async {
        let resolvedHoleSegment: HoleSegment = {
            if series.settings.defaultCourseRotationMode == .alternateFrontBack,
               !holeSegment.isNineHoleLeagueSegment {
                return .front9
            }
            return holeSegment
        }()

        series.settings.defaultCourse = SeriesCourseSelection(
            courseID: courseID,
            cachedName: cachedName,
            defaultTeeBoxID: defaultTeeID ?? "",
            holeSegment: resolvedHoleSegment
        )
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        addEvent(
            "series.default_course_set",
            eventProps: seriesTelemetryProps([
                "course_id": courseID,
                "hole_segment": "\(resolvedHoleSegment)"
            ])
        )
    }

    func clearDefaultCourse() async {
        series.settings.defaultCourse = nil
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        addEvent("series.default_course_cleared", eventProps: seriesTelemetryProps())
    }

    func skipDefaultCourse() async {
        await clearDefaultCourse()
    }

    func saveLeagueSettings(_ settings: SeriesSettings) async {
        let previousSettings = series.settings
        let sanitized = sanitizedLeagueSettings(settings)
        series.settings = sanitized
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: sanitized)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        await createBuiltInScoringProfilesIfNeeded()
        await refreshSeriesCachesIfNeeded()
        addEvent("series.league_settings_saved", eventProps: seriesTelemetryProps())
    }

    func setScoreboardVisible(_ isVisible: Bool) async {
        let resolvedVisibility = isSeriesScoreboardEligible ? isVisible : false
        guard series.settings.showScoreboardTile != resolvedVisibility else { return }
        let previousSettings = series.settings
        series.settings.showScoreboardTile = resolvedVisibility
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        addEvent(
            "series.scoreboard_visibility_changed",
            eventProps: seriesTelemetryProps(["visible": resolvedVisibility])
        )
    }

    func confirmLeagueRules(_ settings: SeriesSettings) async {
        let sanitized = sanitizedLeagueSettings(settings)
        series.settings = sanitized
        series.leagueRulesConfirmedAt = .init()
        series.leagueRulesConfirmedByUserID = currentUserID ?? series.commissionerUserID
        series.leagueRulesSignature = materialLeagueRulesSignature(for: sanitized)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        await createBuiltInScoringProfilesIfNeeded()
        await refreshSeriesCachesIfNeeded()
        addEvent("series.league_rules_confirmed", eventProps: seriesTelemetryProps())
    }

    func saveHandicapSettings(_ handicapConfig: SeriesHandicapConfig) async {
        let previousSettings = series.settings
        series.handicapConfig = handicapConfig
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        await hydrateRoundHandicapScoreMetadataIfNeeded()
        recomputeAllHandicaps()
        await refreshSeriesCachesIfNeeded()
        addEvent(
            "series.handicap_settings_saved",
            eventProps: seriesTelemetryProps([
                "handicap_enabled": handicapConfig.isEnabled,
                "handicap_mode": handicapConfig.mode.rawValue
            ])
        )
    }

    private func sanitizedLeagueSettings(_ settings: SeriesSettings) -> SeriesSettings {
        var sanitized = settings
        if sanitized.useTeams {
            sanitized.defaultRoundConfig.teamAssignmentMode = .seriesTeams
            sanitized.defaultRoundConfig.matchupMode = sanitized.defaultRoundConfig.resolvedCompetitionScope == .matchup ? .teamVsTeam : .field
        } else {
            sanitized.defaultRoundConfig.teamAssignmentMode = .manual
            sanitized.defaultRoundConfig.matchupMode = sanitized.defaultRoundConfig.resolvedCompetitionScope == .matchup
                ? .individualVsIndividual
                : .field
            sanitized.defaultRoundConfig.podGroupingStrategy = .disabled
            sanitized.useTeamStandings = false
        }
        if sanitized.defaultCourseRotationMode == .alternateFrontBack,
           let defaultCourse = sanitized.defaultCourse,
           !defaultCourse.holeSegment.isNineHoleLeagueSegment {
            sanitized.defaultCourse = defaultCourse.applying(holeSegment: .front9)
        }
        return sanitized
    }

    private func invalidateLeagueRulesConfirmationIfNeeded(previousSettings: SeriesSettings, newSettings: SeriesSettings) {
        guard materialLeagueRulesSignature(for: previousSettings) != materialLeagueRulesSignature(for: newSettings) else { return }
        series.leagueRulesConfirmedAt = nil
        series.leagueRulesConfirmedByUserID = nil
        series.leagueRulesSignature = nil
    }

    // MARK: - Member Mutations

    func addMember(_ player: Player) async {
        guard !hasActiveMember(for: player) else { return }

        var member = SeriesMember(
            id: HackersID.string(),
            userID: player.userID,
            playerID: player.id,
            name: player.name,
            role: .member,
            defaultTeeBoxID: nil,
            isActive: true,
            joinedAt: .init(),
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.addSeriesMember(member) {
        case .success(let created):
            member = created
            members.append(member)
            let matchingInviteIDs = invites.indices.filter { index in
                let invite = invites[index]
                guard invite.status == .pending else { return false }

                let matchesPlayerID = player.id.isPopulated && invite.invitedPlayerID == player.id
                let matchesUserID = (player.userID?.isPopulated == true) && invite.invitedUserID == player.userID
                return matchesPlayerID || matchesUserID
            }

            for inviteIndex in matchingInviteIDs {
                invites[inviteIndex].status = .accepted
                invites[inviteIndex].respondedAt = .init()
                invites[inviteIndex].resolvedMemberID = member.id
                invites[inviteIndex].lastUpdatedAt = .init()
                _ = await FirebaseService.shared.updateSeriesInvite(invites[inviteIndex])
            }
            if let playerID = member.playerID, playerID.isPopulated {
                if !series.memberPlayerIDs.contains(playerID) {
                    series.memberPlayerIDs.append(playerID)
                    try? await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: playerID)
                }
            }
            await seedAttendanceForFutureRounds(memberID: member.id)
            recomputeAllHandicaps()
            await refreshSeriesCachesIfNeeded()
            addEvent(
                "series.member_added",
                eventProps: seriesTelemetryProps([
                    "is_offline_profile": player.userID == nil,
                    "member_role": member.role.rawValue
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add series member", error: error)
        }
    }

    func addOfflineMember(name: Name) async {
        guard !hasOfflineMember(named: name) else { return }

        var player = Player(name: name)
        player.userID = nil
        player.lastUpdatedAt = .init()

        let createdPlayer: Player
        switch await player.post() {
        case .success(let saved):
            createdPlayer = saved
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create offline player profile", error: error)
            return
        }

        await addMember(createdPlayer)
    }

    /// Removes an active member from the series (commissioner only). Used from add-players sheet to undo a mistaken add.
    func removeMember(playing player: Player) async {
        guard isCommissioner else { return }
        let resolvedPlayerID = player.playerID ?? player.id
        guard let index = members.firstIndex(where: { member in
            guard member.isActive else { return false }
            if resolvedPlayerID.isPopulated { return member.playerID == resolvedPlayerID }
            return member.playerID == nil
                && normalizedName(member.name) == normalizedName(player.name)
        }) else { return }

        let member = members[index]
        guard member.role != .commissioner else { return }

        await removeActiveMember(at: index, fallbackPlayerID: resolvedPlayerID, selfInitiatedLeave: false)
    }

    /// Removes a roster member by id (commissioner only). Used from roster ellipsis menu.
    func removeMember(_ member: SeriesMember) async {
        guard isCommissioner else { return }
        guard member.role != .commissioner else { return }
        guard let index = members.firstIndex(where: { $0.id == member.id && $0.isActive }) else { return }
        await removeActiveMember(at: index, fallbackPlayerID: member.playerID ?? "", selfInitiatedLeave: false)
    }

    /// Self-removal for non-commissioner members. Historical data is preserved.
    func leaveLeague() async {
        guard !isCommissioner else { return }
        guard let playerID = currentPlayerID,
              let index = members.firstIndex(where: { $0.playerID == playerID && $0.isActive }) else { return }
        await removeActiveMember(at: index, fallbackPlayerID: playerID, selfInitiatedLeave: true)
    }

    private func removeActiveMember(at index: Int, fallbackPlayerID: String, selfInitiatedLeave: Bool) async {
        let member = members[index]

        let podsToRemove = pods.filter { $0.isActive && $0.memberIDs.contains(member.id) }
        for pod in podsToRemove {
            await deletePod(pod)
        }

        var attendanceToDelete: [SeriesRoundAttendance] = []
        for list in attendanceByRound.values {
            attendanceToDelete.append(contentsOf: list.filter { $0.memberID == member.id })
        }
        for attendance in attendanceToDelete {
            _ = await FirebaseService.shared.deleteSeriesRoundAttendance(attendance)
        }
        for roundID in attendanceByRound.keys {
            attendanceByRound[roundID]?.removeAll { $0.memberID == member.id }
        }
        attendanceByMember.removeValue(forKey: member.id)
        handicapOverrides.removeAll { $0.memberID == member.id }

        switch await FirebaseService.shared.deleteSeriesMember(member) {
        case .success:
            members.remove(at: index)
            let pidToRemove = member.playerID ?? fallbackPlayerID
            if pidToRemove.isPopulated {
                series.memberPlayerIDs.removeAll { $0 == pidToRemove }
                try? await FirebaseService.shared.removePlayerFromSeries(seriesID: seriesID, playerID: pidToRemove)
            }
            memberHandicaps.removeValue(forKey: member.id)
            recomputeAllHandicaps()
            await refreshSeriesCachesIfNeeded()
            addEvent(
                "series.member_removed",
                eventProps: seriesTelemetryProps([
                    "self_initiated_leave": selfInitiatedLeave,
                    "removed_role": member.role.rawValue
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to remove series member", error: error)
        }
    }

    func updateMemberTeeBox(_ member: SeriesMember, teeBoxID: String?) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].defaultTeeBoxID = teeBoxID
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
        addEvent(
            "series.member_tee_updated",
            eventProps: seriesTelemetryProps(["tee_box_id_set": teeBoxID != nil])
        )
    }

    /// Roles the current user may assign to `member` (UI filtering). Commissioner-on-offline remains disabled in views.
    func assignableRoles(for member: SeriesMember) -> [SeriesMemberRole] {
        guard currentMemberID != nil else { return [] }

        if member.id == currentMemberID {
            let effectiveSelf: SeriesMemberRole = isCommissioner ? .commissioner : (currentMemberRecord?.role ?? .member)
            return SeriesMemberRole.allCases.filter { $0.rank <= effectiveSelf.rank }
        }

        if isCommissioner {
            return Array(SeriesMemberRole.allCases)
        }
        if isCaptain {
            return [.captain, .member, .spectator]
        }
        return []
    }

    /// Effective rank used for self role changes (owner counts as commissioner even if row role differs).
    func effectiveSelfRole(for member: SeriesMember) -> SeriesMemberRole? {
        guard member.id == currentMemberID else { return nil }
        return isCommissioner ? .commissioner : (currentMemberRecord?.role ?? member.role)
    }

    /// True when changing own role to a strictly lower rank; show a confirmation first.
    func shouldConfirmSelfRoleChange(member: SeriesMember, to newRole: SeriesMemberRole) -> Bool {
        guard let from = effectiveSelfRole(for: member) else { return false }
        return newRole.rank < from.rank
    }

    func canUpdateMemberRole(_ member: SeriesMember, to role: SeriesMemberRole) -> Bool {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return false }
        if role == .commissioner, members[index].hasLinkedUserID == false { return false }

        let isSelf = member.id == currentMemberID
        if isSelf {
            guard let effective = effectiveSelfRole(for: members[index]) else { return false }
            return role.rank <= effective.rank
        }

        if isCommissioner { return true }
        if isCaptain {
            return [.captain, .member, .spectator].contains(role)
        }
        return false
    }

    func updateMemberRole(_ member: SeriesMember, role: SeriesMemberRole) async {
        guard canUpdateMemberRole(member, to: role) else { return }
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].role = role
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
        addEvent("series.member_role_updated", eventProps: seriesTelemetryProps(["new_role": role.rawValue]))
    }

    func updateMemberTeam(_ member: SeriesMember, teamID: String?) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        let previousTeamID = members[index].teamID
        if previousTeamID != teamID {
            let podsContainingMember = pods.filter { $0.isActive && $0.memberIDs.contains(member.id) }
            for pod in podsContainingMember {
                await deletePod(pod)
            }
        }
        members[index].teamID = teamID
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
        addEvent(
            "series.member_team_updated",
            eventProps: seriesTelemetryProps(["has_team": teamID != nil])
        )
    }

    func updateMemberDisplayName(_ member: SeriesMember, fullName: String) async {
        guard isCommissioner else { return }
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return }
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].name = Name(trimmed)
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
        addEvent("series.member_display_name_updated", eventProps: seriesTelemetryProps())
    }

    /// Clears any fixed pair for `member`, then optionally pairs them with `partnerMemberID` on the same team.
    func setMemberFixedPair(member: SeriesMember, partnerMemberID: String?) async {
        guard isCommissioner else { return }
        guard let teamID = member.teamID else { return }

        for pod in pods.filter({ $0.isActive && $0.memberIDs.contains(member.id) }) {
            await deletePod(pod)
        }

        guard let partnerID = partnerMemberID,
              partnerID != member.id,
              let partner = activeMembers.first(where: { $0.id == partnerID }),
              partner.teamID == teamID
        else { return }

        for pod in pods.filter({ $0.isActive && $0.memberIDs.contains(partnerID) }) {
            await deletePod(pod)
        }

        _ = await createPod(teamID: teamID, memberIDs: [member.id, partnerID])
    }

    // MARK: - Invite Mutations

    func createInvite(for player: Player) async {
        guard let memberID = currentMemberID else { return }
        guard !invites.contains(where: { $0.invitedPlayerID == player.id && $0.status == .pending }) else { return }

        let invite = SeriesInvite(
            id: HackersID.string(),
            seriesID: seriesID,
            invitedUserID: player.userID,
            invitedPlayerID: player.id,
            invitedName: player.name.fullName,
            status: .pending,
            invitedByMemberID: memberID,
            invitedAt: .init(),
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.addSeriesInvite(invite) {
        case .success(let created):
            invites.append(created)
            addEvent("series.invite_created", eventProps: seriesTelemetryProps())
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create series invite", error: error)
        }
    }

    func resolveInvite(_ invite: SeriesInvite, status: SeriesInviteStatus) async {
        guard let index = invites.firstIndex(where: { $0.id == invite.id }) else { return }
        invites[index].status = status
        invites[index].respondedAt = .init()
        _ = await FirebaseService.shared.updateSeriesInvite(invites[index])
        addEvent(
            "series.invite_resolved",
            eventProps: seriesTelemetryProps(["status": status.rawValue])
        )
    }

    // MARK: - Team + Pod Mutations

    func createDefaultTeams() async {
        guard teams.isEmpty else { return }
        let previousSettings = series.settings
        series.settings.useTeams = true
        series.settings.useTeamStandings = true
        series.settings.defaultRoundConfig.teamAssignmentMode = .seriesTeams
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
        _ = await FirebaseService.shared.updateSeries(series)

        let red = SeriesTeam(
            id: HackersID.string(),
            name: TeamColor.teamValue(for: 0).1,
            color: TeamColor.teamValue(for: 0).0.rawValue,
            index: 0,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        let blue = SeriesTeam(
            id: HackersID.string(),
            name: TeamColor.teamValue(for: 1).1,
            color: TeamColor.teamValue(for: 1).0.rawValue,
            index: 1,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.addSeriesTeam(red) {
        case .success(let team): teams.append(team)
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create default red team", error: error)
            return
        }

        switch await FirebaseService.shared.addSeriesTeam(blue) {
        case .success(let team): teams.append(team)
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create default blue team", error: error)
            return
        }

        await refreshSeriesCachesIfNeeded()
        addEvent("series.default_teams_created", eventProps: seriesTelemetryProps(["team_count": teams.count]))
    }

    /// - Parameters:
    ///   - presetColorKey: `TeamColor` raw value used when no custom hex is set.
    ///   - customColorHex: Optional `#RRGGBB` / `RRGGBB` override stored as `custom_color_hex` in Firestore.
    func createTeam(name: String, presetColorKey: String, customColorHex: String?) async -> SeriesTeam? {
        let hex = Self.normalizedSeriesTeamCustomHex(customColorHex)
        let team = SeriesTeam(
            id: HackersID.string(),
            name: name,
            color: presetColorKey,
            customColorHex: hex,
            index: teams.nextIndex,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesTeam(team) {
        case .success(let created):
            teams.append(created)
            let previousSettings = series.settings
            series.settings.useTeams = true
            series.settings.useTeamStandings = true
            series.settings.defaultRoundConfig.teamAssignmentMode = .seriesTeams
            invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
            _ = await FirebaseService.shared.updateSeries(series)
            addEvent("series.team_created", eventProps: seriesTelemetryProps(["team_id": created.id]))
            return created
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create team", error: error)
            return nil
        }
    }

    func updateTeam(_ team: SeriesTeam, name: String, presetColorKey: String, customColorHex: String?) async {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else { return }
        teams[index].name = name
        teams[index].color = presetColorKey
        teams[index].customColorHex = Self.normalizedSeriesTeamCustomHex(customColorHex)
        teams[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesTeam(teams[index])
        addEvent("series.team_updated", eventProps: seriesTelemetryProps(["team_id": team.id]))
    }

    private static func normalizedSeriesTeamCustomHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isPopulated else { return nil }
        if !t.hasPrefix("#") { t = "#\(t)" }
        let digits = t.dropFirst().filter(\.isHexDigit)
        guard digits.count == 3 || digits.count == 6 else { return nil }
        return "#\(String(digits).uppercased())"
    }

    func deleteTeam(_ team: SeriesTeam) async {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else { return }

        let dependentPods = pods.filter { $0.teamID == team.id }
        for pod in dependentPods {
            _ = await FirebaseService.shared.deleteSeriesPod(pod)
        }
        pods.removeAll { $0.teamID == team.id }

        for memberIndex in members.indices where members[memberIndex].teamID == team.id {
            members[memberIndex].teamID = nil
            members[memberIndex].lastUpdatedAt = .init()
            _ = await FirebaseService.shared.updateSeriesMember(members[memberIndex])
        }

        let target = teams[index]
        teams.remove(at: index)
        _ = await FirebaseService.shared.deleteSeriesTeam(target)
        addEvent("series.team_deleted", eventProps: seriesTelemetryProps(["had_dependent_pods": dependentPods.isPopulated]))

        if teams.isEmpty {
            let previousSettings = series.settings
            series.settings.useTeams = false
            series.settings.useTeamStandings = false
            series.settings.defaultRoundConfig.teamAssignmentMode = .manual
            series.settings.defaultRoundConfig.matchupMode = series.settings.defaultRoundConfig.resolvedCompetitionScope == .matchup
                ? .individualVsIndividual
                : .field
            series.settings.defaultRoundConfig.podGroupingStrategy = .disabled
            invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
            _ = await FirebaseService.shared.updateSeries(series)
        }

        await refreshSeriesCachesIfNeeded()
    }

    func createPod(teamID: String, memberIDs: [String], label: String? = nil) async -> SeriesTeamPod? {
        let cleanedIDs = Array(Set(memberIDs)).sorted()
        guard cleanedIDs.count == 2 else { return nil }
        guard validatePod(teamID: teamID, memberIDs: cleanedIDs) else { return nil }

        let pod = SeriesTeamPod(
            id: HackersID.string(),
            teamID: teamID,
            label: label ?? "",
            index: pods.filter { $0.teamID == teamID }.nextIndex,
            memberIDs: cleanedIDs,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesPod(pod) {
        case .success(let created):
            pods.append(created)
            addEvent(
                "series.pod_created",
                eventProps: seriesTelemetryProps(["team_id": teamID])
            )
            return created
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create team pod", error: error)
            return nil
        }
    }

    func deletePod(_ pod: SeriesTeamPod) async {
        guard let index = pods.firstIndex(where: { $0.id == pod.id }) else { return }
        let target = pods[index]
        pods.remove(at: index)
        _ = await FirebaseService.shared.deleteSeriesPod(target)
        addEvent("series.pod_deleted", eventProps: seriesTelemetryProps(["team_id": target.teamID]))
    }

    // MARK: - Round Mutations

    func addRound(
        title: String,
        scheduledAt: Time? = nil,
        format: GameFormat = .strokePlay
    ) async -> SeriesRound? {
        var defaultConfig = series.settings.defaultRoundConfig
        if format != .strokePlay {
            defaultConfig.formatTemplateID = templateID(for: format)
        }
        return await addRound(
            title: title,
            scheduledAt: scheduledAt,
            courseOverride: nil,
            roundConfig: defaultConfig,
            teamScoringProfileID: series.settings.defaultTeamScoringProfileID,
            individualScoringProfileID: series.settings.defaultIndividualScoringProfileID,
            matchupPlans: [],
            plannedMatchups: [],
            plannedTeeGroups: [],
            partnershipPlans: [],
            notes: nil,
            duplicateSourceSeriesRoundID: nil
        )
    }

    func addRound(
        title: String,
        scheduledAt: Time?,
        courseOverride: SeriesCourseSelection?,
        roundConfig: SeriesRoundConfiguration,
        teamScoringProfileID: String?,
        individualScoringProfileID: String?,
        matchupPlans: [SeriesRoundMatchupPlan],
        plannedMatchups: [SeriesRoundPlannedMatchup],
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup],
        partnershipPlans: [SeriesRoundPartnershipPlan] = [],
        notes: String?,
        duplicateSourceSeriesRoundID: String? = nil
    ) async -> SeriesRound? {
        let roundCourse = courseOverride ?? resolvedDefaultCourseSelection(forRoundIndex: rounds.nextIndex)
        let round = SeriesRound(
            id: HackersID.string(),
            title: title,
            index: rounds.nextIndex,
            status: .planned,
            scheduledAt: scheduledAt,
            courseOverride: roundCourse,
            roundConfig: roundConfig,
            teamScoringProfileID: teamScoringProfileID,
            individualScoringProfileID: individualScoringProfileID,
            matchupPlans: matchupPlans.sorted { $0.index < $1.index },
            plannedMatchups: plannedMatchups,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: partnershipPlans,
            notes: notes,
            awardsStatus: .pending,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.addSeriesRound(round) {
        case .success(let created):
            rounds.append(created)
            await seedAttendance(for: created)
            await refreshSeriesCachesIfNeeded()
            if let sourceID = duplicateSourceSeriesRoundID {
                addEvent(
                    "series.round_duplicated",
                    eventProps: seriesTelemetryProps([
                        "source_series_round_id": sourceID,
                        "new_series_round_id": created.id
                    ])
                )
            } else {
                addEvent(
                    "series.round_added",
                    eventProps: seriesTelemetryProps([
                        "series_round_id": created.id,
                        "round_index": created.index
                    ])
                )
            }
            return created
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add series round", error: error)
            return nil
        }
    }

    func updateSeriesRound(
        _ round: SeriesRound,
        title: String? = nil,
        scheduledAt: Time? = nil,
        courseOverride: SeriesCourseSelection? = nil,
        shouldUpdateCourseOverride: Bool = false,
        roundConfig: SeriesRoundConfiguration? = nil,
        teamScoringProfileID: String? = nil,
        individualScoringProfileID: String? = nil,
        matchupPlans: [SeriesRoundMatchupPlan]? = nil,
        plannedMatchups: [SeriesRoundPlannedMatchup]? = nil,
        plannedTeeGroups: [SeriesRoundPlannedTeeGroup]? = nil,
        partnershipPlans: [SeriesRoundPartnershipPlan]? = nil,
        notes: String? = nil
    ) async {
        guard let index = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        let previousRound = rounds[index]
        if let title { rounds[index].title = title }
        rounds[index].scheduledAt = scheduledAt
        if let roundConfig {
            var sanitizedRoundConfig = roundConfig
            sanitizedRoundConfig.excludedHandicapMemberIDs = roundConfig.normalizedExcludedHandicapMemberIDs
            rounds[index].roundConfig = sanitizedRoundConfig
        }
        if let matchupPlans { rounds[index].matchupPlans = matchupPlans.sorted { $0.index < $1.index } }
        if let plannedMatchups { rounds[index].plannedMatchups = plannedMatchups }
        if let plannedTeeGroups { rounds[index].plannedTeeGroups = plannedTeeGroups }
        if let partnershipPlans { rounds[index].partnershipPlans = partnershipPlans }
        if let notes { rounds[index].notes = notes }
        if shouldUpdateCourseOverride {
            rounds[index].courseOverride = courseOverride
        }
        rounds[index].teamScoringProfileID = teamScoringProfileID
        rounds[index].individualScoringProfileID = individualScoringProfileID
        rounds[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesRound(rounds[index])

        let updatedRound = rounds[index]
        let handicapSettingsChanged =
            previousRound.roundConfig.countsTowardHandicapPool != updatedRound.roundConfig.countsTowardHandicapPool
            || previousRound.roundConfig.normalizedExcludedHandicapMemberIDs != updatedRound.roundConfig.normalizedExcludedHandicapMemberIDs
            || previousRound.roundConfig.formatTemplateID != updatedRound.roundConfig.formatTemplateID

        let awardRelevantChanged =
            previousRound.roundConfig != updatedRound.roundConfig
            || previousRound.teamScoringProfileID != updatedRound.teamScoringProfileID
            || previousRound.individualScoringProfileID != updatedRound.individualScoringProfileID
            || previousRound.matchupPlans != updatedRound.matchupPlans
            || previousRound.partnershipPlans != updatedRound.partnershipPlans

        let roundIsComplete = effectiveStatus(for: updatedRound) == .complete || updatedRound.status == .complete
        let shouldReprocessCompleteRound = roundIsComplete
            && updatedRound.roundID != nil
            && (handicapSettingsChanged || awardRelevantChanged)

        if shouldReprocessCompleteRound,
           let roundID = updatedRound.roundID,
           let snapshot = await loadRoundSnapshot(roundID: roundID) {
            let _ = await processCompletedRound(
                seriesRound: updatedRound,
                snapshot: snapshot,
                overwriteDerivedData: true
            )
            if handicapSettingsChanged {
                handicapScores = await FirebaseService.shared.fetchHandicapScores(seriesID: seriesID)
                recomputeAllHandicaps()
            }
        }
        addEvent(
            "series.round_updated",
            eventProps: seriesTelemetryProps(["series_round_id": round.id])
        )
    }

    func duplicateRound(_ source: SeriesRound) async -> SeriesRound? {
        await addRound(
            title: source.title.isPopulated ? "\(source.title) (copy)" : "Round \(rounds.nextIndex + 1)",
            scheduledAt: source.scheduledAt,
            courseOverride: source.courseOverride,
            roundConfig: source.roundConfig,
            teamScoringProfileID: source.teamScoringProfileID,
            individualScoringProfileID: source.individualScoringProfileID,
            matchupPlans: source.matchupPlans.map {
                var plan = $0
                plan.id = HackersID.string()
                plan.createdAt = .init()
                plan.lastUpdatedAt = .init()
                return plan
            },
            plannedMatchups: source.plannedMatchups.map {
                var updated = $0
                var plan = updated.matchupPlan
                plan.id = HackersID.string()
                plan.createdAt = .init()
                plan.lastUpdatedAt = .init()
                updated.id = plan.id
                updated.plan = plan
                return updated
            },
            plannedTeeGroups: source.plannedTeeGroups,
            partnershipPlans: source.partnershipPlans.map {
                var plan = $0
                plan.id = HackersID.string()
                plan.createdAt = .init()
                plan.lastUpdatedAt = .init()
                return plan
            },
            notes: source.notes,
            duplicateSourceSeriesRoundID: source.id
        )
    }

    func deleteScheduledRound(_ round: SeriesRound) async {
        guard let index = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        let attendance = attendanceByRound[round.id] ?? []
        for item in attendance {
            _ = await FirebaseService.shared.deleteSeriesRoundAttendance(item)
        }
        attendanceByRound[round.id] = nil
        rounds.remove(at: index)
        _ = await FirebaseService.shared.deleteSeriesRound(round)
        await refreshSeriesCachesIfNeeded()
        addEvent(
            "series.round_deleted",
            eventProps: seriesTelemetryProps(["series_round_id": round.id])
        )
    }

    func cancelRound(_ round: SeriesRound) async {
        guard let index = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        rounds[index].status = .canceled
        rounds[index].lastUpdatedAt = .init()
        if let roundID = rounds[index].roundID,
           var linked = linkedRounds[roundID],
           linked.status != .complete {
            linked.status = .archived
            _ = await linked.put()
            linkedRounds[roundID] = linked
        }
        _ = await FirebaseService.shared.updateSeriesRound(rounds[index])
        await refreshSeriesCachesIfNeeded()
        addEvent(
            "series.round_canceled",
            eventProps: seriesTelemetryProps(["series_round_id": round.id])
        )
    }

    func attendanceCounts(for seriesRoundID: String) -> (playing: Int, declined: Int, noResponse: Int) {
        let list = attendanceByRound[seriesRoundID] ?? []
        let playing = list.filter { $0.status == SeriesRoundAttendanceStatus.accepted.rawValue }.count
        let declined = list.filter { $0.status == SeriesRoundAttendanceStatus.no.rawValue }.count
        let noResponse = max(0, eligibleMembers.count - playing - declined)
        return (playing, declined, noResponse)
    }

    func currentAttendanceStatus(for seriesRoundID: String) -> SeriesRoundAttendanceStatus {
        guard let memberID = currentMemberID,
              let attendance = attendanceByRound[seriesRoundID]?.first(where: { $0.memberID == memberID }),
              let status = SeriesRoundAttendanceStatus(rawValue: attendance.status) else {
            return series.settings.attendanceDefault
        }
        return status
    }

    /// Whether the current user may change RSVP for someone else (commissioner: eligible roster; captain: same team).
    func canProxyRSVP(for member: SeriesMember) -> Bool {
        guard let selfID = currentMemberID, member.id != selfID else { return false }
        if isCommissioner {
            return eligibleMembers.contains { $0.id == member.id }
        }
        if isCaptain {
            guard let myTeam = currentMemberRecord?.teamID,
                  let theirTeam = member.teamID,
                  myTeam == theirTeam else { return false }
            return activeMembers.contains { $0.id == member.id }
        }
        return false
    }

    func updateAttendance(
        seriesRoundID: String,
        memberID: String,
        status: SeriesRoundAttendanceStatus,
        declinedNote: String?
    ) async {
        guard let seriesRound = rounds.first(where: { $0.id == seriesRoundID }),
              isRSVPEligible(for: seriesRound) else { return }

        if memberID != currentMemberID {
            guard let target = activeMembers.first(where: { $0.id == memberID }),
                  canProxyRSVP(for: target) else { return }
        }

        let existing = attendanceByRound[seriesRoundID]?.first(where: { $0.memberID == memberID })
        let attendance = SeriesRoundAttendance(
            id: SeriesRoundAttendance.documentID(seriesRoundID: seriesRoundID, memberID: memberID),
            seriesRoundID: seriesRoundID,
            memberID: memberID,
            status: status.rawValue,
            declinedNote: declinedNote,
            createdAt: existing?.createdAt ?? .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.upsertSeriesRoundAttendance(attendance) {
        case .success(let saved):
            var roundAttendance = attendanceByRound[seriesRoundID] ?? []
            if let index = roundAttendance.firstIndex(where: { $0.memberID == memberID }) {
                roundAttendance[index] = saved
            } else {
                roundAttendance.append(saved)
            }
            attendanceByRound[seriesRoundID] = roundAttendance
            attendanceByMember[memberID] = saved
            await applyLobbyAttendanceChangeIfNeeded(seriesRoundID: seriesRoundID)
            addEvent(
                "series.attendance_updated",
                eventProps: seriesTelemetryProps([
                    "series_round_id": seriesRoundID,
                    "status": status.rawValue,
                    "is_proxy_rsvp": memberID != currentMemberID
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to update attendance", error: error)
        }
    }

    private func applyLobbyAttendanceChangeIfNeeded(seriesRoundID: String) async {
        guard let seriesRound = rounds.first(where: { $0.id == seriesRoundID }),
              isRSVPEligible(for: seriesRound),
              let roundID = seriesRound.roundID,
              let linked = linkedRounds[roundID],
              linked.status == .lobby,
              let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return
        }

        let attendance = attendanceByRound[seriesRoundID] ?? []
        let attendanceByMemberID = Dictionary(uniqueKeysWithValues: attendance.map { ($0.memberID, $0) })
        let participatingMembers = eligibleMembers.filter { member in
            guard let attendance = attendanceByMemberID[member.id],
                  let resolved = SeriesRoundAttendanceStatus(rawValue: attendance.status) else {
                return series.settings.attendanceDefault != .no
            }
            return resolved == .accepted || resolved == .pending
        }
        let presenceStatusByMemberID = Dictionary(uniqueKeysWithValues: participatingMembers.map { member in
            let resolvedStatus: RoundParticipantPresenceStatus
            if let attendance = attendanceByMemberID[member.id],
               attendance.status == SeriesRoundAttendanceStatus.pending.rawValue {
                resolvedStatus = .unconfirmed
            } else if attendanceByMemberID[member.id] == nil,
                      series.settings.attendanceDefault == .pending {
                resolvedStatus = .unconfirmed
            } else {
                resolvedStatus = .active
            }
            return (member.id, resolvedStatus)
        })

        let mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRoundID
        )
        let hostPlayerID = await AppData.shared.getPrimaryPlayer()?.id

        do {
            let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
                series: series,
                seriesRound: seriesRound,
                participatingMembers: participatingMembers,
                teams: teams,
                pods: pods,
                handicaps: memberHandicaps,
                seriesMappings: mappings,
                snapshot: snapshot,
                hostPlayerID: hostPlayerID,
                presenceStatusByMemberID: presenceStatusByMemberID
            )
            try await applyLobbyAttendancePlan(plan)
            await refreshLinkedRoundState()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to apply lobby RSVP rebuild", error: error)
        }
    }

    private func applyLobbyAttendancePlan(_ plan: SeriesRoundSyncPlanning.LobbyAttendancePlan) async throws {
        _ = try await plan.round.put().get()
        for item in plan.teeGroupsToDelete {
            _ = try await item.delete().get()
        }
        for item in plan.teamsToDelete {
            _ = try await item.delete().get()
        }
        for item in plan.scoringGroupsToDelete {
            _ = try await item.delete().get()
        }
        for item in plan.participantsToDelete {
            _ = try await item.delete().get()
        }
        for item in plan.mappingsToDelete {
            _ = try await item.delete().get()
        }
        try await putSubcollectionItems(plan.teeGroupsToPut)
        try await putSubcollectionItems(plan.teamsToPut)
        try await putSubcollectionItems(plan.participantsToPut)
        try await putSubcollectionItems(plan.scoringGroupsToPut)
        try await putSubcollectionItems(plan.mappingsToPut)
        _ = try await plan.segment.put().get()
    }

    private func putSubcollectionItems<T: FirebaseSubcollectable>(_ items: [T]) async throws {
        guard items.isPopulated else { return }
        _ = try await items.batchPut().get()
    }

    private func seedAttendance(for round: SeriesRound) async {
        guard series.settings.isAttendanceEnabled else { return }
        guard eligibleMembers.isPopulated else { return }
        var seeded: [SeriesRoundAttendance] = []
        for member in eligibleMembers {
            let attendance = SeriesRoundAttendance(
                id: SeriesRoundAttendance.documentID(seriesRoundID: round.id, memberID: member.id),
                seriesRoundID: round.id,
                memberID: member.id,
                status: series.settings.attendanceDefault.rawValue,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
            switch await FirebaseService.shared.upsertSeriesRoundAttendance(attendance) {
            case .success(let saved):
                seeded.append(saved)
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to seed attendance", error: error)
            }
        }
        attendanceByRound[round.id] = seeded
    }

    private func seedAttendanceForFutureRounds(memberID: String) async {
        guard series.settings.isAttendanceEnabled else { return }
        for round in rounds where effectiveStatus(for: round) == .planned {
            let attendance = SeriesRoundAttendance(
                id: SeriesRoundAttendance.documentID(seriesRoundID: round.id, memberID: memberID),
                seriesRoundID: round.id,
                memberID: memberID,
                status: series.settings.attendanceDefault.rawValue,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
            switch await FirebaseService.shared.upsertSeriesRoundAttendance(attendance) {
            case .success(let saved):
                var current = attendanceByRound[round.id] ?? []
                current.append(saved)
                attendanceByRound[round.id] = current
            case .failure:
                break
            }
        }
    }

    // MARK: - Scoring Profiles

    func createBuiltInScoringProfilesIfNeeded() async {
        guard scoringProfiles.isEmpty else { return }

        let profiles = [
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Team WLT",
                summary: "Award win, tie, and loss points from team matchup results.",
                outcomeSource: .roundMatchResult,
                competitorType: .team,
                kind: .winTieLoss,
                tieHandling: .splitPoints,
                placementRules: [],
                resultPoints: .init(winPoints: 1, tiePoints: 0.5, lossPoints: 0),
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Individual WLT",
                summary: "Award win, tie, and loss points from individual matchup results.",
                outcomeSource: .roundMatchResult,
                competitorType: .member,
                kind: .winTieLoss,
                tieHandling: .splitPoints,
                placementRules: [],
                resultPoints: .init(winPoints: 1, tiePoints: 0.5, lossPoints: 0),
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Team Placement",
                summary: "Award points from team leaderboard placements.",
                outcomeSource: .roundTeamLeaderboard,
                competitorType: .team,
                kind: .placement,
                tieHandling: .splitPoints,
                placementRules: [
                    .init(id: HackersID.string(), rankStart: 1, rankEnd: 1, points: 3),
                    .init(id: HackersID.string(), rankStart: 2, rankEnd: 2, points: 1),
                    .init(id: HackersID.string(), rankStart: 3, rankEnd: 3, points: 0.5)
                ],
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Accrue from Individual",
                summary: "Sum awarded individual round points into team standings for this round.",
                outcomeSource: .individualAwardsAggregateToTeam,
                competitorType: .team,
                kind: .accrueFromIndividual,
                tieHandling: .splitPoints,
                placementRules: [],
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Individual Placement",
                summary: "Award points from individual leaderboard placements.",
                outcomeSource: .roundIndividualLeaderboard,
                competitorType: .member,
                kind: .placement,
                tieHandling: .splitPoints,
                placementRules: [
                    .init(id: HackersID.string(), rankStart: 1, rankEnd: 1, points: 3),
                    .init(id: HackersID.string(), rankStart: 2, rankEnd: 2, points: 2),
                    .init(id: HackersID.string(), rankStart: 3, rankEnd: 3, points: 1)
                ],
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Manual Team",
                summary: "Commissioner manually allocates team series points.",
                outcomeSource: .manual,
                competitorType: .team,
                kind: .manual,
                tieHandling: .commissionerDecision,
                placementRules: [],
                parentID: seriesID
            ),
            SeriesScoringProfile(
                id: HackersID.string(),
                name: "Manual Individual",
                summary: "Commissioner manually allocates individual series points.",
                outcomeSource: .manual,
                competitorType: .member,
                kind: .manual,
                tieHandling: .commissionerDecision,
                placementRules: [],
                parentID: seriesID
            )
        ]

        var profilesCreated = 0
        for profile in profiles {
            switch await FirebaseService.shared.addScoringProfile(profile) {
            case .success(let created):
                scoringProfiles.append(created)
                profilesCreated += 1
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to create built-in series scoring profile", error: error)
            }
        }

        let previousSettings = series.settings
        if let teamProfile = scoringProfiles.first(where: { $0.kind == .placement && $0.competitorType == .team }) {
            series.settings.defaultTeamScoringProfileID = teamProfile.id
        }
        if let individualProfile = scoringProfiles.first(where: { $0.kind == .placement && $0.competitorType == .member }) {
            series.settings.defaultIndividualScoringProfileID = individualProfile.id
        }
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
        _ = await FirebaseService.shared.updateSeries(series)
        if profilesCreated > 0 {
            addEvent(
                "series.built_in_scoring_profiles_seeded",
                eventProps: seriesTelemetryProps(["profile_count": profilesCreated])
            )
        }
    }

    func createMatchupScoringProfile() async -> SeriesScoringProfile? {
        await createBuiltInScoringProfilesIfNeeded()
        return scoringProfiles.first(where: { $0.kind == .winTieLoss && $0.outcomeSource == .roundMatchResult && $0.competitorType == .team })
    }

    func ensureMirrorTeeGroupTeamScoringProfile() async -> SeriesScoringProfile? {
        await createBuiltInScoringProfilesIfNeeded()
        if let existing = scoringProfiles.first(where: { profile in
            profile.kind == .winTieLoss
                && profile.outcomeSource == .roundMatchResult
                && profile.competitorType == .team
                && profile.resultPoints?.winPoints == 40
                && profile.resultPoints?.tiePoints == 20
                && profile.resultPoints?.lossPoints == 0
        }) {
            return existing
        }

        let profile = SeriesScoringProfile(
            id: HackersID.string(),
            name: "Team WLT 40",
            summary: "Each group matchup is worth 40 points; ties split 20/20.",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            tieHandling: .splitPoints,
            placementRules: [],
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0),
            parentID: seriesID
        )
        return await saveScoringProfile(profile)
    }

    @discardableResult
    func saveScoringProfile(_ profile: SeriesScoringProfile) async -> SeriesScoringProfile? {
        if scoringProfiles.contains(where: { $0.id == profile.id }) {
            switch await FirebaseService.shared.updateScoringProfile(profile) {
            case .success(let updated):
                if let index = scoringProfiles.firstIndex(where: { $0.id == updated.id }) {
                    scoringProfiles[index] = updated
                }
                addEvent(
                    "series.scoring_profile_saved",
                    eventProps: seriesTelemetryProps([
                        "profile_id": updated.id,
                        "is_new": false,
                        "profile_kind": updated.kind.rawValue
                    ])
                )
                return updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to update scoring profile", error: error)
                return nil
            }
        }

        switch await FirebaseService.shared.addScoringProfile(profile) {
        case .success(let created):
            scoringProfiles.append(created)
            addEvent(
                "series.scoring_profile_saved",
                eventProps: seriesTelemetryProps([
                    "profile_id": created.id,
                    "is_new": true,
                    "profile_kind": created.kind.rawValue
                ])
            )
            return created
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create scoring profile", error: error)
            return nil
        }
    }

    func updateSeriesRound(
        _ round: SeriesRound,
        title: String?,
        scheduledAt: Time?,
        scoringProfileID: String?
    ) async {
        let profile = scoringProfile(id: scoringProfileID)
        let teamProfileID = profile?.competitorType == .team ? profile?.id : round.teamScoringProfileID
        let individualProfileID = profile?.competitorType == .member ? profile?.id : round.individualScoringProfileID
        await updateSeriesRound(
            round,
            title: title,
            scheduledAt: scheduledAt,
            roundConfig: nil,
            teamScoringProfileID: teamProfileID,
            individualScoringProfileID: individualProfileID,
            matchupPlans: nil,
            plannedMatchups: nil,
            plannedTeeGroups: nil,
            notes: nil
        )
    }

    // MARK: - Handicap

    func recomputeAllHandicaps() {
        memberHandicaps = Dictionary(uniqueKeysWithValues: eligibleMembers.map { ($0.id, SeriesMemberHandicap(id: $0.id, memberID: $0.id)) })
        memberHandicapScoreSelections = [:]

        guard series.handicapConfig.isEnabled else { return }
        let config = series.handicapConfig.config.toConfig()
        let overridesByMember = Dictionary(uniqueKeysWithValues: handicapOverrides.map { ($0.memberID, $0) })

        var selections: [String: (poolIDs: Set<String>, countingIDs: Set<String>)] = [:]

        for member in eligibleMembers {
            let samples: [HandicapScoreSample] = handicapScores
                .filter { $0.memberID == member.id && $0.countsTowardHandicapIndex }
                .map {
                    HandicapScoreSample(
                        id: $0.id,
                        gross: handicapGrossForIndex($0, config: config),
                        recordedAt: $0.recordedAt,
                        sortOrder: $0.sortOrder
                    )
                }

            let result = computeHandicapIndex(samples: samples, config: config)
            let override = overridesByMember[member.id]
            memberHandicaps[member.id] = SeriesMemberHandicap(
                id: member.id,
                memberID: member.id,
                computedIndex: result?.handicapIndex,
                overrideIndex: override?.overrideIndex,
                isOverridden: override?.isEnabled == true
            )
            if let result {
                selections[member.id] = (result.poolSampleIDs, result.selectedSampleIDs)
            } else {
                selections[member.id] = ([], [])
            }
        }

        memberHandicapScoreSelections = selections
    }

    private func handicapGrossForIndex(_ score: SeriesHandicapScore, config: HandicapComputationConfig) -> Double {
        if score.source == .baseline, score.baselineStrokeBasis == .eighteenHole {
            return normalizedBaselineGrossForHandicapIndex(
                gross: score.score,
                par: score.par,
                defaultParForIndex: config.defaultParForIndex
            ) ?? score.score
        }

        guard config.usesCourseRatingSlopeAdjustment, score.source == .round else { return score.score }
        guard let rating = score.courseRating,
              let slope = score.courseSlope,
              let normalized = normalizedGrossForHandicapIndex(
                gross: score.score,
                rating: rating,
                slope: slope,
                defaultParForIndex: config.defaultParForIndex
              ) else {
            return score.score
        }
        return normalized
    }

    func handicapScoreAdjustmentSubtitle(for score: SeriesHandicapScore) -> String? {
        guard series.handicapConfig.isEnabled else { return nil }
        let config = series.handicapConfig.config.toConfig()
        guard config.usesCourseRatingSlopeAdjustment, score.source == .round else { return nil }
        guard let rating = score.courseRating,
              let slope = score.courseSlope,
              let normalized = normalizedGrossForHandicapIndex(
                gross: score.score,
                rating: rating,
                slope: slope,
                defaultParForIndex: config.defaultParForIndex
              ) else {
            return nil
        }

        let teeName: String? = {
            guard let roundID = score.sourceRoundID,
                  let teeBoxID = score.teeBoxID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  teeBoxID.isPopulated else { return nil }
            return linkedRounds[roundID]?.configuration.courses.first?.tee(from: teeBoxID)?.name
        }()

        let ratingSlope = "\(String(format: "%.1f", rating)) / \(slope)"
        let context = teeName?.isPopulated == true ? "\(teeName!), \(ratingSlope)" : ratingSlope

        if context.isPopulated {
            return "Adjusted \(String(format: "%.1f", normalized)) from \(Int(score.score)) (\(context))"
        }
        return "Adjusted \(String(format: "%.1f", normalized)) from \(Int(score.score))"
    }

    func setHandicapOverride(memberID: String, value: Double?, isOverridden: Bool) async {
        let override = SeriesHandicapOverride(
            id: memberID,
            memberID: memberID,
            overrideIndex: value,
            isEnabled: isOverridden && value != nil,
            createdAt: handicapOverrides.first(where: { $0.memberID == memberID })?.createdAt ?? .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.upsertHandicapOverride(override) {
        case .success(let saved):
            if let index = handicapOverrides.firstIndex(where: { $0.memberID == memberID }) {
                handicapOverrides[index] = saved
            } else {
                handicapOverrides.append(saved)
            }
            recomputeAllHandicaps()
            addEvent(
                "series.handicap_override_saved",
                eventProps: seriesTelemetryProps([
                    "is_overridden": saved.isEnabled,
                    "has_value": saved.overrideIndex != nil
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to save handicap override", error: error)
        }
    }

    func addBaselineScore(memberID: String, score: Double, par: Double = 36, segment: HoleSegment = .front9) async {
        await addHandicapScore(
            memberID: memberID,
            score: score,
            par: par,
            segment: segment,
            source: .baseline,
            sourceRoundID: nil,
            caption: nil,
            recordedAt: nil
        )
    }

    /// Adds a handicap history row. For `source == .round`, `sourceRoundID` must be the **live** round id (`SeriesRound.roundID`).
    func addHandicapScore(
        memberID: String,
        score: Double,
        par: Double,
        segment: HoleSegment,
        source: SeriesHandicapScoreSourceType,
        sourceRoundID: String?,
        caption: String?,
        recordedAt: Time?
    ) async {
        guard isCommissioner else {
            addBreadcrumb(level: .warning, message: "Ignoring handicap score add for non-commissioner")
            return
        }
        if source == .round, let rid = sourceRoundID, rid.isPopulated {
            if handicapScores.contains(where: { $0.memberID == memberID && $0.source == .round && $0.sourceRoundID == rid }) {
                addBreadcrumb(level: .warning, message: "Skipping duplicate round handicap score for member \(memberID) round \(rid)")
                return
            }
        }

        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCaption = trimmedCaption.isPopulated ? trimmedCaption : nil
        let now = Time(for: Date())
        let resolvedRecorded: Time = {
            if let recordedAt { return recordedAt }
            if source == .round, let rid = sourceRoundID, rid.isPopulated,
               let sr = seriesRound(forLiveRoundID: rid) {
                return sr.handicapScoreRecordedAt
            }
            return now
        }()
        let roundMetadata = await handicapRoundMetadata(memberID: memberID, roundID: sourceRoundID)

        let sortOrder = nextHandicapSortOrder(for: memberID)
        let countsToward: Bool = {
            guard source == .round, let rid = sourceRoundID, rid.isPopulated,
                  let sr = seriesRound(forLiveRoundID: rid) else { return true }
            let excluded = Set(sr.roundConfig.normalizedExcludedHandicapMemberIDs).contains(memberID)
            return shouldAccrueLeagueHandicap(for: sr, snapshot: nil) && !excluded
        }()

        let entry = SeriesHandicapScore(
            id: HackersID.string(),
            memberID: memberID,
            score: score,
            par: par,
            holeSegment: segment,
            teeBoxID: roundMetadata?.teeBoxID,
            courseRating: roundMetadata?.courseRating,
            courseSlope: roundMetadata?.courseSlope,
            source: source,
            sourceRoundID: sourceRoundID,
            caption: resolvedCaption,
            recordedAt: resolvedRecorded,
            sortOrder: sortOrder,
            createdAt: now,
            lastUpdatedAt: now,
            parentID: seriesID,
            countsTowardHandicapIndex: countsToward
        )
        switch await FirebaseService.shared.addHandicapScore(entry) {
        case .success(let saved):
            handicapScores.append(saved)
            recomputeAllHandicaps()
            addEvent(
                "series.handicap_score_added",
                eventProps: seriesTelemetryProps([
                    "source": source.rawValue,
                    "hole_segment": "\(segment)"
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add handicap score", error: error)
        }
    }

    func updateHandicapScoreEntry(_ score: SeriesHandicapScore) async -> Bool {
        guard isCommissioner else {
            addBreadcrumb(level: .warning, message: "Ignoring handicap score update for non-commissioner")
            return false
        }
        var updated = score
        updated.lastUpdatedAt = .init()
        switch await FirebaseService.shared.updateHandicapScore(updated) {
        case .success(let saved):
            if let idx = handicapScores.firstIndex(where: { $0.id == saved.id }) {
                handicapScores[idx] = saved
            }
            recomputeAllHandicaps()
            addEvent(
                "series.handicap_score_updated",
                eventProps: seriesTelemetryProps(["source": saved.source.rawValue])
            )
            return true
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to update handicap score", error: error)
            return false
        }
    }

    func setHandicapScoreCountsTowardIndex(_ score: SeriesHandicapScore, countsToward: Bool) async -> Bool {
        guard isCommissioner else {
            addBreadcrumb(level: .warning, message: "Ignoring handicap score count toggle for non-commissioner")
            return false
        }
        var updated = score
        updated.countsTowardHandicapIndex = countsToward
        updated.lastUpdatedAt = .init()
        return await updateHandicapScoreEntry(updated)
    }

    func deleteHandicapScoreEntry(_ score: SeriesHandicapScore) async -> Bool {
        guard isCommissioner else {
            addBreadcrumb(level: .warning, message: "Ignoring handicap score delete for non-commissioner")
            return false
        }
        switch await FirebaseService.shared.deleteHandicapScore(score) {
        case .success:
            handicapScores.removeAll { $0.id == score.id }
            recomputeAllHandicaps()
            addEvent(
                "series.handicap_score_deleted",
                eventProps: seriesTelemetryProps(["source": score.source.rawValue])
            )
            return true
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to delete handicap score", error: error)
            return false
        }
    }

    func nextHandicapSortOrder(for memberID: String) -> Int {
        let maxOrder = handicapScores.filter { $0.memberID == memberID }.map(\.sortOrder).max() ?? -1
        return maxOrder + 1
    }

    func seriesRound(forLiveRoundID roundID: String) -> SeriesRound? {
        rounds.first { $0.roundID == roundID }
    }

    /// Round participant id for a series member in a loaded snapshot (for commissioner correction UI).
    func preferredRoundParticipantID(seriesMemberID: String, snapshot: RoundSnapshot) -> String? {
        if let match = snapshot.participants.first(where: { $0.seriesMemberID == seriesMemberID }) {
            return match.id
        }
        guard let member = members.first(where: { $0.id == seriesMemberID }),
              let playerID = member.playerID, playerID.isPopulated else { return nil }
        return snapshot.participants.first(where: { $0.playerID == playerID })?.id
    }

    /// Builds hole-level commissioner changes so the player’s total gross matches `targetGross` (uses draft grid overrides when present).
    func commissionerGrossCorrectionChanges(
        context: SeriesRoundCorrectionContext,
        participantID: String,
        targetGross: Int,
        draftScores: [String: Int]
    ) -> [SeriesScoreCorrectionChange]? {
        CommissionerGrossScoreDistributer.correctionChanges(
            holes: context.holes,
            participantID: participantID,
            currentStrokes: { holeNumber in
                let key = "\(participantID)_\(holeNumber)"
                if let draft = draftScores[key] {
                    return draft == 0 ? nil : draft
                }
                return context.entriesByParticipantID[participantID]?[holeNumber]?.strokes
            },
            targetGross: targetGross
        )
    }

    // MARK: - Round Creation

    func createLiveRound(from seriesRound: SeriesRound, courseSegment: CourseSegment? = nil) async -> String? {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == seriesRound.id }) else { return nil }
        creatingRoundID = seriesRound.id
        defer { creatingRoundID = nil }

        let attendancePlan = SeriesRoundCreationMapping.participatingMembersAndPresenceStatuses(
            series: series,
            eligibleMembers: eligibleMembers,
            attendance: attendanceByRound[seriesRound.id] ?? []
        )
        let participants = attendancePlan.members
        let presenceStatusByMemberID = attendancePlan.presenceStatusByMemberID

        if let courseSegment {
            rounds[roundIndex].courseOverride = SeriesCourseSelection(
                courseID: courseSegment.courseInfo.golfCourseApiID.map(String.init) ?? courseSegment.courseInfo.id,
                cachedName: courseSegment.courseInfo.name,
                defaultTeeBoxID: courseSegment.defaultTee ?? "",
                holeSegment: courseSegment.holeSegment
            )
        }

        guard let roundID = await SeriesRoundCreationService().createRoundFromSeries(
            series: series,
            seriesRound: rounds[roundIndex],
            members: participants,
            teams: teams,
            pods: pods,
            handicaps: memberHandicaps,
            presenceStatusByMemberID: presenceStatusByMemberID,
            courseSegment: courseSegment
        ) else {
            return nil
        }

        rounds[roundIndex].roundID = roundID
        rounds[roundIndex].status = .lobby
        rounds[roundIndex].startedAt = .init()
        rounds[roundIndex].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesRound(rounds[roundIndex])

        await loadLinkedRounds()
        await refreshSeriesCachesIfNeeded()
        return roundID
    }

    /// Pushes league-authored player, format, and/or organization state into the linked live round (commissioner).
    func syncLinkedRoundFromSeries(
        seriesRound: SeriesRound,
        options: SeriesRoundSyncOptions
    ) async -> Result<Void, SeriesRoundSyncError> {
        guard let roundID = seriesRound.roundID else { return .failure(.roundNotLinked) }
        guard let linked = linkedRounds[roundID] else { return .failure(.roundNotLinked) }
        guard let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return .failure(.writeFailed("Could not load live round data."))
        }

        let membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        let mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRound.id
        )
        let hostPlayerID = await AppData.shared.getPrimaryPlayer()?.id

        let result = await SeriesRoundSyncService().syncRoundFromSeries(
            series: series,
            seriesRound: seriesRound,
            membersByID: membersByID,
            teams: teams,
            pods: pods,
            handicaps: memberHandicaps,
            seriesMappings: mappings,
            snapshot: snapshot,
            roundStatus: linked.status,
            hostPlayerID: hostPlayerID,
            options: options
        )

        if case .success = result {
            await refreshLinkedRoundState()
        }
        return result
    }

    func refreshLinkedRoundState() async {
        await loadLinkedRounds()
        await syncLinkedRoundState()
        await loadAttendanceForRSVPEligibleRounds()
    }

    private func syncLinkedRoundState() async {
        guard linkedRounds.isPopulated else { return }

        var changedRounds: [SeriesRound] = []
        var didProcessAnyCompleteRoundWithSnapshot = false

        for roundIndex in rounds.indices {
            guard let roundID = rounds[roundIndex].roundID,
                  let linkedRound = linkedRounds[roundID] else { continue }

            let previousStatus = rounds[roundIndex].status
            let newStatus = SeriesRoundStatus(linkedRoundStatus: linkedRound.status)
            var hasChanged = false

            if previousStatus != newStatus {
                rounds[roundIndex].status = newStatus
                hasChanged = true
            }
            if newStatus == .lobby || newStatus == .live {
                if rounds[roundIndex].startedAt == nil {
                    rounds[roundIndex].startedAt = linkedRound.lastUpdatedAt
                    hasChanged = true
                }
            }
            let shouldBackPropagate = shouldUseLinkedRoundConfiguration(
                for: rounds[roundIndex],
                linkedRound: linkedRound
            )
                && (newStatus == .lobby || newStatus == .live || (newStatus == .complete && previousStatus != .complete))
            let shouldProcessCompletedRound = needsCompletedRoundProcessing(
                for: rounds[roundIndex],
                roundID: roundID,
                previousStatus: previousStatus,
                newStatus: newStatus
            )
            let snapshot = shouldBackPropagate || shouldProcessCompletedRound
                ? await loadRoundSnapshot(roundID: roundID)
                : nil

            if let snapshot, shouldBackPropagate {
                let updatedConfig = roundConfig(
                    from: linkedRound,
                    segment: snapshot.roundSegment,
                    fallback: rounds[roundIndex].roundConfig
                )
                if rounds[roundIndex].roundConfig != updatedConfig {
                    rounds[roundIndex].roundConfig = updatedConfig
                    hasChanged = true
                }

                let syncedCourse = courseSelection(from: snapshot.courseSegment)
                if rounds[roundIndex].courseOverride != syncedCourse {
                    rounds[roundIndex].courseOverride = syncedCourse
                    hasChanged = true
                }

                let syncedMatchups = await seriesMatchupPlans(from: snapshot, seriesRound: rounds[roundIndex]) ?? []
                if rounds[roundIndex].matchupPlans != syncedMatchups {
                    rounds[roundIndex].matchupPlans = syncedMatchups
                    hasChanged = true
                }
            }

            if newStatus == .complete {
                if rounds[roundIndex].completedAt == nil {
                    rounds[roundIndex].completedAt = linkedRound.lastUpdatedAt
                    hasChanged = true
                }

                if shouldProcessCompletedRound, let snapshot {
                    let _ = await processCompletedRound(seriesRound: rounds[roundIndex], snapshot: snapshot)
                    didProcessAnyCompleteRoundWithSnapshot = true
                }
            }

            if hasChanged {
                rounds[roundIndex].lastUpdatedAt = .init()
                changedRounds.append(rounds[roundIndex])
            }
        }

        if changedRounds.isPopulated {
            _ = await changedRounds.batchPut()
        }

        if didProcessAnyCompleteRoundWithSnapshot {
            pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
            standings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)
        }

        await refreshSeriesCachesIfNeeded()
    }

    private func needsCompletedRoundProcessing(
        for seriesRound: SeriesRound,
        roundID: String,
        previousStatus: SeriesRoundStatus,
        newStatus: SeriesRoundStatus
    ) -> Bool {
        guard newStatus == .complete else { return false }
        if previousStatus != .complete { return true }

        let needsHandicapRefresh: Bool = {
            guard series.handicapConfig.mode.allowsAccrual else { return false }
            return !handicapScores.contains { $0.source == .round && $0.sourceRoundID == roundID }
        }()

        let hasAssignedAwardProfile =
            scoringProfile(id: seriesRound.teamScoringProfileID) != nil
            || scoringProfile(id: seriesRound.individualScoringProfileID) != nil
        let hasAwardRows = pointAwards.contains { $0.seriesRoundID == seriesRound.id }
        let needsAwardRefresh = hasAssignedAwardProfile
            && seriesRound.awardsStatus == .pending
            && !hasAwardRows

        return needsHandicapRefresh || needsAwardRefresh
    }

    private func processCompletedRound(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        overwriteDerivedData: Bool = false
    ) async -> Bool {
        var changed = false

        let didSyncHandicapScores = await syncRoundHandicapScores(
            seriesRound: seriesRound,
            snapshot: snapshot,
            replacingExisting: overwriteDerivedData
        )
        changed = changed || didSyncHandicapScores

        let awardsState = await finalizeAwardsIfPossible(seriesRound: seriesRound, snapshot: snapshot)
        if let index = rounds.firstIndex(where: { $0.id == seriesRound.id }) {
            if rounds[index].awardsStatus != awardsState {
                rounds[index].awardsStatus = awardsState
                rounds[index].awardsFinalizedAt = awardsState == .finalized ? .init() : nil
                rounds[index].lastUpdatedAt = .init()
                _ = await FirebaseService.shared.updateSeriesRound(rounds[index])
                changed = true
            }
        }
        return changed
    }

    // MARK: - Awards

    private func finalizeAwardsIfPossible(seriesRound: SeriesRound, snapshot: RoundSnapshot) async -> SeriesAwardsStatus {
        let teamProfile = seriesRound.teamScoringProfileID.flatMap { scoringProfile(id: $0) }
        let individualProfile = seriesRound.individualScoringProfileID.flatMap { scoringProfile(id: $0) }

        guard teamProfile != nil || individualProfile != nil else { return .pending }

        let existingAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID, seriesRoundID: seriesRound.id)

        var needsReview = false
        var newAwards: [SeriesPointAward] = []
        var individualAwards: [SeriesPointAward] = []

        if let individualProfile {
            switch await buildAwards(
                seriesRound: seriesRound,
                snapshot: snapshot,
                awardTrack: .individual,
                profile: individualProfile
            ) {
            case .success(let awards):
                individualAwards = awards
                newAwards.append(contentsOf: awards)
            case .needsReview:
                needsReview = true
            }
        }

        if let teamProfile {
            let result: AwardBuildResult
            if teamProfile.kind == .accrueFromIndividual || teamProfile.outcomeSource == .individualAwardsAggregateToTeam {
                result = buildTeamAwardsAccruedFromIndividuals(
                    seriesRound: seriesRound,
                    profile: teamProfile,
                    individualAwards: individualAwards
                )
            } else {
                result = await buildAwards(
                    seriesRound: seriesRound,
                    snapshot: snapshot,
                    awardTrack: .team,
                    profile: teamProfile
                )
            }

            switch result {
            case .success(let awards):
                newAwards.append(contentsOf: awards)
            case .needsReview:
                needsReview = true
            }
        }

        switch await FirebaseService.shared.batchReplacePointAwards(deleting: existingAwards, upserting: newAwards) {
        case .success:
            addEvent(
                "series.automatic_point_awards_replaced",
                eventProps: seriesTelemetryProps([
                    "series_round_id": seriesRound.id,
                    "deleted_award_count": existingAwards.count,
                    "upserted_award_count": newAwards.count
                ])
            )
        case .failure(let error):
            addBreadcrumb(level: .error, message: "batchReplacePointAwards failed", error: error)
        }

        pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        await rebuildStandings()
        return needsReview ? .needsReview : .finalized
    }

    private func buildTeamAwardsAccruedFromIndividuals(
        seriesRound: SeriesRound,
        profile: SeriesScoringProfile,
        individualAwards: [SeriesPointAward]
    ) -> AwardBuildResult {
        guard individualAwards.isPopulated else { return .needsReview }
        let awards = Self.buildAccruedTeamAwards(
            seriesRoundID: seriesRound.id,
            profile: profile,
            individualAwards: individualAwards,
            members: members,
            teams: teams,
            seriesID: seriesID,
            awardedByMemberID: currentMemberID
        )
        return .success(awards)
    }

    static func buildAccruedTeamAwards(
        seriesRoundID: String,
        profile: SeriesScoringProfile,
        individualAwards: [SeriesPointAward],
        members: [SeriesMember],
        teams: [SeriesTeam],
        seriesID: String,
        awardedByMemberID: String?
    ) -> [SeriesPointAward] {
        let teamNameByID = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.name) })
        let teamRows: [(teamID: String, teamName: String, total: Double)] = Dictionary(grouping: individualAwards) { award in
            members.first(where: { $0.id == award.competitorID })?.teamID ?? ""
        }
        .compactMap { teamID, awards -> (String, String, Double)? in
            guard teamID.isPopulated else { return nil }
            let total = awards.reduce(0.0) { partial, award in
                partial + award.totalPoints
            }
            return (teamID, teamNameByID[teamID] ?? "Team", total)
        }

        let sortedRows = teamRows.sorted {
            if $0.total != $1.total {
                return $0.total > $1.total
            }
            return $0.teamName.localizedCaseInsensitiveCompare($1.teamName) == .orderedAscending
        }

        var awards: [SeriesPointAward] = []
        var placement = 1
        var index = 0

        while index < sortedRows.count {
            let total = sortedRows[index].total
            var group: [(teamID: String, teamName: String, total: Double)] = []
            while index < sortedRows.count, sortedRows[index].total == total {
                group.append(sortedRows[index])
                index += 1
            }

            for row in group {
                awards.append(
                    SeriesPointAward(
                        id: "\(seriesRoundID)_team_\(row.teamID)",
                        seriesRoundID: seriesRoundID,
                        awardTrack: .team,
                        competitorType: .team,
                        competitorID: row.teamID,
                        competitorName: row.teamName,
                        profileKind: profile.kind,
                        placement: placement,
                        tieGroupSize: group.count > 1 ? group.count : nil,
                        basePoints: row.total,
                        bonusPoints: 0,
                        totalPoints: row.total,
                        source: .automatic,
                        roundOwnerID: row.teamID,
                        reason: "Accrued from individual awards",
                        awardedByMemberID: awardedByMemberID,
                        awardedAt: .init(),
                        createdAt: .init(),
                        lastUpdatedAt: .init(),
                        parentID: seriesID
                    )
                )
            }

            placement += group.count
        }

        return awards
    }

    private func hasIndividualPlacementAwardsConfigured(_ seriesRound: SeriesRound) -> Bool {
        guard let profileID = seriesRound.individualScoringProfileID,
              let profile = scoringProfile(id: profileID) else { return false }
        return profile.kind == .placement && profile.outcomeSource == .roundIndividualLeaderboard
    }

    func rebuildIndividualPlacementAwardsAndStandings() async -> Bool {
        guard isCommissioner, !isRebuildingIndividualStandings else { return false }

        isRebuildingIndividualStandings = true
        defer { isRebuildingIndividualStandings = false }

        var didChange = false
        for seriesRound in completedRounds where hasIndividualPlacementAwardsConfigured(seriesRound) {
            guard let roundID = seriesRound.roundID,
                  let profileID = seriesRound.individualScoringProfileID,
                  let profile = scoringProfile(id: profileID),
                  let snapshot = await loadRoundSnapshot(roundID: roundID) else {
                continue
            }

            let result = await buildAwards(
                seriesRound: seriesRound,
                snapshot: snapshot,
                awardTrack: .individual,
                profile: profile
            )
            guard case .success(let newIndividualAwards) = result else { continue }

            let existingIndividualAwards = await FirebaseService.shared
                .fetchPointAwards(seriesID: seriesID, seriesRoundID: seriesRound.id)
                .filter { $0.awardTrack == .individual }

            switch await FirebaseService.shared.batchReplacePointAwards(
                deleting: existingIndividualAwards,
                upserting: newIndividualAwards
            ) {
            case .success:
                didChange = didChange || existingIndividualAwards.isPopulated || newIndividualAwards.isPopulated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Individual standings rebuild failed", error: error)
            }
        }

        pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        await rebuildStandings(only: .individual)
        standings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)

        addEvent(
            "series.individual_standings_rebuilt",
            eventProps: seriesTelemetryProps(["changed": didChange])
        )
        return didChange
    }

    private enum AwardBuildResult {
        case success([SeriesPointAward])
        case needsReview
    }

    private func buildAwards(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        awardTrack: SeriesAwardTrack,
        profile: SeriesScoringProfile
    ) async -> AwardBuildResult {
        guard profile.kind != .manual, profile.outcomeSource != .manual else { return .needsReview }
        guard let segment = snapshot.roundSegment ?? snapshot.segments.first else { return .needsReview }
        if profile.kind == .winTieLoss,
           seriesRound.roundConfig.resolvedCompetitionScope != .matchup {
            return .success([])
        }
        if profile.kind == .winTieLoss,
           profile.competitorType == .member,
           snapshot.requiresTeams {
            return .success([])
        }

        let result = scoringResult(from: snapshot, segment: segment)
        let mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRound.id
        )
        let competitors: [AwardCompetitor]

        switch profile.outcomeSource {
        case .roundIndividualLeaderboard:
            competitors = buildIndividualCompetitors(result: result, snapshot: snapshot, mappings: mappings)
        case .roundTeamLeaderboard:
            competitors = buildTeamCompetitors(result: result, snapshot: snapshot, mappings: mappings)
        case .roundMatchResult:
            competitors = buildMatchupCompetitors(
                result: result,
                snapshot: snapshot,
                awardTrack: awardTrack,
                mappings: mappings
            )
        case .individualAwardsAggregateToTeam:
            return .needsReview
        case .manual:
            competitors = []
        }

        guard competitors.isPopulated else { return .success([]) }

        let awards = competitors.compactMap { competitor -> SeriesPointAward? in
            guard let placement = competitor.placement else { return nil }
            let isDirectHolePoints = profile.outcomeSource == .roundMatchResult
                && seriesRound.roundConfig.matchupScoringStyle == .holeByHolePoints
            let basePoints: Double
            if isDirectHolePoints {
                basePoints = competitor.rawScore ?? 0
            } else {
                guard let resolved = resolvePoints(
                    placement: placement,
                    tieGroupSize: competitor.tieGroupSize ?? 1,
                    profile: profile
                ) else {
                    return nil
                }
                basePoints = resolved
            }
            let tieGroupSize = max(1, competitor.tieGroupSize ?? 1)
            let matchWinnerBonus: Double = {
                guard isDirectHolePoints, placement == 1 else { return 0 }
                let bonus = seriesRound.roundConfig.resolvedMatchWinnerBonusPoints
                guard bonus > 0 else { return 0 }
                return tieGroupSize > 1 ? bonus / Double(tieGroupSize) : bonus
            }()
            let bonusPoints = profile.bonusRules
                .filter(\.isEnabled)
                .reduce(0.0) { partial, rule in
                    switch rule.type {
                    case .participation:
                        return partial + rule.points
                    case .manual:
                        return partial
                    }
                } + matchWinnerBonus
            let total = basePoints + bonusPoints
            return SeriesPointAward(
                id: "\(seriesRound.id)_\(awardTrack.rawValue)_\(competitor.competitorID)",
                seriesRoundID: seriesRound.id,
                awardTrack: awardTrack,
                competitorType: competitor.competitorType,
                competitorID: competitor.competitorID,
                competitorName: competitor.competitorName,
                profileKind: profile.kind,
                placement: placement,
                tieGroupSize: competitor.tieGroupSize,
                basePoints: basePoints,
                bonusPoints: bonusPoints,
                totalPoints: total,
                source: .automatic,
                roundOwnerID: competitor.roundOwnerID,
                reason: competitor.reason,
                awardedByMemberID: currentMemberID,
                awardedAt: .init(),
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
        }

        return .success(awards)
    }

    func rebuildStandings() async {
        await rebuildStandings(only: nil)
    }

    private func rebuildStandings(only track: SeriesAwardTrack?) async {
        let awards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        pointAwards = awards
        let existingStandings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)

        let targetAwards = track.map { target in
            awards.filter { $0.awardTrack == target }
        } ?? awards
        let computedForTarget = Self.computedStandings(
            from: targetAwards,
            seriesID: seriesID,
            sort: standingsSort
        )

        let standingsToDelete = track.map { target in
            existingStandings.filter { $0.awardTrack == target }
        } ?? existingStandings
        for standing in standingsToDelete {
            _ = await FirebaseService.shared.deleteStanding(standing)
        }
        for standing in computedForTarget {
            _ = await FirebaseService.shared.updateStanding(standing)
        }

        if let track {
            standings = existingStandings.filter { $0.awardTrack != track } + computedForTarget
        } else {
            standings = computedForTarget
        }

        let eventName = track == .individual
            ? "series.individual_standings_recomputed"
            : "series.standings_recomputed"
        addEvent(
            eventName,
            eventProps: seriesTelemetryProps(["standing_row_count": computedForTarget.count])
        )
    }

    static func computedStandings(
        from awards: [SeriesPointAward],
        seriesID: String,
        sort: (SeriesStanding, SeriesStanding) -> Bool
    ) -> [SeriesStanding] {
        var grouped: [String: SeriesStanding] = [:]
        var roundsCountedByKey: [String: Set<String>] = [:]

        for award in awards {
            let standingID = SeriesStanding.standingID(for: award.awardTrack, competitorID: award.competitorID)
            var standing = grouped[standingID] ?? SeriesStanding(
                id: standingID,
                awardTrack: award.awardTrack,
                competitorType: award.competitorType,
                competitorID: award.competitorID,
                competitorName: award.competitorName,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
            standing.totalPoints += award.totalPoints
            standing.wins += award.placement == 1 ? 1 : 0
            standing.topThrees += (award.placement ?? .max) <= 3 ? 1 : 0
            standing.lastPlacement = award.placement
            if let best = standing.bestPlacement {
                standing.bestPlacement = min(best, award.placement ?? best)
            } else {
                standing.bestPlacement = award.placement
            }
            standing.lastUpdatedAt = .init()
            grouped[standingID] = standing
            roundsCountedByKey[standingID, default: []].insert(award.seriesRoundID)
        }

        for key in grouped.keys {
            grouped[key]?.roundsCounted = roundsCountedByKey[key]?.count ?? 0
        }

        var computedStandings: [SeriesStanding] = []
        for track in SeriesAwardTrack.allCases {
            let sorted = grouped.values
                .filter { $0.awardTrack == track }
                .sorted(by: sort)
            for (index, var standing) in sorted.enumerated() {
                standing.rank = index + 1
                computedStandings.append(standing)
            }
        }
        return computedStandings
    }

    // MARK: - Handicap Ingestion

    private func ingestRoundScores(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        replacingExisting: Bool = false
    ) async -> Bool {
        guard let roundID = seriesRound.roundID else { return false }
        let excludedMemberIDs = Set(seriesRound.roundConfig.normalizedExcludedHandicapMemberIDs)
        let accruesForRound = shouldAccrueLeagueHandicap(for: seriesRound, snapshot: snapshot)

        let teeByParticipant = Dictionary(uniqueKeysWithValues: snapshot.participants.map { participant in
            let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID)
                ?? snapshot.courseSegment?.tee(from: snapshot.courseSegment?.defaultTee ?? "")
                ?? snapshot.courseSegment?.courseInfo.tees.first
            return (participant.id, tee)
        })

        let scoreEntriesByParticipant = Dictionary(grouping: snapshot.scoring, by: \.scoringUnitID)
        var inserted = false
        let deleted = replacingExisting ? await deleteRoundHandicapScores(sourceRoundID: roundID) : false

        var pendingHandicapScores: [SeriesHandicapScore] = []

        for participant in snapshot.participants {
            guard let memberID = participant.seriesMemberID ?? members.first(where: { $0.playerID == participant.playerID })?.id else { continue }
            let excluded = excludedMemberIDs.contains(memberID)
            let countsTowardIndex = accruesForRound && !excluded
            let alreadyIngested = handicapScores.contains {
                $0.memberID == memberID && $0.source == .round && $0.sourceRoundID == roundID
            }
            guard replacingExisting || !alreadyIngested else { continue }

            let entries = scoreEntriesByParticipant[participant.id] ?? []
            let tee = teeByParticipant[participant.id] ?? nil
            let holeNumbers = snapshot.roundSegment?.holeRange.holeNumbers ?? snapshot.holeSegment.holeRange.holeNumbers
            let completeness = RoundScoreCompleteness.classify(
                participantID: participant.id,
                scores: snapshot.scoring,
                holeNumbers: holeNumbers,
                holes: tee?.holes ?? snapshot.defaultTee?.holes ?? [],
                scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs
            )
            guard completeness.isComplete else { continue }

            let holeMap = Dictionary(uniqueKeysWithValues: (tee?.holes ?? snapshot.defaultTee?.holes ?? []).map { ($0.number, $0.par) })
            let total = Double(entries.compactMap { entry in
                guard holeNumbers.contains(entry.holeNumber) else { return nil }
                return RoundScoreCompleteness.validGrossStrokes(entry: entry, par: holeMap[entry.holeNumber])
            }.reduce(0, +))
            let par = Double(tee?.par(for: snapshot.holeSegment) ?? snapshot.courseSegment?.courseInfo.tees.first?.par(for: snapshot.holeSegment) ?? Int(series.handicapConfig.config.defaultParForIndex))
            let resolvedTeeBoxID = participant.teeBoxID.isPopulated ? participant.teeBoxID : tee?.id
            let courseRating = tee?.rating(for: snapshot.holeSegment)
            let courseSlope = tee?.slope(for: snapshot.holeSegment)
            let recordedAt = seriesRound.handicapScoreRecordedAt
            let sortOrder = nextHandicapSortOrder(for: memberID)
            let now = Time(for: Date())
            let score = SeriesHandicapScore(
                id: HackersID.string(),
                memberID: memberID,
                score: total,
                par: par,
                holeSegment: snapshot.holeSegment,
                teeBoxID: resolvedTeeBoxID,
                courseRating: courseRating,
                courseSlope: courseSlope,
                source: .round,
                sourceRoundID: roundID,
                caption: nil,
                recordedAt: recordedAt,
                sortOrder: sortOrder,
                createdAt: now,
                lastUpdatedAt: now,
                parentID: seriesID,
                countsTowardHandicapIndex: countsTowardIndex
            )
            pendingHandicapScores.append(score)
        }

        if pendingHandicapScores.isPopulated {
            switch await pendingHandicapScores.batchPut() {
            case .success(let saved):
                handicapScores.append(contentsOf: saved)
                inserted = true
                addEvent(
                    "series.handicap_scores_ingested_from_round",
                    eventProps: seriesTelemetryProps([
                        "source_round_id": roundID,
                        "rows_ingested": saved.count
                    ])
                )
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to batch ingest series handicap scores", error: error)
            }
        }

        if inserted || deleted {
            recomputeAllHandicaps()
        }
        return inserted || deleted
    }

    private func hydrateRoundHandicapScoreMetadataIfNeeded() async {
        guard series.handicapConfig.isEnabled else { return }
        guard series.handicapConfig.config.usesCourseRatingSlopeAdjustment else { return }
        guard !isHydratingHandicapScoreMetadata else { return }

        let missingScores = handicapScores.filter {
            $0.source == .round
                && $0.sourceRoundID?.isPopulated == true
                && ($0.teeBoxID?.isPopulated != true || $0.courseRating == nil || $0.courseSlope == nil)
        }
        guard missingScores.isPopulated else { return }

        isHydratingHandicapScoreMetadata = true
        defer { isHydratingHandicapScoreMetadata = false }

        let groupedByRoundID = Dictionary(grouping: missingScores, by: { $0.sourceRoundID ?? "" })
        var updates: [SeriesHandicapScore] = []

        for (roundID, scores) in groupedByRoundID where roundID.isPopulated {
            guard let snapshot = await loadRoundSnapshot(roundID: roundID) else { continue }
            for score in scores {
                guard let metadata = handicapRoundMetadata(memberID: score.memberID, snapshot: snapshot) else { continue }
                var updated = score
                updated.teeBoxID = metadata.teeBoxID
                updated.courseRating = metadata.courseRating
                updated.courseSlope = metadata.courseSlope
                updated.lastUpdatedAt = .init()
                updates.append(updated)
            }
        }

        guard updates.isPopulated else { return }

        switch await updates.batchPut() {
        case .success(let saved):
            let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            handicapScores = handicapScores.map { savedByID[$0.id] ?? $0 }
            recomputeAllHandicaps()
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to hydrate handicap score round metadata", error: error)
        }
    }

    private typealias HandicapRoundMetadata = (teeBoxID: String, courseRating: Double, courseSlope: Int)

    private func handicapRoundMetadata(memberID: String, roundID: String?) async -> HandicapRoundMetadata? {
        guard let roundID, roundID.isPopulated,
              let snapshot = await loadRoundSnapshot(roundID: roundID) else { return nil }
        return handicapRoundMetadata(memberID: memberID, snapshot: snapshot)
    }

    private func handicapRoundMetadata(memberID: String, snapshot: RoundSnapshot) -> HandicapRoundMetadata? {
        let memberPlayerID = members.first(where: { $0.id == memberID })?.playerID
        guard let participant = snapshot.participants.first(where: {
            ($0.seriesMemberID?.isPopulated == true && $0.seriesMemberID == memberID)
                || (memberPlayerID?.isPopulated == true && $0.playerID == memberPlayerID)
        }) else {
            return nil
        }

        let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID)
            ?? snapshot.courseSegment?.tee(from: snapshot.courseSegment?.defaultTee ?? "")
            ?? snapshot.courseSegment?.courseInfo.tees.first

        let resolvedTeeBoxID = participant.teeBoxID.isPopulated ? participant.teeBoxID : tee?.id ?? ""
        guard resolvedTeeBoxID.isPopulated,
              let courseRating = tee?.rating(for: snapshot.holeSegment),
              let courseSlope = tee?.slope(for: snapshot.holeSegment) else {
            return nil
        }

        return (teeBoxID: resolvedTeeBoxID, courseRating: courseRating, courseSlope: courseSlope)
    }

    private func syncRoundHandicapScores(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        replacingExisting: Bool
    ) async -> Bool {
        guard series.handicapConfig.mode.allowsAccrual else {
            if replacingExisting, let roundID = seriesRound.roundID {
                let deleted = await deleteRoundHandicapScores(sourceRoundID: roundID)
                if deleted { recomputeAllHandicaps() }
                return deleted
            }
            return false
        }

        return await ingestRoundScores(
            seriesRound: seriesRound,
            snapshot: snapshot,
            replacingExisting: replacingExisting
        )
    }

    private func shouldAccrueLeagueHandicap(for seriesRound: SeriesRound, snapshot: RoundSnapshot?) -> Bool {
        guard series.handicapConfig.mode.allowsAccrual else { return false }
        guard seriesRound.roundConfig.countsTowardHandicapPool else { return false }
        if let snapshot {
            return snapshot.resolvedActiveTemplate.supportsLeagueHandicapAccrual
        }
        return effectiveRoundConfig(for: seriesRound).supportsLeagueHandicapAccrual
    }

    private func deleteRoundHandicapScores(sourceRoundID: String) async -> Bool {
        let existingRoundScores = handicapScores.filter {
            $0.source == .round && $0.sourceRoundID == sourceRoundID
        }

        var deleted = false
        for existing in existingRoundScores {
            switch await FirebaseService.shared.deleteHandicapScore(existing) {
            case .success:
                handicapScores.removeAll { $0.id == existing.id }
                deleted = true
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to delete existing handicap score for correction", error: error)
            }
        }
        return deleted
    }

    // MARK: - Announcements

    @discardableResult
    func addAnnouncement(title: String, message: String, start: Date?, end: Date?) async -> Bool {
        guard let memberID = currentMemberID else { return false }
        guard let (startTime, endTime) = Self.resolvedAnnouncementSchedule(start: start, end: end) else { return false }
        let announcement = SeriesAnnouncement(
            id: HackersID.string(),
            title: title,
            message: message,
            createdByMemberID: memberID,
            startsAt: startTime,
            endsAt: endTime,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesAnnouncement(announcement) {
        case .success(let created):
            announcements.append(created)
            await refreshSeriesCachesIfNeeded()
            addEvent(
                "series.announcement_created",
                eventProps: seriesTelemetryProps(["announcement_id": created.id])
            )
            return true
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add announcement", error: error)
            return false
        }
    }

    func deleteAnnouncement(_ announcement: SeriesAnnouncement) async {
        guard let index = announcements.firstIndex(where: { $0.id == announcement.id }) else { return }
        let target = announcements[index]
        announcements.remove(at: index)
        _ = await FirebaseService.shared.deleteSeriesAnnouncement(target)
        await refreshSeriesCachesIfNeeded()
        addEvent(
            "series.announcement_deleted",
            eventProps: seriesTelemetryProps(["announcement_id": target.id])
        )
    }

    @discardableResult
    func updateAnnouncement(_ announcement: SeriesAnnouncement, title: String, message: String, start: Date?, end: Date?) async -> Bool {
        guard let (startTime, endTime) = Self.resolvedAnnouncementSchedule(start: start, end: end) else { return false }
        var updated = announcement
        updated.title = title
        updated.message = message
        updated.startsAt = startTime
        updated.endsAt = endTime
        updated.lastUpdatedAt = .init()
        switch await FirebaseService.shared.updateSeriesAnnouncement(updated) {
        case .success(let saved):
            if let idx = announcements.firstIndex(where: { $0.id == saved.id }) {
                announcements[idx] = saved
            }
            await refreshSeriesCachesIfNeeded()
            addEvent(
                "series.announcement_updated",
                eventProps: seriesTelemetryProps(["announcement_id": saved.id])
            )
            return true
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to update announcement", error: error)
            return false
        }
    }

    /// Maps optional schedule to stored `Time` values; returns `nil` if explicit window is invalid.
    private static func resolvedAnnouncementSchedule(start: Date?, end: Date?) -> (Time, Time)? {
        let startTime = start.map { Time(for: $0) } ?? Time().beginningOfTime
        let endTime = end.map { Time(for: $0) } ?? Time().endOfTIme
        let bothExplicit = start != nil && end != nil
        if bothExplicit, endTime.unix <= startTime.unix { return nil }
        return (startTime, endTime)
    }

    private func announcementSortNewestFirst(_ lhs: SeriesAnnouncement, _ rhs: SeriesAnnouncement) -> Bool {
        if lhs.startsAt.unix != rhs.startsAt.unix { return lhs.startsAt.unix > rhs.startsAt.unix }
        return lhs.createdAt.unix > rhs.createdAt.unix
    }

    /// Future start time — not yet visible as “live”.
    var plannedAnnouncements: [SeriesAnnouncement] {
        let now = Time()
        return announcements
            .filter { $0.startsAt.unix > now.unix }
            .sorted(by: announcementSortNewestFirst)
    }

    /// In the active time window.
    var liveAnnouncements: [SeriesAnnouncement] {
        let now = Time()
        return announcements
            .filter { $0.isActive(at: now) }
            .sorted(by: announcementSortNewestFirst)
    }

    /// Past explicit end (open-ended announcements never land here).
    var expiredAnnouncements: [SeriesAnnouncement] {
        let now = Time()
        return announcements
            .filter {
                !$0.isActive(at: now)
                    && $0.startsAt.unix <= now.unix
                    && !$0.usesOpenEnd
                    && $0.endsAt.unix <= now.unix
            }
            .sorted(by: announcementSortNewestFirst)
    }

    // MARK: - CSV Export

    func exportCSV(for seriesRound: SeriesRound) async -> URL? {
        guard let roundID = seriesRound.roundID else { return nil }
        exportingRoundID = seriesRound.id
        defer { exportingRoundID = nil }

        guard let snapshot = await loadRoundSnapshot(roundID: roundID) else { return nil }
        let document = SeriesRoundCSVExporter.document(seriesRound: seriesRound, snapshot: snapshot, members: members)
        guard document.rows.isPopulated else { return nil }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("series-round-\(seriesRound.index + 1)-\(seriesRound.id.prefix(6)).csv")

        do {
            try document.content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedCSVURL = fileURL
            addEvent(
                "series.round_csv_exported",
                eventProps: seriesTelemetryProps([
                    "series_round_id": seriesRound.id,
                    "hole_count": snapshot.holeRange?.count ?? snapshot.holeSegment.holeCount
                ])
            )
            return fileURL
        } catch {
            addBreadcrumb(level: .error, message: "Failed to write series CSV export", error: error)
            return nil
        }
    }

    func pointAwards(for seriesRound: SeriesRound, track: SeriesAwardTrack? = nil) -> [SeriesPointAward] {
        pointAwards
            .filter { award in
                award.seriesRoundID == seriesRound.id && (track == nil || award.awardTrack == track)
            }
            .sorted { lhs, rhs in
                if (lhs.awardTrack.rawValue, lhs.placement ?? .max) != (rhs.awardTrack.rawValue, rhs.placement ?? .max) {
                    if lhs.awardTrack != rhs.awardTrack {
                        return lhs.awardTrack.rawValue < rhs.awardTrack.rawValue
                    }
                    return (lhs.placement ?? .max) < (rhs.placement ?? .max)
                }
                if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
                return lhs.competitorName < rhs.competitorName
            }
    }

    func teamRosterSubtitle(for teamID: String) -> String? {
        let roster = activeMembers.filter { $0.teamID == teamID }
        return SeriesTeamInsightBuilder.rosterSubtitle(for: roster)
    }

    func teamInsight(for standing: SeriesStanding) async -> SeriesTeamInsight? {
        guard standing.awardTrack == .team,
              let team = teams.first(where: { $0.id == standing.competitorID }) else {
            return nil
        }

        var snapshotsBySeriesRoundID: [String: RoundSnapshot] = [:]
        for round in rounds where round.roundID?.isPopulated == true {
            if let snapshot = await cachedLinkedRoundSnapshot(for: round) {
                snapshotsBySeriesRoundID[round.id] = snapshot
            }
        }

        let statusBySeriesRoundID = Dictionary(uniqueKeysWithValues: rounds.map { ($0.id, effectiveStatus(for: $0)) })
        return SeriesTeamInsightBuilder.build(
            team: team,
            standing: standing,
            teams: teams,
            members: members,
            rounds: rounds,
            pointAwards: pointAwards,
            snapshotsBySeriesRoundID: snapshotsBySeriesRoundID,
            statusBySeriesRoundID: statusBySeriesRoundID
        )
    }

    func teeChoices(for course: SeriesCourseSelection?) -> [Tee] {
        guard let course, course.courseID.isPopulated else { return [] }
        if let cached = seriesCourseTeesByCourseID[course.courseID], cached.isPopulated {
            return cached
        }

        if let round = rounds.first(where: { $0.resolvedCourse(using: series)?.courseID == course.courseID }),
           let roundID = round.roundID,
           let linked = linkedRounds[roundID],
           let tees = linked.configuration.courses.first?.courseInfo.tees,
           tees.isPopulated {
            return tees
        }

        return []
    }

    func ensureTeeChoicesLoaded(for course: SeriesCourseSelection?) async {
        guard let course, course.courseID.isPopulated else { return }
        if seriesCourseTeesByCourseID[course.courseID]?.isPopulated == true { return }

        let courseID = course.courseID
        let applyLinkedRoundFallback: () -> Void = { [self] in
            if let round = rounds.first(where: { $0.resolvedCourse(using: series)?.courseID == courseID }),
               let roundID = round.roundID,
               let linked = linkedRounds[roundID],
               let tees = linked.configuration.courses.first?.courseInfo.tees,
               tees.isPopulated {
                seriesCourseTeesByCourseID[courseID] = tees
            }
        }

        if let apiID = Int(courseID) {
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: apiID)
                let built = Course(from: apiCourse, with: courseID, useStableTeeIDs: true)
                seriesCourseTeesByCourseID[courseID] = built.tees
            } catch {
                switch await FirebaseService.shared.getCourseByID(courseID) {
                case .success(let loadedCourse):
                    seriesCourseTeesByCourseID[courseID] = loadedCourse.tees
                case .failure:
                    applyLinkedRoundFallback()
                }
            }
        } else {
            switch await FirebaseService.shared.getCourseByID(courseID) {
            case .success(let loadedCourse):
                seriesCourseTeesByCourseID[courseID] = loadedCourse.tees
            case .failure:
                applyLinkedRoundFallback()
            }
        }
    }

    func loadCorrectionContext(for seriesRound: SeriesRound) async -> SeriesRoundCorrectionContext? {
        guard let roundID = seriesRound.roundID,
              let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return nil
        }

        let holes = holesForScoring(in: snapshot).sorted { $0.number < $1.number }
        let entriesByParticipantID = Dictionary(
            uniqueKeysWithValues: snapshot.participants.map { participant in
                let scoreRows = Dictionary(
                    uniqueKeysWithValues: snapshot.scoring
                        .filter { $0.scoringUnitID == participant.id }
                        .map { ($0.holeNumber, $0) }
                )
                return (participant.id, scoreRows)
            }
        )

        return SeriesRoundCorrectionContext(
            seriesRound: seriesRound,
            snapshot: snapshot,
            holes: holes,
            entriesByParticipantID: entriesByParticipantID
        )
    }

    /// Writes commissioner hole edits to the live round, updates series round metadata, then runs `processCompletedRound` (handicap accrual, awards, standings). Used by hole-by-hole and gross-total correction UIs.
    func applyScoreCorrections(
        for seriesRound: SeriesRound,
        changes: [SeriesScoreCorrectionChange],
        reason: String
    ) async -> Bool {
        guard isCommissioner,
              let roundID = seriesRound.roundID,
              let currentMemberID else { return false }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let snapshot = await loadRoundSnapshot(roundID: roundID) else { return false }

        correctingRoundID = seriesRound.id
        defer { correctingRoundID = nil }

        let participantsByID = Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
        let existingEntries = Dictionary(
            grouping: snapshot.scoring,
            by: { "\($0.scoringUnitID)_\($0.holeNumber)" }
        )

        var didWrite = false
        var successfulHoleWrites = 0
        for change in changes {
            guard let participant = participantsByID[change.participantID] else { continue }
            let key = "\(participant.id)_\(change.holeNumber)"
            let previousEntry = existingEntries[key]?.first

            if previousEntry?.strokes == change.strokes, previousEntry?.pickedUp == false {
                continue
            }
            if change.strokes == nil, previousEntry == nil {
                continue
            }

            let resolvedSegmentID: String = {
                if let existingID = previousEntry?.segmentID, existingID.isPopulated {
                    return existingID
                }
                if let segment = snapshot.segment(forHole: change.holeNumber), segment.id.isPopulated {
                    return segment.id
                }
                if let roundSegmentID = snapshot.roundSegment?.id, roundSegmentID.isPopulated {
                    return roundSegmentID
                }
                return snapshot.segments.first?.id ?? "seg0"
            }()

            let entryID = ScoreEntry.makeID(
                hole: change.holeNumber,
                segment: resolvedSegmentID,
                scoringUnit: participant.id
            )

            var entry = previousEntry ?? ScoreEntry(
                id: entryID,
                holeNumber: change.holeNumber,
                segmentID: resolvedSegmentID,
                groupID: participant.groupID ?? "",
                scoringUnitID: participant.id,
                participantIDs: [participant.id],
                strokes: nil,
                value: nil,
                pickedUp: false,
                entryID: previousEntry?.entryID ?? participant.id,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: roundID
            )

            entry.id = entryID
            entry.parentID = roundID
            entry.segmentID = resolvedSegmentID
            entry.groupID = participant.groupID ?? entry.groupID
            entry.scoringUnitID = participant.id
            entry.participantIDs = [participant.id]
            entry.entryID = previousEntry?.entryID ?? participant.id
            entry.pickedUp = false
            entry.value = nil
            entry.strokes = change.strokes
            entry.lastUpdatedAt = .init()

            do {
                _ = try await entry.put().get()
                didWrite = true
                successfulHoleWrites += 1
            } catch {
                addBreadcrumb(level: .error, message: "Failed to save commissioner score correction", error: error)
            }
        }

        guard didWrite,
              let roundIndex = rounds.firstIndex(where: { $0.id == seriesRound.id }) else {
            return false
        }

        rounds[roundIndex].lastScoreAdjustmentAt = .init()
        rounds[roundIndex].lastScoreAdjustmentByMemberID = currentMemberID
        rounds[roundIndex].lastScoreAdjustmentReason = trimmedReason.isPopulated ? trimmedReason : "Commissioner score correction"
        rounds[roundIndex].scoreAdjustmentCount += 1
        rounds[roundIndex].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesRound(rounds[roundIndex])

        if case .success(let linkedRound) = await FirebaseService.shared.getRoundByID(roundID) {
            linkedRounds[roundID] = linkedRound
        }

        guard let refreshedSnapshot = await loadRoundSnapshot(roundID: roundID) else { return false }
        handicapScores = await FirebaseService.shared.fetchHandicapScores(seriesID: seriesID)
        let _ = await processCompletedRound(
            seriesRound: rounds[roundIndex],
            snapshot: refreshedSnapshot,
            overwriteDerivedData: true
        )
        pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        standings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)
        handicapScores = await FirebaseService.shared.fetchHandicapScores(seriesID: seriesID)
        recomputeAllHandicaps()
        addEvent(
            "series.commissioner_score_correction_applied",
            eventProps: seriesTelemetryProps([
                "series_round_id": seriesRound.id,
                "round_id": roundID,
                "score_cells_written": successfulHoleWrites
            ])
        )
        return true
    }

    // MARK: - Helpers

    private func hasActiveMember(for player: Player) -> Bool {
        let playerID = player.playerID ?? player.id
        if playerID.isPopulated {
            return activeMembers.contains { $0.playerID == playerID }
        }
        return hasOfflineMember(named: player.name)
    }

    private func hasOfflineMember(named name: Name) -> Bool {
        activeMembers.contains { $0.playerID == nil && normalizedName($0.name) == normalizedName(name) }
    }

    private func normalizedName(_ name: Name) -> String {
        name.searchKey
    }

    private func validatePod(teamID: String, memberIDs: [String]) -> Bool {
        let teamMemberIDs = Set(activeMembers.filter { $0.teamID == teamID }.map(\.id))
        guard Set(memberIDs).isSubset(of: teamMemberIDs) else { return false }

        let usedMemberIDs = Set(
            pods
                .filter { $0.teamID == teamID && $0.isActive }
                .flatMap(\.memberIDs)
        )
        return Set(memberIDs).intersection(usedMemberIDs).isEmpty
    }

    private func scoringProfile(id: String?) -> SeriesScoringProfile? {
        guard let id else { return nil }
        return scoringProfiles.first { $0.id == id && !$0.isArchived }
    }

    private func roundConfig(
        from linkedRound: Round,
        segment: RoundSegment? = nil,
        fallback: SeriesRoundConfiguration
    ) -> SeriesRoundConfiguration {
        var updated = fallback
        updated.formatTemplateID = linkedRound.configuration.formatSummary?.templateID ?? fallback.formatTemplateID
        updated.competitionScope = linkedRound.configuration.competitionScope
        updated.teamScoring = linkedRound.configuration.teamScoring
        updated.matchupResolutionStyle = linkedRound.configuration.matchupResolutionStyle
        let template = FormatTemplateRegistry.template(for: updated.formatTemplateID)
        updated.scoreOwnerScope = template.scoreSource == .shared ? linkedRound.configuration.scoreOwnerScope : .individual
        updated.matchupScoringStyle = linkedRound.configuration.matchupScoringStyle
        updated.holeWinPoints = linkedRound.configuration.holeWinPoints
        updated.matchWinnerBonusPoints = linkedRound.configuration.matchWinnerBonusPoints
        updated.matchTiePolicy = linkedRound.configuration.matchTiePolicy
        updated.selectionDomain = linkedRound.configuration.selectionDomain
        updated.sequentialTeeStartsEnabled = linkedRound.configuration.sequentialTeeStartsEnabled ?? fallback.sequentialTeeStartsEnabled ?? false
        updated.handicapEntryFormat = linkedRound.configuration.handicapEntryFormat
        updated.handicapNormalizationMode = linkedRound.configuration.handicapNormalizationMode
        updated.handicapStrokeBasis = linkedRound.configuration.handicapStrokeBasis
        if linkedRound.configuration.resolvedCompetitionScope == .matchup {
            updated.matchupMode = seriesMatchupMode(
                from: linkedRound.configuration,
                segment: segment,
                fallback: fallback.matchupMode
            )
        } else {
            updated.matchupMode = .field
        }
        return updated
    }

    private func seriesMatchupMode(
        from configuration: RoundConfiguration,
        segment: RoundSegment?,
        fallback: SeriesMatchupMode
    ) -> SeriesMatchupMode {
        let matchups = segment?.matchups ?? []
        if matchups.contains(where: { $0.effectiveMode == .partnership }) {
            return .teeGroupPartnerships
        }
        if matchups.contains(where: { $0.effectiveMode == .team }) {
            return .teamVsTeam
        }
        if matchups.contains(where: { $0.effectiveMode == .individual }) {
            return .individualVsIndividual
        }
        if configuration.selectionDomain == .partnership && fallback == .teeGroupPartnerships {
            return .teeGroupPartnerships
        }
        return configuration.primaryFormat.configuration.requiresTeams ? .teamVsTeam : .individualVsIndividual
    }

    private func templateID(for format: GameFormat) -> String {
        switch (format.type, format.configuration.requiresTeams) {
        case (.matchPlay, false): return FormatTemplateRegistry.matchPlayIndividual.id
        case (.strokePlay, true): return FormatTemplateRegistry.bestBall.id
        default: return FormatTemplateRegistry.strokePlay.id
        }
    }

    private func loadRoundSnapshot(roundID: String) async -> RoundSnapshot? {
        addBreadcrumb(message: "\(#function) roundID: \(roundID)")
        // Work around a Swift 6.3 async-let runtime crash seen with larger return structs.
        let fetchedRound = await FirebaseService.shared.getRoundDocument(byID: roundID)
        let fetchedParticipants = await FirebaseService.shared.getParticipants(for: roundID)
        let fetchedTeams = await FirebaseService.shared.getTeams(for: roundID)
        let fetchedGroups = await FirebaseService.shared.getTeeGroups(for: roundID)
        let fetchedSegments = await FirebaseService.shared.getSegments(for: roundID)
        let fetchedScores = await FirebaseService.shared.getScores(for: roundID)

        guard case .success(let round) = fetchedRound else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode round root doc for \(roundID)")
            return nil
        }
        guard case .success(let participants) = fetchedParticipants else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode participants for \(roundID)")
            return nil
        }
        guard case .success(let roundTeams) = fetchedTeams else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode teams for \(roundID)")
            return nil
        }
        guard case .success(let teeGroups) = fetchedGroups else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode tee groups for \(roundID)")
            return nil
        }
        guard case .success(let segments) = fetchedSegments else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode segments for \(roundID)")
            return nil
        }
        guard case .success(let scores) = fetchedScores else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode scores for \(roundID)")
            return nil
        }
        let fetchedScoringGroups = await FirebaseService.shared.getScoringGroups(for: roundID)
        guard case .success(let scoringGroups) = fetchedScoringGroups else {
            addBreadcrumb(level: .error, message: "loadRoundSnapshot failed to decode scoring groups for \(roundID)")
            return nil
        }

        let templateID = round.configuration.formatSummary?.templateID ?? round.configuration.activeTemplate.id
        addBreadcrumb(
            message: """
            loadRoundSnapshot decoded roundID=\(roundID) \
            template=\(templateID) status=\(round.status.rawValue) \
            participants=\(participants.count) teams=\(roundTeams.count) \
            groups=\(teeGroups.count) segments=\(segments.count) scores=\(scores.count) \
            scoringGroups=\(scoringGroups.count)
            """
        )

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: roundTeams,
            teeGroups: teeGroups,
            scoringGroups: scoringGroups,
            segments: segments,
            scoring: scores
        )
    }

    func loadLinkedRoundSnapshot(for seriesRound: SeriesRound) async -> RoundSnapshot? {
        guard let roundID = seriesRound.roundID else { return nil }
        return await cachedLinkedRoundSnapshot(roundID: roundID)
    }

    private func cachedLinkedRoundSnapshot(for seriesRound: SeriesRound) async -> RoundSnapshot? {
        guard let roundID = seriesRound.roundID else { return nil }
        return await cachedLinkedRoundSnapshot(roundID: roundID)
    }

    private func cachedLinkedRoundSnapshot(roundID: String) async -> RoundSnapshot? {
        if let cached = linkedRoundSnapshotCache[roundID] {
            return cached
        }
        guard let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return nil
        }
        linkedRoundSnapshotCache[roundID] = snapshot
        return snapshot
    }

    func roundOutcomeNarrative(for seriesRound: SeriesRound) async -> SeriesRoundOutcomeNarrative? {
        guard effectiveStatus(for: seriesRound) == .complete,
              let roundID = seriesRound.roundID,
              let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return nil
        }

        let priorRounds = rounds
            .filter { prior in
                prior.id != seriesRound.id
                    && prior.index < seriesRound.index
                    && effectiveStatus(for: prior) == .complete
                    && prior.roundID?.isPopulated == true
            }
            .sorted { $0.index > $1.index }

        var priorSnapshots: [SeriesRoundOutcomeNarrativeBuilder.PriorRoundSnapshot] = []
        for priorRound in priorRounds {
            guard let priorRoundID = priorRound.roundID,
                  let priorSnapshot = await loadRoundSnapshot(roundID: priorRoundID) else {
                continue
            }
            priorSnapshots.append(.init(seriesRound: priorRound, snapshot: priorSnapshot))
        }

        return roundOutcomeNarrative(
            for: seriesRound,
            snapshot: snapshot,
            priorRoundSnapshots: priorSnapshots
        )
    }

    func roundOutcomeNarrative(
        for seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        priorRoundSnapshots: [SeriesRoundOutcomeNarrativeBuilder.PriorRoundSnapshot] = []
    ) -> SeriesRoundOutcomeNarrative? {
        SeriesRoundOutcomeNarrativeBuilder.build(
            seriesRound: seriesRound,
            snapshot: snapshot,
            priorRoundSnapshots: priorRoundSnapshots,
            members: members,
            handicapScores: handicapScores,
            memberHandicaps: memberHandicaps,
            pointAwards: pointAwards,
            standings: standings,
            teams: teams
        )
    }

    func viewerParticipantID(for seriesRound: SeriesRound, appSession: AppSession) async -> String? {
        guard let roundID = seriesRound.roundID,
              let snapshot = await loadRoundSnapshot(roundID: roundID) else {
            return nil
        }

        if let ephemeral = appSession.ephemeralParticipantID, ephemeral.isPopulated,
           snapshot.participants.contains(where: { $0.id == ephemeral }) {
            return ephemeral
        }

        if let user = await AppData.shared.user,
           let participant = snapshot.participants.first(where: { $0.userID == user.id }) {
            return participant.id
        }

        if let primary = await AppData.shared.getPrimaryPlayer(),
           let participant = snapshot.participants.first(where: { $0.playerID == primary.id }) {
            return participant.id
        }

        return nil
    }

    func matchupOutcomes(
        for seriesRound: SeriesRound,
        promotingParticipantID: String? = nil
    ) async -> [SeriesMatchupOutcome] {
        guard let roundID = seriesRound.roundID,
              let snapshot = await loadRoundSnapshot(roundID: roundID),
              let segment = snapshot.roundSegment else { return [] }
        guard snapshot.configuration.resolvedCompetitionScope == .matchup else { return [] }

        if let mismatch = snapshot.primarySegmentHoleRangeMismatch {
            return orderedMatchupOutcomes(
                diagnosticMatchupOutcomes(
                    mismatch: mismatch,
                    segment: segment,
                    snapshot: snapshot
                ),
                promotingParticipantID: promotingParticipantID
            )
        }

        let result = scoringResult(from: snapshot, segment: segment)
        guard result.matchupResults.isPopulated else { return [] }

        let highestWins = result.template.leaderboardSort == .highestWins
        let participantSortBasis: ScoreBasis = snapshot.configuration.useHandicaps ? .net : .gross
        let outcomes = result.matchupResults.enumerated().compactMap { index, matchupResult -> SeriesMatchupOutcome? in
            guard matchupResult.matchup.isValid else { return nil }
            let presentation = MatchupResultPresentationBuilder.build(
                snapshot: snapshot,
                result: result,
                matchupResult: matchupResult
            )
            let sides = presentation.sides.map { side in
                return SeriesMatchupOutcome.Side(
                    id: side.id,
                    title: side.title,
                    subtitle: side.subtitle,
                    score: side.scoreLabel,
                    accentColor: side.accentColor
                )
            }
            guard sides.count == 2 else { return nil }

            let playerItems = presentation.sides.flatMap { side in
                side.participants.map { (participant: $0, side: side) }
            }
            let players = playerItems
                .sorted {
                    matchupParticipantSort(
                        lhs: $0.participant,
                        rhs: $1.participant,
                        highestWins: highestWins,
                        sortBasis: participantSortBasis,
                        snapshot: snapshot,
                        segment: segment
                    )
                }
                .map { item in
                    SeriesMatchupOutcome.Player(
                        id: "\(item.side.id)_\(item.participant.id)",
                        participantID: item.participant.id,
                        ownerID: item.side.id,
                        name: item.participant.name.fullName,
                        handicap: "\(item.participant.adjustedHandicap)",
                        gross: participantScoreLabel(participantID: item.participant.id, snapshot: snapshot, segment: segment, basis: .gross),
                        net: snapshot.configuration.useHandicaps ? participantScoreLabel(participantID: item.participant.id, snapshot: snapshot, segment: segment, basis: .net) : nil,
                        scoreCounts: item.side.isParticipantActive(item.participant),
                        accentColor: item.participant.teamID.flatMap { teamID in snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor }
                            ?? item.side.accentColor
                    )
                }
            let showsResultChip = Self.shouldShowMatchupResultChip(for: presentation)

            return SeriesMatchupOutcome(
                id: matchupResult.matchup.id,
                matchIndex: index + 1,
                title: presentation.hasCompleteSides ? presentation.title : "Match \(index + 1)",
                detail: presentation.hasCompleteSides ? presentation.scorelineDetail : presentation.scorelineDetail,
                mode: presentation.mode,
                sides: sides,
                players: players,
                winningSideID: presentation.winningSideID,
                isTie: presentation.isTie,
                showsResultChip: showsResultChip,
                resultChipLabel: presentation.isAutoWin ? "Auto-win" : nil,
                usesNetScores: snapshot.configuration.useHandicaps
            )
        }
        return orderedMatchupOutcomes(outcomes, promotingParticipantID: promotingParticipantID)
    }

    private func diagnosticMatchupOutcomes(
        mismatch: RoundSegmentHoleRangeMismatch,
        segment: RoundSegment,
        snapshot: RoundSnapshot
    ) -> [SeriesMatchupOutcome] {
        let validMatchups = (segment.matchups ?? []).filter(\.isValid)
        return validMatchups.enumerated().compactMap { index, matchup in
            let mode = matchup.effectiveMode
            let sides = matchup.pairingIDs().map { sideID in
                SeriesMatchupOutcome.Side(
                    id: sideID,
                    title: matchupSideName(sideID: sideID, mode: mode, snapshot: snapshot),
                    subtitle: matchupSideSubtitle(sideID: sideID, mode: mode, snapshot: snapshot),
                    score: "—",
                    accentColor: matchupSideAccentColor(sideID: sideID, mode: mode, snapshot: snapshot)
                )
            }
            guard sides.count == 2 else { return nil }

            let players = sides.flatMap { side in
                matchupSideParticipants(sideID: side.id, mode: mode, snapshot: snapshot).map { participant in
                    SeriesMatchupOutcome.Player(
                        id: "\(side.id)_\(participant.id)",
                        participantID: participant.id,
                        ownerID: side.id,
                        name: participant.name.fullName,
                        handicap: "\(participant.adjustedHandicap)",
                        gross: "—",
                        net: snapshot.configuration.useHandicaps ? "—" : nil,
                        scoreCounts: false,
                        accentColor: participant.teamID.flatMap { teamID in snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor }
                            ?? side.accentColor
                    )
                }
            }

            return SeriesMatchupOutcome(
                id: matchup.id,
                matchIndex: index + 1,
                title: "\(mismatch.diagnosticTitle) - Match \(index + 1)",
                detail: mismatch.diagnosticDetail,
                mode: mode,
                sides: sides,
                players: players,
                winningSideID: nil,
                isTie: false,
                showsResultChip: false,
                resultChipLabel: nil,
                usesNetScores: snapshot.configuration.useHandicaps
            )
        }
    }

    private func orderedMatchupOutcomes(
        _ outcomes: [SeriesMatchupOutcome],
        promotingParticipantID participantID: String?
    ) -> [SeriesMatchupOutcome] {
        guard let participantID, participantID.isPopulated else { return outcomes }

        return outcomes.sorted { lhs, rhs in
            let lhsContains = lhs.players.contains { $0.participantID == participantID }
            let rhsContains = rhs.players.contains { $0.participantID == participantID }
            if lhsContains != rhsContains { return lhsContains }
            return lhs.matchIndex < rhs.matchIndex
        }
    }

    func matchupScoreDisplayLabel(for row: ScoringRow, highestWins: Bool) -> String {
        Self.matchupScoreDisplayLabel(for: row, highestWins: highestWins)
    }

    nonisolated static func matchupScoreDisplayLabel(for row: ScoringRow, highestWins: Bool) -> String {
        MatchupResultPresentationBuilder.scoreLabel(for: row.total, isPointsFormat: highestWins)
    }

    nonisolated static func shouldShowMatchupResultChip(for presentation: MatchupResultPresentation) -> Bool {
        presentation.hasCompleteSides && (presentation.winningSideID != nil || presentation.isTie)
    }

    private func expectedMatchupMode(for snapshot: RoundSnapshot) -> MatchupMode {
        snapshot.expectedMatchupMode
    }

    private func scoringRow(
        in rows: [ScoringRow],
        matchesSideID sideID: String,
        matchup: TeamMatchup,
        expectedMode: MatchupMode,
        snapshot: RoundSnapshot
    ) -> ScoringRow? {
        rows.first {
            scoringRowIdentityMatches(
                scoringUnitID: $0.scoringUnitID,
                owner: $0.owner,
                participantIDs: $0.participantIDs,
                sideID: sideID,
                mode: matchup.effectiveMode,
                snapshot: snapshot
            )
        }
    }

    private func scoringRowIdentityMatches(
        scoringUnitID: String,
        owner: ScoringOwner,
        participantIDs: [String],
        sideID: String,
        mode: MatchupMode,
        snapshot: RoundSnapshot
    ) -> Bool {
        if scoringUnitID == sideID { return true }

        switch mode {
        case .individual:
            return participantIDs.contains(sideID)
        case .team:
            let teamMemberIDs = Set(snapshot.participants.filter { $0.teamID == sideID }.map(\.id))
            return teamMemberIDs.isPopulated && Set(participantIDs).isSubset(of: teamMemberIDs)
        case .partnership, .teeGroup, .scoreOwner:
            guard let group = snapshot.scoringGroup(id: sideID) else { return false }
            return Set(participantIDs) == Set(group.memberIDs)
        }
    }

    private func matchupSideName(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> String {
        switch mode {
        case .team:
            return snapshot.teams.first(where: { $0.id == sideID })?.name ?? "Team"
        case .individual:
            return snapshot.participants.first(where: { $0.id == sideID })?.name.fullName ?? "Player"
        case .partnership, .teeGroup, .scoreOwner:
            if let scoringGroup = snapshot.scoringGroup(id: sideID) {
                if let label = scoringGroup.label, label.isPopulated {
                    return label
                }
                let names = matchupSideParticipants(sideID: sideID, mode: mode, snapshot: snapshot)
                    .map(\.name.fullName)
                    .filter(\.isPopulated)
                return names.isPopulated ? names.joined(separator: " + ") : "Side"
            }
            return "Side"
        }
    }

    private func matchupSideSubtitle(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> String? {
        switch mode {
        case .individual:
            return nil
        case .team, .partnership, .teeGroup, .scoreOwner:
            let names = matchupSideParticipants(sideID: sideID, mode: mode, snapshot: snapshot)
                .map(\.name.fullName)
                .filter(\.isPopulated)
            return names.isPopulated ? names.joined(separator: ", ") : nil
        }
    }

    private func matchupSideAccentColor(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> Color? {
        switch mode {
        case .team:
            return snapshot.teams.first(where: { $0.id == sideID })?.displaySwatchColor
        case .individual:
            return snapshot.participants
                .first(where: { $0.id == sideID })?
                .teamID
                .flatMap { teamID in snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor }
        case .partnership, .teeGroup, .scoreOwner:
            guard let group = snapshot.scoringGroup(id: sideID) else { return nil }
            if let teamID = group.teamID {
                return snapshot.teams.first(where: { $0.id == teamID })?.displaySwatchColor
            }
            return nil
        }
    }

    private func matchupSideParticipants(sideID: String, mode: MatchupMode, snapshot: RoundSnapshot) -> [RoundParticipant] {
        switch mode {
        case .team:
            return snapshot.participants
                .filter { $0.teamID == sideID }
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
        case .individual:
            return snapshot.participants
                .filter { $0.id == sideID }
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
        case .partnership, .teeGroup, .scoreOwner:
            guard let group = snapshot.scoringGroup(id: sideID) else { return [] }
            let memberIDs = Set(group.memberIDs)
            return snapshot.participants
                .filter { memberIDs.contains($0.id) }
                .sorted { ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max) }
        }
    }

    private func matchupParticipantSort(
        lhs: RoundParticipant,
        rhs: RoundParticipant,
        highestWins: Bool,
        sortBasis: ScoreBasis,
        snapshot: RoundSnapshot,
        segment: RoundSegment
    ) -> Bool {
        let basis: ScoreBasis = highestWins ? .gross : sortBasis
        let lhsScore = participantScoreToPar(participantID: lhs.id, snapshot: snapshot, segment: segment, basis: basis) ?? 0
        let rhsScore = participantScoreToPar(participantID: rhs.id, snapshot: snapshot, segment: segment, basis: basis) ?? 0
        if lhsScore != rhsScore {
            return highestWins ? lhsScore > rhsScore : lhsScore < rhsScore
        }
        if (lhs.teeOrder ?? Int.max) != (rhs.teeOrder ?? Int.max) {
            return (lhs.teeOrder ?? Int.max) < (rhs.teeOrder ?? Int.max)
        }
        let nameComparison = lhs.name.fullName.localizedCaseInsensitiveCompare(rhs.name.fullName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private func participantScoreCounts(participantID: String, row: ScoringRow?) -> Bool {
        guard let row else { return false }
        if row.countingParticipantIDs.isPopulated {
            return row.countingParticipantIDs.contains(participantID)
        }
        return row.participantIDs.contains(participantID)
    }

    private func participantScoreLabel(
        participantID: String,
        snapshot: RoundSnapshot,
        segment: RoundSegment,
        basis: ScoreBasis
    ) -> String {
        guard let score = participantScoreToPar(participantID: participantID, snapshot: snapshot, segment: segment, basis: basis) else {
            return "—"
        }
        return Self.scoreReviewFormatRelative(score)
    }

    private func participantScoreToPar(
        participantID: String,
        snapshot: RoundSnapshot,
        segment: RoundSegment,
        basis: ScoreBasis
    ) -> Int? {
        let result = ScoringEngine.computeStrokePlay(
            scores: snapshot.scoring,
            participants: snapshot.participants,
            segment: segment,
            holes: holesForScoring(in: snapshot),
            basis: basis,
            template: snapshot.resolvedActiveTemplate,
            scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
        guard let row = result.rows.first(where: { $0.scoringUnitID == participantID }),
              row.holesPlayed > 0 else { return nil }
        return Int(row.total.rounded())
    }

    /// Relative to par and gross total, e.g. `+4 / 45`, for commissioner score review rows.
    func scoreReviewTrailingLabel(playerID: String, snapshot: RoundSnapshot) -> String? {
        guard let segment = snapshot.roundSegment else { return nil }
        let result = ScoringEngine.computeStrokePlay(
            scores: snapshot.scoring,
            participants: snapshot.participants,
            segment: segment,
            holes: holesForScoring(in: snapshot),
            basis: snapshot.configuration.primaryFormat.configuration.basis,
            template: snapshot.resolvedActiveTemplate,
            scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs,
            handicapStrokeBasis: snapshot.handicapStrokeBasis
        )
        guard let participant = snapshot.participants.first(where: { $0.playerID == playerID }) else { return nil }
        guard RoundScoreCompleteness.classify(participantID: participant.id, snapshot: snapshot).isComplete else {
            return nil
        }
        guard let row = result.rows.first(where: { $0.scoringUnitID == participant.id }),
              row.holesPlayed > 0 else { return nil }
        let relStr = Self.scoreReviewFormatRelative(Int(row.total.rounded()))
        let gross = row.holeValues.values.compactMap(\.rawStrokes).reduce(0, +)
        return gross > 0 ? "\(relStr) / \(gross)" : "\(relStr) / —"
    }

    nonisolated private static func scoreReviewFormatRelative(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private static func grossStrokesSum(participantID: String, snapshot: RoundSnapshot) -> Int {
        let holes = snapshot.roundSegment?.holeRange.holeNumbers ?? []
        let segmentIDs = snapshot.segmentScoreLookupSegmentIDs
        var sum = 0
        for hole in holes {
            for seg in segmentIDs {
                let id = ScoreEntry.makeID(hole: hole, segment: seg, scoringUnit: participantID)
                if let entry = snapshot.scoring.first(where: { $0.id == id }), let s = entry.strokes {
                    sum += s
                }
            }
        }
        return sum
    }

    private func courseSelection(from segment: CourseSegment?) -> SeriesCourseSelection? {
        guard let segment else { return nil }
        return SeriesCourseSelection(
            courseID: segment.courseInfo.golfCourseApiID.map(String.init) ?? segment.courseInfo.id,
            cachedName: segment.courseInfo.name,
            defaultTeeBoxID: segment.defaultTee ?? "",
            holeSegment: segment.holeSegment
        )
    }

    private func seriesMatchupPlans(
        from snapshot: RoundSnapshot,
        seriesRound: SeriesRound
    ) async -> [SeriesRoundMatchupPlan]? {
        let currentMatchups = snapshot.roundSegment?.matchups ?? []
        let validTeamMatchups = currentMatchups
            .filter { $0.effectiveMode == .team && $0.teamIDs.count == 2 }
        let validIndividualMatchups = currentMatchups
            .filter { $0.effectiveMode == .individual && ($0.participantIDs?.count ?? 0) == 2 }
        let validScoreOwnerMatchups = currentMatchups
            .filter { $0.effectiveMode == .partnership && ($0.scoreOwnerIDs?.count ?? 0) == 2 }

        let expectsMatchups = seriesRound.roundConfig.matchupMode == .teamVsTeam
            || seriesRound.roundConfig.matchupMode == .individualVsIndividual
            || seriesRound.roundConfig.matchupMode == .teeGroupPartnerships
        let preferredMode: MatchupMode
        if seriesRound.roundConfig.matchupMode == .teeGroupPartnerships || validScoreOwnerMatchups.isPopulated {
            preferredMode = .partnership
        } else {
            preferredMode = snapshot.requiresTeams ? .team : .individual
        }
        let hasPreferredMatchups: Bool
        switch preferredMode {
        case .team:
            hasPreferredMatchups = validTeamMatchups.isPopulated
        case .individual:
            hasPreferredMatchups = validIndividualMatchups.isPopulated
        case .partnership, .teeGroup, .scoreOwner:
            hasPreferredMatchups = validScoreOwnerMatchups.isPopulated
        }
        if !hasPreferredMatchups {
            return expectsMatchups ? [] : nil
        }

        let mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRound.id
        )
        let reverseTeamMapping = Dictionary(
            mappings
                .filter { $0.roundOwnerType == .team && $0.competitorType == .team }
                .map { ($0.roundOwnerID, $0.competitorID) },
            uniquingKeysWith: { _, new in new }
        )
        let reverseParticipantMapping = Dictionary(
            mappings
                .filter { $0.roundOwnerType == .participant && $0.competitorType == .member }
                .map { ($0.roundOwnerID, $0.competitorID) },
            uniquingKeysWith: { _, new in new }
        )
        let reverseScoreOwnerTeamMapping = Dictionary(
            mappings
                .filter { $0.roundOwnerType == .scoreOwner && $0.competitorType == .team }
                .map { ($0.roundOwnerID, $0.competitorID) },
            uniquingKeysWith: { _, new in new }
        )

        if preferredMode == .partnership {
            let updatedPlans = validScoreOwnerMatchups.enumerated().compactMap { index, matchup -> SeriesRoundMatchupPlan? in
                guard let scoreOwnerIDs = matchup.scoreOwnerIDs,
                      scoreOwnerIDs.count == 2,
                      scoreOwnerIDs[0] != scoreOwnerIDs[1],
                      let teamAID = reverseScoreOwnerTeamMapping[scoreOwnerIDs[0]],
                      let teamBID = reverseScoreOwnerTeamMapping[scoreOwnerIDs[1]],
                      teamAID != teamBID else { return nil }

                let existing = seriesRound.matchupPlans.first {
                    $0.id == matchup.id || Set([$0.pairAID ?? "", $0.pairBID ?? ""]) == Set(scoreOwnerIDs)
                }

                return SeriesRoundMatchupPlan(
                    id: existing?.id ?? matchup.id,
                    teamAID: teamAID,
                    teamBID: teamBID,
                    pairAID: scoreOwnerIDs[0],
                    pairBID: scoreOwnerIDs[1],
                    index: index,
                    podGroupingStrategy: existing?.podGroupingStrategy ?? seriesRound.roundConfig.podGroupingStrategy,
                    notes: existing?.notes,
                    isLocked: existing?.isLocked ?? false,
                    createdAt: existing?.createdAt ?? .init(),
                    lastUpdatedAt: .init()
                )
            }

            return updatedPlans.sorted { $0.index < $1.index }
        }

        if preferredMode == .individual {
            let updatedPlans = validIndividualMatchups.enumerated().compactMap { index, matchup -> SeriesRoundMatchupPlan? in
                guard let participantIDs = matchup.participantIDs,
                      participantIDs.count == 2,
                      let memberAID = reverseParticipantMapping[participantIDs[0]],
                      let memberBID = reverseParticipantMapping[participantIDs[1]],
                      memberAID != memberBID else { return nil }

                let existing = seriesRound.matchupPlans.first {
                    $0.id == matchup.id || Set([$0.memberAID ?? "", $0.memberBID ?? ""]) == Set([memberAID, memberBID])
                }

                return SeriesRoundMatchupPlan(
                    id: existing?.id ?? matchup.id,
                    memberAID: memberAID,
                    memberBID: memberBID,
                    index: index,
                    podGroupingStrategy: .disabled,
                    notes: existing?.notes,
                    isLocked: existing?.isLocked ?? false,
                    createdAt: existing?.createdAt ?? .init(),
                    lastUpdatedAt: .init()
                )
            }

            return updatedPlans.sorted { $0.index < $1.index }
        }

        let updatedPlans = validTeamMatchups.enumerated().compactMap { index, matchup -> SeriesRoundMatchupPlan? in
            guard let teamAID = reverseTeamMapping[matchup.teamIDs[0]],
                  let teamBID = reverseTeamMapping[matchup.teamIDs[1]],
                  teamAID != teamBID else { return nil }

            let existing = seriesRound.matchupPlans.first {
                $0.id == matchup.id || Set([$0.teamAID, $0.teamBID]) == Set([teamAID, teamBID])
            }

            return SeriesRoundMatchupPlan(
                id: existing?.id ?? matchup.id,
                teamAID: teamAID,
                teamBID: teamBID,
                index: index,
                podGroupingStrategy: existing?.podGroupingStrategy ?? seriesRound.roundConfig.podGroupingStrategy,
                notes: existing?.notes,
                isLocked: existing?.isLocked ?? false,
                createdAt: existing?.createdAt ?? .init(),
                lastUpdatedAt: .init()
            )
        }

        return updatedPlans.sorted { $0.index < $1.index }
    }

    private func resolvedDefaultCourseSelection(forRoundIndex roundIndex: Int) -> SeriesCourseSelection? {
        guard let defaultCourse = series.settings.defaultCourse else { return nil }
        guard series.settings.defaultCourseRotationMode == .alternateFrontBack else { return defaultCourse }

        let startingSegment = defaultCourse.holeSegment.isNineHoleLeagueSegment ? defaultCourse.holeSegment : HoleSegment.front9
        let matchingRoundsCount = rounds.filter { round in
            let selection = round.courseOverride ?? round.resolvedCourse(using: series)
            return selection?.courseID == defaultCourse.courseID && round.index < roundIndex
        }.count

        let resolvedSegment = matchingRoundsCount.isMultiple(of: 2)
            ? startingSegment
            : startingSegment.alternatingPairSegment
        return defaultCourse.applying(holeSegment: resolvedSegment)
    }

    private func scoringResult(from snapshot: RoundSnapshot, segment: RoundSegment) -> ScoringResult {
        Self.buildScoringResult(from: snapshot, segment: segment)
    }

    nonisolated static func buildScoringResult(from snapshot: RoundSnapshot, segment: RoundSegment) -> ScoringResult {
        let holes = scoringHoles(in: snapshot)
        return ScoringEngine.computeSnapshotResult(
            snapshot: snapshot,
            segment: segment,
            holes: holes,
            basis: snapshot.configuration.primaryFormat.configuration.basis,
            scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs
        )
    }

    private func holesForScoring(in snapshot: RoundSnapshot) -> [Hole] {
        Self.scoringHoles(in: snapshot)
    }

    nonisolated static func shouldUseTeamAggregateScoring(snapshot: RoundSnapshot, segment: RoundSegment) -> Bool {
        ScoringEngine.shouldUseTeamAggregateScoring(snapshot: snapshot, segment: segment)
    }

    private nonisolated static func scoringHoles(in snapshot: RoundSnapshot) -> [Hole] {
        let preferredTeeID = snapshot.courseSegment?.defaultTee
        let tee = preferredTeeID.flatMap { snapshot.courseSegment?.tee(from: $0) }
            ?? snapshot.courseSegment?.courseInfo.tees.first
        let allHoles = tee?.holes ?? []
        let sliced = Array(allHoles.slice(for: snapshot.holeSegment))
        return sliced.isEmpty ? allHoles : sliced
    }

    private struct AwardCompetitor {
        let roundOwnerID: String
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let competitorName: String
        let placement: Int?
        let tieGroupSize: Int?
        let reason: String?
        let rawScore: Double?
    }

    private func buildIndividualCompetitors(
        result: ScoringResult,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping]
    ) -> [AwardCompetitor] {
        if result.rows.contains(where: { $0.owner == .scoreOwner }) {
            let ownerRows = result.rows.map { row in
                OwnerPlacementRow(
                    roundOwnerID: row.scoringUnitID,
                    roundOwnerType: roundOwnerType(for: row.owner),
                    displayName: ownerDisplayName(for: row, snapshot: snapshot),
                    fallbackParticipantIDs: row.participantIDs,
                    fallbackTeamID: scoreOwnerFallbackTeamID(for: row, snapshot: snapshot),
                    score: row.total
                )
            }
            let ownerPlacements = buildOwnerPlacementGroups(
                for: ownerRows,
                highestWins: result.template.leaderboardSort == .highestWins
            )
            return ownerPlacements.flatMap { placement in
                expandAwardCompetitors(
                    placement,
                    competitorType: .member,
                    snapshot: snapshot,
                    mappings: mappings
                )
            }
        }

        let leaderboard = LeaderboardBuilder.buildIndividualLeaderboard(result: result, participants: snapshot.participants)
        let mappingByParticipant = Dictionary(uniqueKeysWithValues: mappings.compactMap { mapping -> (String, String)? in
            guard mapping.roundOwnerType == .participant, mapping.competitorType == .member else { return nil }
            return (mapping.roundOwnerID, mapping.competitorID)
        })

        return buildPlacementGroups(for: leaderboard.map { row in
            let participant = snapshot.participants.first(where: { $0.id == row.scoringUnitID })
            return AwardPlacementRow(
                roundOwnerID: row.scoringUnitID,
                competitorType: .member,
                competitorID: mappingByParticipant[row.scoringUnitID]
                    ?? participant?.seriesMemberID
                    ?? members.first(where: { $0.playerID == participant?.playerID })?.id
                    ?? row.scoringUnitID,
                competitorName: participant?.name.fullName ?? "Player",
                score: row.total
            )
        }, highestWins: result.template.leaderboardSort == .highestWins)
    }

    private func buildTeamCompetitors(
        result: ScoringResult,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping]
    ) -> [AwardCompetitor] {
        if result.rows.contains(where: { $0.owner == .scoreOwner }) {
            let ownerRows = result.rows.filter { $0.owner == .team || $0.owner == .scoreOwner }.map { row in
                OwnerPlacementRow(
                    roundOwnerID: row.scoringUnitID,
                    roundOwnerType: roundOwnerType(for: row.owner),
                    displayName: ownerDisplayName(for: row, snapshot: snapshot),
                    fallbackParticipantIDs: row.participantIDs,
                    fallbackTeamID: scoreOwnerFallbackTeamID(for: row, snapshot: snapshot),
                    score: row.total
                )
            }
            let ownerPlacements = buildOwnerPlacementGroups(
                for: ownerRows,
                highestWins: result.template.leaderboardSort == .highestWins
            )
            return ownerPlacements.flatMap { placement in
                expandAwardCompetitors(
                    placement,
                    competitorType: .team,
                    snapshot: snapshot,
                    mappings: mappings
                )
            }
        }

        let sections = LeaderboardBuilder.buildTeamSections(result: result, participants: snapshot.participants, teams: snapshot.teams)
        let mappingByTeamID = Dictionary(uniqueKeysWithValues: mappings.compactMap { mapping -> (String, String)? in
            guard mapping.roundOwnerType == .team, mapping.competitorType == .team else { return nil }
            return (mapping.roundOwnerID, mapping.competitorID)
        })
        let rows = sections.compactMap { section -> AwardPlacementRow? in
            guard section.id != LeaderboardBuilder.unassignedTeamSectionID else { return nil }
            return AwardPlacementRow(
                roundOwnerID: section.id,
                competitorType: .team,
                competitorID: mappingByTeamID[section.id] ?? section.id,
                competitorName: section.name,
                score: section.sectionTotal
            )
        }
        return buildPlacementGroups(for: rows, highestWins: result.template.leaderboardSort == .highestWins)
    }

    private func buildMatchupCompetitors(
        result: ScoringResult,
        snapshot: RoundSnapshot,
        awardTrack: SeriesAwardTrack,
        mappings: [SeriesRoundMapping]
    ) -> [AwardCompetitor] {
        var competitors: [AwardCompetitor] = []
        for matchupResult in result.matchupResults {
            let highestWins = matchupResult.isPointsFormat ?? (result.template.leaderboardSort == .highestWins)
            let sortedRows: [ScoringRow]
            let isMinimumCountTie: Bool
            if shouldResolveMinimumCountResult(matchupResult.minimumCountStatus, snapshot: snapshot),
               let minimumStatus = matchupResult.minimumCountStatus,
               minimumStatus.hasUnderMinimumSide {
                sortedRows = minimumCountResolvedRows(
                    matchupResult.rows,
                    matchup: matchupResult.matchup,
                    status: minimumStatus,
                    highestWins: highestWins
                )
                isMinimumCountTie = minimumStatus.bothSidesUnderMinimum
            } else {
                sortedRows = matchupResult.rows.sorted {
                    if $0.total != $1.total {
                        return highestWins ? $0.total > $1.total : $0.total < $1.total
                    }
                    return $0.scoringUnitID < $1.scoringUnitID
                }
                isMinimumCountTie = false
            }

            guard let first = sortedRows.first else { continue }
            let isTie = isMinimumCountTie || (sortedRows.count > 1 && sortedRows.allSatisfy { $0.total == first.total })
            for row in sortedRows {
                let competitorType: SeriesCompetitorType = awardTrack == .team ? .team : .member
                let placement = isTie ? 1 : (row.scoringUnitID == first.scoringUnitID ? 1 : 2)
                let ownerPlacement = OwnerPlacement(
                    roundOwnerID: row.scoringUnitID,
                    roundOwnerType: roundOwnerType(for: row.owner),
                    displayName: ownerDisplayName(for: row, snapshot: snapshot),
                    fallbackParticipantIDs: row.participantIDs,
                    fallbackTeamID: scoreOwnerFallbackTeamID(for: row, snapshot: snapshot),
                    rawScore: row.total,
                    placement: placement,
                    tieGroupSize: isTie ? sortedRows.count : nil,
                    reason: nil
                )
                competitors.append(contentsOf: expandAwardCompetitors(
                    ownerPlacement,
                    competitorType: competitorType,
                    snapshot: snapshot,
                    mappings: mappings
                ))
            }
        }
        return competitors
    }

    private func shouldResolveMinimumCountResult(
        _ status: MatchupMinimumCountStatus?,
        snapshot: RoundSnapshot
    ) -> Bool {
        guard let status, status.hasUnderMinimumSide else {
            return true
        }
        return status.hasStructuralShortage || snapshot.round.status == .complete
    }

    private func minimumCountResolvedRows(
        _ rows: [ScoringRow],
        matchup: TeamMatchup,
        status: MatchupMinimumCountStatus,
        highestWins: Bool
    ) -> [ScoringRow] {
        let pairingOrder = matchup.pairingIDs()
        let rowByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.scoringUnitID, $0) })
        if let winnerID = status.autoWinnerSideID,
           let winner = rowByID[winnerID] {
            let losers = pairingOrder
                .filter { $0 != winnerID }
                .compactMap { rowByID[$0] }
            let extras = rows.filter { row in
                row.scoringUnitID != winnerID && !pairingOrder.contains(row.scoringUnitID)
            }
            return [winner] + losers + extras
        }
        if status.bothSidesUnderMinimum {
            let ordered = pairingOrder.compactMap { rowByID[$0] }
            let extras = rows.filter { !pairingOrder.contains($0.scoringUnitID) }
            return ordered + extras
        }
        return rows.sorted {
            if $0.total != $1.total {
                return highestWins ? $0.total > $1.total : $0.total < $1.total
            }
            return $0.scoringUnitID < $1.scoringUnitID
        }
    }

    private struct AwardPlacementRow {
        let roundOwnerID: String
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let competitorName: String
        let score: Double
    }

    private struct OwnerPlacementRow {
        let roundOwnerID: String
        let roundOwnerType: SeriesRoundOwnerType
        let displayName: String
        let fallbackParticipantIDs: [String]
        let fallbackTeamID: String?
        let score: Double
    }

    private struct OwnerPlacement {
        let roundOwnerID: String
        let roundOwnerType: SeriesRoundOwnerType
        let displayName: String
        let fallbackParticipantIDs: [String]
        let fallbackTeamID: String?
        let rawScore: Double
        let placement: Int?
        let tieGroupSize: Int?
        let reason: String?
    }

    private func ownerDisplayName(for row: ScoringRow, snapshot: RoundSnapshot) -> String {
        switch row.owner {
        case .participant:
            return snapshot.participants.first(where: { $0.id == row.scoringUnitID })?.name.fullName ?? "Player"
        case .team:
            return snapshot.teams.first(where: { $0.id == row.scoringUnitID })?.name ?? "Team"
        case .scoreOwner:
            if let scoringGroup = snapshot.scoringGroup(id: row.scoringUnitID) {
                if let label = scoringGroup.label, label.isPopulated {
                    return label
                }
            }
            let names = row.participantIDs
                .compactMap { participantID in
                    snapshot.participants.first(where: { $0.id == participantID })?.name.fullName
                }
                .filter(\.isPopulated)
            return names.isPopulated ? names.joined(separator: " + ") : "Side"
        }
    }

    private func roundOwnerType(for owner: ScoringOwner) -> SeriesRoundOwnerType {
        switch owner {
        case .participant: return .participant
        case .team: return .team
        case .scoreOwner: return .scoreOwner
        }
    }

    private func scoreOwnerFallbackTeamID(for row: ScoringRow, snapshot: RoundSnapshot) -> String? {
        switch row.owner {
        case .team:
            return row.scoringUnitID
        case .scoreOwner:
            return snapshot.scoringGroup(id: row.scoringUnitID)?.teamID
        case .participant:
            return snapshot.participants.first(where: { $0.id == row.scoringUnitID })?.teamID
        }
    }

    private func buildOwnerPlacementGroups(
        for rows: [OwnerPlacementRow],
        highestWins: Bool
    ) -> [OwnerPlacement] {
        let sortedRows = rows.sorted {
            if $0.score != $1.score {
                return highestWins ? $0.score > $1.score : $0.score < $1.score
            }
            return $0.displayName < $1.displayName
        }

        var placements: [OwnerPlacement] = []
        var placement = 1
        var index = 0

        while index < sortedRows.count {
            let score = sortedRows[index].score
            var group: [OwnerPlacementRow] = []
            while index < sortedRows.count, sortedRows[index].score == score {
                group.append(sortedRows[index])
                index += 1
            }
            for row in group {
                placements.append(
                    OwnerPlacement(
                        roundOwnerID: row.roundOwnerID,
                        roundOwnerType: row.roundOwnerType,
                        displayName: row.displayName,
                        fallbackParticipantIDs: row.fallbackParticipantIDs,
                        fallbackTeamID: row.fallbackTeamID,
                        rawScore: row.score,
                        placement: placement,
                        tieGroupSize: group.count > 1 ? group.count : nil,
                        reason: nil
                    )
                )
            }
            placement += group.count
        }

        return placements
    }

    private func expandAwardCompetitors(
        _ ownerPlacement: OwnerPlacement,
        competitorType: SeriesCompetitorType,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping]
    ) -> [AwardCompetitor] {
        let mapped = mappings.filter {
            $0.roundOwnerID == ownerPlacement.roundOwnerID
                && $0.roundOwnerType == ownerPlacement.roundOwnerType
                && $0.competitorType == competitorType
        }

        let resolvedMappings: [(id: String, name: String)] = {
            if mapped.isPopulated {
                return mapped.map { mapping in
                    (
                        id: mapping.competitorID,
                        name: competitorName(
                            for: mapping.competitorID,
                            type: competitorType,
                            snapshot: snapshot
                        )
                    )
                }
            }

            switch competitorType {
            case .team:
                guard let teamID = ownerPlacement.fallbackTeamID else { return [] }
                return [(id: teamID, name: competitorName(for: teamID, type: .team, snapshot: snapshot))]
            case .member:
                return ownerPlacement.fallbackParticipantIDs.compactMap { participantID in
                    guard let participant = snapshot.participants.first(where: { $0.id == participantID }) else { return nil }
                    let memberID = participant.seriesMemberID
                        ?? members.first(where: { $0.playerID == participant.playerID })?.id
                        ?? participantID
                    return (
                        id: memberID,
                        name: competitorName(for: memberID, type: .member, snapshot: snapshot)
                    )
                }
            }
        }()

        return resolvedMappings.map { item in
            AwardCompetitor(
                roundOwnerID: ownerPlacement.roundOwnerID,
                competitorType: competitorType,
                competitorID: item.id,
                competitorName: item.name,
                placement: ownerPlacement.placement,
                tieGroupSize: ownerPlacement.tieGroupSize,
                reason: ownerPlacement.reason,
                rawScore: ownerPlacement.rawScore
            )
        }
    }

    private func competitorName(
        for competitorID: String,
        type: SeriesCompetitorType,
        snapshot: RoundSnapshot
    ) -> String {
        switch type {
        case .team:
            return snapshot.teams.first(where: { $0.id == competitorID })?.name
                ?? teams.first(where: { $0.id == competitorID })?.name
                ?? "Team"
        case .member:
            return members.first(where: { $0.id == competitorID })?.name.fullName
                ?? snapshot.participants.first(where: { $0.seriesMemberID == competitorID })?.name.fullName
                ?? "Player"
        }
    }

    private func buildPlacementGroups(for rows: [AwardPlacementRow], highestWins: Bool) -> [AwardCompetitor] {
        let sortedRows = rows.sorted {
            if $0.score != $1.score {
                return highestWins ? $0.score > $1.score : $0.score < $1.score
            }
            return $0.competitorName < $1.competitorName
        }

        var competitors: [AwardCompetitor] = []
        var placement = 1
        var index = 0

        while index < sortedRows.count {
            let score = sortedRows[index].score
            var group: [AwardPlacementRow] = []
            while index < sortedRows.count, sortedRows[index].score == score {
                group.append(sortedRows[index])
                index += 1
            }
            for row in group {
                competitors.append(
                    AwardCompetitor(
                        roundOwnerID: row.roundOwnerID,
                        competitorType: row.competitorType,
                        competitorID: row.competitorID,
                        competitorName: row.competitorName,
                        placement: placement,
                        tieGroupSize: group.count > 1 ? group.count : nil,
                        reason: nil,
                        rawScore: row.score
                    )
                )
            }
            placement += group.count
        }

        return competitors
    }

    private func resolvePoints(placement: Int, tieGroupSize: Int, profile: SeriesScoringProfile) -> Double? {
        func points(at rank: Int) -> Double {
            profile.placementRules.first(where: { rank >= $0.rankStart && rank <= $0.rankEnd })?.points ?? 0
        }

        switch profile.kind {
        case .placement:
            let occupiedRanks = Array(placement..<(placement + max(1, tieGroupSize)))
            let total = occupiedRanks.reduce(0.0) { partial, rank in partial + points(at: rank) }
            return total / Double(max(1, tieGroupSize))
        case .accrueFromIndividual:
            return nil
        case .winTieLoss:
            guard let resultPoints = profile.resultPoints else { return 0 }
            if tieGroupSize > 1 {
                return resultPoints.tiePoints
            }
            return placement == 1 ? resultPoints.winPoints : resultPoints.lossPoints
        case .manual:
            return nil
        }
    }

    /// Assigns a `share_code` when missing (older series documents) so join links work.
    func ensureShareCodeIfNeeded() async {
        guard !series.shareCode.isPopulated else { return }
        let code = await FirebaseService.shared.getUniqueShareCode()
        var updated = series
        updated.shareCode = code
        updated.lastUpdatedAt = Time()
        switch await FirebaseService.shared.updateSeries(updated) {
        case .success(let saved):
            series = saved
        case .failure(let error):
            addBreadcrumb(level: .warning, message: "Failed to assign series share code", error: error)
        }
    }

    private func standingsSort(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.bestPlacement != rhs.bestPlacement { return (lhs.bestPlacement ?? .max) < (rhs.bestPlacement ?? .max) }
        return lhs.competitorName < rhs.competitorName
    }
}
