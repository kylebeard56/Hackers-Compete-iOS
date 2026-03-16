//
//  SeriesViewModel.swift
//  Hackers
//

import SwiftUI

@MainActor
final class SeriesViewModel: ObservableObject {

    @Published var series: Series = .init()
    @Published var members: [SeriesMember] = []
    @Published var teams: [SeriesTeam] = []
    @Published var rounds: [SeriesRound] = []
    @Published var scoringProfiles: [SeriesScoringProfile] = []
    @Published var standings: [SeriesStanding] = []
    @Published var handicapScores: [SeriesHandicapScore] = []
    @Published var memberHandicaps: [String: SeriesMemberHandicap] = [:]

    @Published var isLoading = true
    @Published var isSaving = false

    var seriesID: String { series.id }

    var isCommissioner: Bool {
        guard let userID = currentUserID else { return false }
        return series.commissionerUserID == userID
    }

    var currentUserID: String?
    var currentPlayerID: String?

    var activeMembers: [SeriesMember] {
        members.filter { $0.isActive }.sorted {
            $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
        }
    }

    var upcomingRounds: [SeriesRound] {
        rounds.filter { $0.status == .planned || $0.status == .lobby || $0.status == .live }
            .sorted { $0.index < $1.index }
    }

    var completedRounds: [SeriesRound] {
        rounds.filter { $0.status == .complete }
            .sorted { ($0.completedAt?.unix ?? 0) > ($1.completedAt?.unix ?? 0) }
    }

    var individualStandings: [SeriesStanding] {
        standings.filter { $0.competitorType == .member }
            .sorted { $0.totalPoints > $1.totalPoints }
    }

    var teamStandings: [SeriesStanding] {
        standings.filter { $0.competitorType == .team }
            .sorted { $0.totalPoints > $1.totalPoints }
    }

    var hasTeams: Bool { !teams.isEmpty }

    // MARK: - Checklist

    var hasPlayers: Bool { members.contains { $0.role != .commissioner && $0.isActive } }
    var hasScheduledRound: Bool { !rounds.isEmpty }
    var hasScoringRules: Bool { !scoringProfiles.isEmpty || series.defaults.defaultScoringProfileID != nil }
    var checklistComplete: Bool { hasPlayers && hasScheduledRound && hasScoringRules }

    // MARK: - Load

    func load(seriesID: String) async {
        isLoading = true
        defer { isLoading = false }

        if let user = await AppData.shared.user {
            currentUserID = user.id
        }
        if let player = await AppData.shared.getPrimaryPlayer() {
            currentPlayerID = player.id
        }

        switch await FirebaseService.shared.fetchSeries(id: seriesID) {
        case .success(let s): series = s
        case .failure: break
        }

        async let m = FirebaseService.shared.fetchSeriesMembers(seriesID: seriesID)
        async let t = FirebaseService.shared.fetchSeriesTeams(seriesID: seriesID)
        async let r = FirebaseService.shared.fetchSeriesRounds(seriesID: seriesID)
        async let sp = FirebaseService.shared.fetchScoringProfiles(seriesID: seriesID)
        async let st = FirebaseService.shared.fetchStandings(seriesID: seriesID)
        async let hs = FirebaseService.shared.fetchHandicapScores(seriesID: seriesID)

        members = await m
        teams = await t
        rounds = await r
        scoringProfiles = await sp
        standings = await st
        handicapScores = await hs

        recomputeAllHandicaps()
    }

    // MARK: - Series mutations

    func updateName(_ newName: String) async {
        series.name = newName
        series.lastUpdatedAt = Time()
        _ = await FirebaseService.shared.updateSeries(series)
    }

    // MARK: - Member mutations

    func addMember(_ player: Player) async {
        let member = SeriesMember(
            id: HackersID.string(),
            userID: player.userID,
            playerID: player.id,
            name: player.name,
            role: .member,
            isActive: true,
            joinedAt: Time(),
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesMember(member) {
        case .success(let m):
            members.append(m)
            if let pid = m.playerID {
                try? await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: pid)
            }
        case .failure: break
        }
    }

    func addOfflineMember(name: Name) async {
        let member = SeriesMember(
            id: HackersID.string(),
            name: name,
            role: .member,
            isActive: true,
            joinedAt: Time(),
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesMember(member) {
        case .success(let m): members.append(m)
        case .failure: break
        }
    }

    func updateMemberTeeBox(_ member: SeriesMember, teeBoxID: String?) async {
        guard let idx = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[idx].defaultTeeBoxID = teeBoxID
        members[idx].lastUpdatedAt = Time()
        _ = await FirebaseService.shared.updateSeriesMember(members[idx])
    }

    // MARK: - Round mutations

    func addRound(title: String, scheduledAt: Time? = nil, format: GameFormat = .strokePlay) async -> SeriesRound? {
        let nextIndex = (rounds.map(\.index).max() ?? -1) + 1
        let round = SeriesRound(
            id: HackersID.string(),
            title: title,
            index: nextIndex,
            status: .planned,
            scheduledAt: scheduledAt,
            format: format,
            scoringProfileID: series.defaults.defaultScoringProfileID,
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesRound(round) {
        case .success(let r):
            rounds.append(r)
            return r
        case .failure:
            return nil
        }
    }

    func duplicateRound(_ source: SeriesRound) async -> SeriesRound? {
        let nextIndex = (rounds.map(\.index).max() ?? -1) + 1
        let clone = SeriesRound(
            id: HackersID.string(),
            title: "\(source.title) (copy)",
            index: nextIndex,
            status: .planned,
            format: source.format,
            scoringProfileID: source.scoringProfileID,
            notes: source.notes,
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesRound(clone) {
        case .success(let r):
            rounds.append(r)
            return r
        case .failure:
            return nil
        }
    }

    // MARK: - Scoring profile

    func createMatchupScoringProfile() async -> SeriesScoringProfile? {
        let profile = SeriesScoringProfile(
            id: HackersID.string(),
            name: "Win / Tie / Loss",
            summary: "1 point for a win, 0.5 for a tie, 0 for a loss",
            template: .winTieLoss,
            outcomeSource: .roundMatchResult,
            competitorType: hasTeams ? .team : .member,
            tieHandling: .splitPoints,
            placementRules: [
                .init(id: HackersID.string(), rankStart: 1, rankEnd: 1, points: 1.0),
                .init(id: HackersID.string(), rankStart: 2, rankEnd: 2, points: 0.0),
            ],
            isDefault: true,
            createdByPlayerID: currentPlayerID,
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addScoringProfile(profile) {
        case .success(let p):
            scoringProfiles.append(p)
            series.defaults.defaultScoringProfileID = p.id
            series.lastUpdatedAt = Time()
            _ = await FirebaseService.shared.updateSeries(series)
            return p
        case .failure:
            return nil
        }
    }

    // MARK: - Handicap

    func recomputeAllHandicaps() {
        guard series.handicapConfig.isEnabled else { return }
        let config = series.handicapConfig.config.toConfig()

        for member in activeMembers {
            let scores = handicapScores
                .filter { $0.memberID == member.id }
                .sorted { $0.createdAt.unix < $1.createdAt.unix }
                .map(\.score)

            let result = computeHandicapIndex(scores: scores, config: config)
            var hc = memberHandicaps[member.id] ?? SeriesMemberHandicap(id: member.id, memberID: member.id)
            hc.computedIndex = result?.handicapIndex
            memberHandicaps[member.id] = hc
        }
    }

    func setHandicapOverride(memberID: String, value: Double?, isOverridden: Bool) {
        var hc = memberHandicaps[memberID] ?? SeriesMemberHandicap(id: memberID, memberID: memberID)
        hc.overrideIndex = value
        hc.isOverridden = isOverridden
        memberHandicaps[memberID] = hc
    }

    func addBaselineScore(memberID: String, score: Double, par: Double = 36, segment: HoleSegment = .front9) async {
        let entry = SeriesHandicapScore(
            id: HackersID.string(),
            memberID: memberID,
            score: score,
            holeSegment: segment,
            par: par,
            source: .baseline,
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addHandicapScore(entry) {
        case .success(let s):
            handicapScores.append(s)
            recomputeAllHandicaps()
        case .failure: break
        }
    }

    func effectiveHandicap(for memberID: String) -> Double? {
        memberHandicaps[memberID]?.effectiveIndex
    }

    // MARK: - Create Live Round from Series

    func createLiveRound(from seriesRound: SeriesRound) async -> String? {
        guard let roundID = await SeriesRoundCreationService().createRoundFromSeries(
            series: series,
            seriesRound: seriesRound,
            members: activeMembers,
            teams: teams,
            handicaps: memberHandicaps
        ) else { return nil }

        if let idx = rounds.firstIndex(where: { $0.id == seriesRound.id }) {
            rounds[idx].roundID = roundID
            rounds[idx].status = .lobby
            rounds[idx].lastUpdatedAt = Time()
            _ = await FirebaseService.shared.updateSeriesRound(rounds[idx])
        }

        return roundID
    }

    // MARK: - Round Completion / Points

    /// Called when a series round is marked complete; computes point awards from matchup results.
    func finalizeRoundAwards(seriesRound: SeriesRound, matchResults: [MatchResult]) async {
        guard let profile = scoringProfile(for: seriesRound) else { return }

        for result in matchResults {
            let points: Double
            switch result.outcome {
            case .win: points = profile.placementRules.first(where: { $0.rankStart == 1 })?.points ?? 1.0
            case .loss: points = profile.placementRules.first(where: { $0.rankStart == 2 })?.points ?? 0
            case .tie: points = 0.5
            }

            let award = SeriesPointAward(
                id: "\(seriesRound.id)_\(result.competitorID)",
                seriesRoundID: seriesRound.id,
                competitorType: profile.competitorType,
                competitorID: result.competitorID,
                competitorName: result.competitorName,
                placement: result.outcome == .win ? 1 : (result.outcome == .tie ? 1 : 2),
                basePoints: points,
                bonusPoints: 0,
                totalPoints: points,
                source: .automatic,
                awardedAt: Time(),
                createdAt: Time(),
                lastUpdatedAt: Time(),
                parentID: seriesID
            )
            _ = await FirebaseService.shared.addPointAward(award)
        }

        await rebuildStandings()
    }

    private func scoringProfile(for round: SeriesRound) -> SeriesScoringProfile? {
        if let id = round.scoringProfileID {
            return scoringProfiles.first { $0.id == id }
        }
        return scoringProfiles.first { $0.isDefault }
    }

    // MARK: - Score Ingestion

    /// When a series round completes, pull participant stroke totals into handicap scores.
    func ingestRoundScores(seriesRound: SeriesRound, participants: [RoundParticipant], scoresByParticipant: [String: Double]) async {
        guard series.handicapConfig.isEnabled else { return }

        for participant in participants {
            let memberID = resolveMemberID(for: participant)
            guard let memberID, let totalStrokes = scoresByParticipant[participant.id] else { continue }

            let alreadyIngested = handicapScores.contains {
                if case .round(let rid) = $0.source {
                    return rid == seriesRound.roundID && $0.memberID == memberID
                }
                return false
            }
            guard !alreadyIngested else { continue }

            await addRoundScore(
                memberID: memberID,
                score: totalStrokes,
                roundID: seriesRound.roundID ?? seriesRound.id
            )
        }
    }

    private func resolveMemberID(for participant: RoundParticipant) -> String? {
        if let smid = participant.seriesMemberID {
            return smid
        }
        if let pid = participant.playerID {
            return members.first { $0.playerID == pid }?.id
        }
        return nil
    }

    private func addRoundScore(memberID: String, score: Double, roundID: String) async {
        let entry = SeriesHandicapScore(
            id: HackersID.string(),
            memberID: memberID,
            score: score,
            holeSegment: .front9,
            par: series.handicapConfig.config.defaultParForIndex,
            source: .round(roundID: roundID),
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addHandicapScore(entry) {
        case .success(let s):
            handicapScores.append(s)
            recomputeAllHandicaps()
        case .failure: break
        }
    }

    /// Recompute standings from all point awards.
    func rebuildStandings() async {
        let awards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        var standingMap: [String: SeriesStanding] = [:]

        for award in awards {
            var existing = standingMap[award.competitorID] ?? SeriesStanding(
                id: award.competitorID,
                competitorType: award.competitorType,
                competitorID: award.competitorID,
                competitorName: award.competitorName,
                parentID: seriesID
            )
            existing.totalPoints += award.totalPoints
            existing.roundsCounted += 1
            if award.placement == 1 { existing.wins += 1 }
            if let p = award.placement, p <= 3 { existing.topThrees += 1 }
            existing.lastPlacement = award.placement
            if let best = existing.bestPlacement {
                existing.bestPlacement = min(best, award.placement ?? best)
            } else {
                existing.bestPlacement = award.placement
            }
            existing.lastUpdatedAt = Time()
            standingMap[award.competitorID] = existing
        }

        let sorted = standingMap.values.sorted { $0.totalPoints > $1.totalPoints }
        for (index, var standing) in sorted.enumerated() {
            standing.rank = index + 1
            _ = await FirebaseService.shared.updateStanding(standing)
        }

        standings = sorted.enumerated().map { idx, s in
            var updated = s
            updated.rank = idx + 1
            return updated
        }
    }
}

// MARK: - Match Result Model

struct MatchResult {
    let competitorID: String
    let competitorName: String
    let outcome: MatchOutcome
}

enum MatchOutcome {
    case win, loss, tie
}
