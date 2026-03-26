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
    var defaultTeamScoringProfileID: String?
    var defaultIndividualScoringProfileID: String?
    var handicapConfig: SeriesHandicapConfig
    var allowRoundEditsAfterLobbyCreation: Bool
    var autoFinalizeAwardsOnRoundCompletion: Bool
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
        defaultTeamScoringProfileID = settings.defaultTeamScoringProfileID
        defaultIndividualScoringProfileID = settings.defaultIndividualScoringProfileID
        handicapConfig = settings.handicapConfig
        allowRoundEditsAfterLobbyCreation = settings.allowRoundEditsAfterLobbyCreation
        autoFinalizeAwardsOnRoundCompletion = settings.autoFinalizeAwardsOnRoundCompletion
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
    @Published var attendanceByMember: [String: SeriesRoundAttendance] = [:]
    @Published var attendanceByRound: [String: [SeriesRoundAttendance]] = [:]
    @Published var linkedRounds: [String: Round] = [:]
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var creatingRoundID: String?
    @Published var correctingRoundID: String?
    @Published var exportingRoundID: String?
    @Published var exportedCSVURL: URL?
    @Published var seriesCourseTeesByCourseID: [String: [Tee]] = [:]

    var seriesID: String { series.id }
    var currentUserID: String?
    var currentPlayerID: String?

    var isCommissioner: Bool {
        guard let userID = currentUserID else { return false }
        return series.commissionerUserID == userID
    }

    var currentMemberID: String? {
        guard let playerID = currentPlayerID else { return nil }
        return activeMembers.first { $0.playerID == playerID }?.id
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
        teams.sorted { $0.index < $1.index }
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

    var upcomingRounds: [SeriesRound] {
        rounds
            .filter {
                let status = effectiveStatus(for: $0)
                return status == .planned || status == .lobby || status == .live
            }
            .sorted {
                let lhs = $0.scheduledAt?.unix ?? .greatestFiniteMagnitude
                let rhs = $1.scheduledAt?.unix ?? .greatestFiniteMagnitude
                if lhs != rhs { return lhs < rhs }
                return $0.index < $1.index
            }
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

    var hasTeams: Bool {
        series.settings.useTeams || !teams.isEmpty
    }

    var usesTeams: Bool {
        series.settings.useTeams
    }

    var hasPlayers: Bool { eligibleMembers.count > 2 }
    var hasScheduledRound: Bool { rounds.isPopulated }
    var hasScoringRules: Bool { isLeagueRulesConfirmed(for: series.settings) }
    var hasDefaultCourse: Bool { series.settings.defaultCourse?.isConfigured == true }
    var skippedDefaultCourse: Bool { false }
    var checklistComplete: Bool { hasPlayers && hasScheduledRound && hasScoringRules }

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
        return mapLinkedRoundStatus(linkedRound.status)
    }

    func effectiveRoundConfig(for seriesRound: SeriesRound) -> SeriesRoundConfiguration {
        guard let roundID = seriesRound.roundID,
              let linkedRound = linkedRounds[roundID] else { return seriesRound.roundConfig }
        return roundConfig(from: linkedRound, fallback: seriesRound.roundConfig)
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

    func suggestedIndividualMatchupPlans(
        preserving existingPlans: [SeriesRoundMatchupPlan] = []
    ) -> [SeriesRoundMatchupPlan] {
        let orderedMembers = eligibleMembers
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
        defer { isLoading = false }

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

        await loadLinkedRounds()
        await loadAttendanceForVisibleRounds()
        recomputeAllHandicaps()
        await syncLinkedRoundState()
        await refreshSeriesCachesIfNeeded()
    }

    private func loadLinkedRounds() async {
        let roundIDs = Set(rounds.compactMap(\.roundID).filter(\.isPopulated))
        guard roundIDs.isPopulated else {
            linkedRounds = [:]
            return
        }

        var fetched: [String: Round] = [:]
        for roundID in roundIDs {
            if case .success(let round) = await FirebaseService.shared.getRoundByID(roundID) {
                fetched[roundID] = round
            }
        }
        linkedRounds = fetched
    }

    func loadAttendanceForVisibleRounds() async {
        var dictionary: [String: [SeriesRoundAttendance]] = [:]
        for round in rounds where round.status != .canceled {
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
    }

    func clearDefaultCourse() async {
        series.settings.defaultCourse = nil
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
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
        await refreshSeriesCachesIfNeeded()
    }

    func confirmLeagueRules(_ settings: SeriesSettings) async {
        let sanitized = sanitizedLeagueSettings(settings)
        series.settings = sanitized
        series.leagueRulesConfirmedAt = .init()
        series.leagueRulesConfirmedByUserID = currentUserID ?? series.commissionerUserID
        series.leagueRulesSignature = materialLeagueRulesSignature(for: sanitized)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        await refreshSeriesCachesIfNeeded()
    }

    func saveHandicapSettings(_ handicapConfig: SeriesHandicapConfig) async {
        let previousSettings = series.settings
        series.handicapConfig = handicapConfig
        invalidateLeagueRulesConfirmationIfNeeded(previousSettings: previousSettings, newSettings: series.settings)
        series.lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeries(series)
        recomputeAllHandicaps()
        await refreshSeriesCachesIfNeeded()
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

        await removeActiveMember(at: index, fallbackPlayerID: resolvedPlayerID)
    }

    /// Removes a roster member by id (commissioner only). Used from roster ellipsis menu.
    func removeMember(_ member: SeriesMember) async {
        guard isCommissioner else { return }
        guard member.role != .commissioner else { return }
        guard let index = members.firstIndex(where: { $0.id == member.id && $0.isActive }) else { return }
        await removeActiveMember(at: index, fallbackPlayerID: member.playerID ?? "")
    }

    private func removeActiveMember(at index: Int, fallbackPlayerID: String) async {
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
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to remove series member", error: error)
        }
    }

    func updateMemberTeeBox(_ member: SeriesMember, teeBoxID: String?) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].defaultTeeBoxID = teeBoxID
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
    }

    func updateMemberRole(_ member: SeriesMember, role: SeriesMemberRole) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].role = role
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
    }

    func updateMemberTeam(_ member: SeriesMember, teamID: String?) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].teamID = teamID
        members[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesMember(members[index])
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
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to create series invite", error: error)
        }
    }

    func resolveInvite(_ invite: SeriesInvite, status: SeriesInviteStatus) async {
        guard let index = invites.firstIndex(where: { $0.id == invite.id }) else { return }
        invites[index].status = status
        invites[index].respondedAt = .init()
        _ = await FirebaseService.shared.updateSeriesInvite(invites[index])
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
            notes: nil
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
        notes: String?
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
        notes: String? = nil
    ) async {
        guard let index = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        if let title { rounds[index].title = title }
        rounds[index].scheduledAt = scheduledAt
        if let roundConfig { rounds[index].roundConfig = roundConfig }
        if let matchupPlans { rounds[index].matchupPlans = matchupPlans.sorted { $0.index < $1.index } }
        if let notes { rounds[index].notes = notes }
        if shouldUpdateCourseOverride {
            rounds[index].courseOverride = courseOverride
        }
        rounds[index].teamScoringProfileID = teamScoringProfileID
        rounds[index].individualScoringProfileID = individualScoringProfileID
        rounds[index].lastUpdatedAt = .init()
        _ = await FirebaseService.shared.updateSeriesRound(rounds[index])
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
            notes: source.notes
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

    func updateAttendance(
        seriesRoundID: String,
        memberID: String,
        status: SeriesRoundAttendanceStatus,
        declinedNote: String?
    ) async {
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
            if currentMemberID == memberID {
                attendanceByMember[memberID] = saved
            }
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to update attendance", error: error)
        }
    }

    private func seedAttendance(for round: SeriesRound) async {
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

        for profile in profiles {
            switch await FirebaseService.shared.addScoringProfile(profile) {
            case .success(let created):
                scoringProfiles.append(created)
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
    }

    func createMatchupScoringProfile() async -> SeriesScoringProfile? {
        await createBuiltInScoringProfilesIfNeeded()
        return scoringProfiles.first(where: { $0.kind == .winTieLoss && $0.outcomeSource == .roundMatchResult && $0.competitorType == .team })
    }

    @discardableResult
    func saveScoringProfile(_ profile: SeriesScoringProfile) async -> SeriesScoringProfile? {
        if scoringProfiles.contains(where: { $0.id == profile.id }) {
            switch await FirebaseService.shared.updateScoringProfile(profile) {
            case .success(let updated):
                if let index = scoringProfiles.firstIndex(where: { $0.id == updated.id }) {
                    scoringProfiles[index] = updated
                }
                return updated
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to update scoring profile", error: error)
                return nil
            }
        }

        switch await FirebaseService.shared.addScoringProfile(profile) {
        case .success(let created):
            scoringProfiles.append(created)
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
            notes: nil
        )
    }

    // MARK: - Handicap

    func recomputeAllHandicaps() {
        memberHandicaps = Dictionary(uniqueKeysWithValues: eligibleMembers.map { ($0.id, SeriesMemberHandicap(id: $0.id, memberID: $0.id)) })

        guard series.handicapConfig.isEnabled else { return }
        let config = series.handicapConfig.config.toConfig()
        let overridesByMember = Dictionary(uniqueKeysWithValues: handicapOverrides.map { ($0.memberID, $0) })

        for member in eligibleMembers {
            let scores = handicapScores
                .filter { $0.memberID == member.id }
                .sorted { $0.createdAt.unix < $1.createdAt.unix }
                .map(\.score)

            let result = computeHandicapIndex(scores: scores, config: config)
            let override = overridesByMember[member.id]
            memberHandicaps[member.id] = SeriesMemberHandicap(
                id: member.id,
                memberID: member.id,
                computedIndex: result?.handicapIndex,
                overrideIndex: override?.overrideIndex,
                isOverridden: override?.isEnabled == true
            )
        }
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
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to save handicap override", error: error)
        }
    }

    func addBaselineScore(memberID: String, score: Double, par: Double = 36, segment: HoleSegment = .front9) async {
        let entry = SeriesHandicapScore(
            id: HackersID.string(),
            memberID: memberID,
            score: score,
            par: par,
            holeSegment: segment,
            source: .baseline,
            sourceRoundID: nil,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addHandicapScore(entry) {
        case .success(let saved):
            handicapScores.append(saved)
            recomputeAllHandicaps()
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add baseline score", error: error)
        }
    }

    // MARK: - Round Creation

    func createLiveRound(from seriesRound: SeriesRound, courseSegment: CourseSegment? = nil) async -> String? {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == seriesRound.id }) else { return nil }
        creatingRoundID = seriesRound.id
        defer { creatingRoundID = nil }

        let attendance = attendanceByRound[seriesRound.id] ?? []
        let attendanceByMemberID = Dictionary(uniqueKeysWithValues: attendance.map { ($0.memberID, $0) })
        let participants = eligibleMembers.filter { member in
            guard let attendance = attendanceByMemberID[member.id] else {
                return series.settings.attendanceDefault != .no
            }
            return attendance.status == SeriesRoundAttendanceStatus.pending.rawValue
                || attendance.status == SeriesRoundAttendanceStatus.accepted.rawValue
        }

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

    func refreshLinkedRoundState() async {
        await loadLinkedRounds()
        await syncLinkedRoundState()
    }

    private func syncLinkedRoundState() async {
        guard linkedRounds.isPopulated else { return }

        var changedRounds: [SeriesRound] = []
        var finalizedAnyRound = false

        for roundIndex in rounds.indices {
            guard let roundID = rounds[roundIndex].roundID,
                  let linkedRound = linkedRounds[roundID] else { continue }

            let newStatus = mapLinkedRoundStatus(linkedRound.status)
            var hasChanged = false

            if rounds[roundIndex].status != newStatus {
                rounds[roundIndex].status = newStatus
                hasChanged = true
            }
            if newStatus == .lobby || newStatus == .live {
                if rounds[roundIndex].startedAt == nil {
                    rounds[roundIndex].startedAt = linkedRound.lastUpdatedAt
                    hasChanged = true
                }
            }
            let shouldBackPropagate = rounds[roundIndex].roundConfig.allowLobbyBackPropagation
                && (newStatus == .lobby || newStatus == .live || newStatus == .complete)
            let snapshot = shouldBackPropagate || newStatus == .complete
                ? await loadRoundSnapshot(roundID: roundID)
                : nil

            if let snapshot, shouldBackPropagate {
                let updatedConfig = roundConfig(from: linkedRound, fallback: rounds[roundIndex].roundConfig)
                if rounds[roundIndex].roundConfig != updatedConfig {
                    rounds[roundIndex].roundConfig = updatedConfig
                    hasChanged = true
                }

                let syncedCourse = courseSelection(from: snapshot.courseSegment)
                if rounds[roundIndex].courseOverride != syncedCourse {
                    rounds[roundIndex].courseOverride = syncedCourse
                    hasChanged = true
                }

                if let syncedMatchups = await seriesMatchupPlans(from: snapshot, seriesRound: rounds[roundIndex]),
                   rounds[roundIndex].matchupPlans != syncedMatchups {
                    rounds[roundIndex].matchupPlans = syncedMatchups
                    hasChanged = true
                }
            }

            if newStatus == .complete {
                if rounds[roundIndex].completedAt == nil {
                    rounds[roundIndex].completedAt = linkedRound.lastUpdatedAt
                    hasChanged = true
                }

                if let snapshot {
                    let finalized = await processCompletedRound(seriesRound: rounds[roundIndex], snapshot: snapshot)
                    finalizedAnyRound = finalizedAnyRound || finalized
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

        if finalizedAnyRound {
            pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
            standings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)
        }

        await refreshSeriesCachesIfNeeded()
    }

    private func processCompletedRound(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        overwriteDerivedData: Bool = false
    ) async -> Bool {
        var changed = false

        if series.handicapConfig.isEnabled {
            let didIngest = await ingestRoundScores(
                seriesRound: seriesRound,
                snapshot: snapshot,
                replacingExisting: overwriteDerivedData
            )
            changed = changed || didIngest
        }

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
        let teamProfile = scoringProfile(id: seriesRound.teamScoringProfileID ?? series.settings.defaultTeamScoringProfileID)
        let individualProfile = scoringProfile(id: seriesRound.individualScoringProfileID ?? series.settings.defaultIndividualScoringProfileID)

        guard teamProfile != nil || individualProfile != nil else { return .pending }

        let existingAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID, seriesRoundID: seriesRound.id)
        for award in existingAwards {
            _ = await FirebaseService.shared.deletePointAward(award)
        }

        var needsReview = false
        var newAwards: [SeriesPointAward] = []

        if let teamProfile {
            switch await buildAwards(
                seriesRound: seriesRound,
                snapshot: snapshot,
                awardTrack: .team,
                profile: teamProfile
            ) {
            case .success(let awards):
                newAwards.append(contentsOf: awards)
            case .needsReview:
                needsReview = true
            }
        }

        if let individualProfile {
            switch await buildAwards(
                seriesRound: seriesRound,
                snapshot: snapshot,
                awardTrack: .individual,
                profile: individualProfile
            ) {
            case .success(let awards):
                newAwards.append(contentsOf: awards)
            case .needsReview:
                needsReview = true
            }
        }

        for award in newAwards {
            _ = await FirebaseService.shared.upsertPointAward(award)
        }

        pointAwards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        await rebuildStandings()
        return needsReview ? .needsReview : .finalized
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
        case .manual:
            competitors = []
        }

        guard competitors.isPopulated else { return .success([]) }

        let awards = competitors.compactMap { competitor -> SeriesPointAward? in
            guard let placement = competitor.placement else { return nil }
            guard let basePoints = resolvePoints(
                placement: placement,
                tieGroupSize: competitor.tieGroupSize ?? 1,
                profile: profile
            ) else {
                return nil
            }
            let bonusPoints = profile.bonusRules
                .filter(\.isEnabled)
                .reduce(0.0) { partial, rule in
                    switch rule.type {
                    case .participation:
                        return partial + rule.points
                    case .manual:
                        return partial
                    }
                }
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
        let awards = await FirebaseService.shared.fetchPointAwards(seriesID: seriesID)
        pointAwards = awards
        let existingStandings = await FirebaseService.shared.fetchStandings(seriesID: seriesID)

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
        for standing in existingStandings {
            _ = await FirebaseService.shared.deleteStanding(standing)
        }
        for track in SeriesAwardTrack.allCases {
            let sorted = grouped.values
                .filter { $0.awardTrack == track }
                .sorted(by: standingsSort)
            for (index, var standing) in sorted.enumerated() {
                standing.rank = index + 1
                _ = await FirebaseService.shared.updateStanding(standing)
                computedStandings.append(standing)
            }
        }

        standings = computedStandings
    }

    // MARK: - Handicap Ingestion

    private func ingestRoundScores(
        seriesRound: SeriesRound,
        snapshot: RoundSnapshot,
        replacingExisting: Bool = false
    ) async -> Bool {
        guard let roundID = seriesRound.roundID else { return false }

        let teeByParticipant = Dictionary(uniqueKeysWithValues: snapshot.participants.map { participant in
            let tee = snapshot.courseSegment?.tee(from: participant.teeBoxID)
                ?? snapshot.courseSegment?.tee(from: snapshot.courseSegment?.defaultTee ?? "")
                ?? snapshot.courseSegment?.courseInfo.tees.first
            return (participant.id, tee)
        })

        let scoreEntriesByParticipant = Dictionary(grouping: snapshot.scoring, by: \.scoringUnitID)
        var inserted = false
        var deleted = false

        if replacingExisting {
            let existingRoundScores = handicapScores.filter {
                $0.source == .round && $0.sourceRoundID == roundID
            }
            for existing in existingRoundScores {
                switch await FirebaseService.shared.deleteHandicapScore(existing) {
                case .success:
                    handicapScores.removeAll { $0.id == existing.id }
                    deleted = true
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "Failed to delete existing handicap score for correction", error: error)
                }
            }
        }

        for participant in snapshot.participants {
            guard let memberID = participant.seriesMemberID ?? members.first(where: { $0.playerID == participant.playerID })?.id else { continue }
            let alreadyIngested = handicapScores.contains {
                $0.memberID == memberID && $0.source == .round && $0.sourceRoundID == roundID
            }
            guard replacingExisting || !alreadyIngested else { continue }

            let entries = scoreEntriesByParticipant[participant.id] ?? []
            let tee = teeByParticipant[participant.id] ?? nil
            let scoredEntries = entries.filter { $0.strokes != nil }
            guard scoredEntries.isPopulated else { continue }

            let total = Double(scoredEntries.compactMap(\.strokes).reduce(0, +))
            let par = Double(tee?.par(for: snapshot.holeSegment) ?? snapshot.courseSegment?.courseInfo.tees.first?.par(for: snapshot.holeSegment) ?? Int(series.handicapConfig.config.defaultParForIndex))
            let score = SeriesHandicapScore(
                id: HackersID.string(),
                memberID: memberID,
                score: total,
                par: par,
                holeSegment: snapshot.holeSegment,
                source: .round,
                sourceRoundID: roundID,
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: seriesID
            )
            switch await FirebaseService.shared.addHandicapScore(score) {
            case .success(let saved):
                handicapScores.append(saved)
                inserted = true
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to ingest series handicap score", error: error)
            }
        }

        if inserted || deleted {
            recomputeAllHandicaps()
        }
        return inserted || deleted
    }

    // MARK: - Announcements

    func addAnnouncement(title: String, message: String, startsAt: Date, endsAt: Date) async {
        guard let memberID = currentMemberID else { return }
        let announcement = SeriesAnnouncement(
            id: HackersID.string(),
            title: title,
            message: message,
            createdByMemberID: memberID,
            startsAt: .init(for: startsAt),
            endsAt: .init(for: endsAt),
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: seriesID
        )
        switch await FirebaseService.shared.addSeriesAnnouncement(announcement) {
        case .success(let created):
            announcements.append(created)
            await refreshSeriesCachesIfNeeded()
        case .failure(let error):
            addBreadcrumb(level: .error, message: "Failed to add announcement", error: error)
        }
    }

    func deleteAnnouncement(_ announcement: SeriesAnnouncement) async {
        guard let index = announcements.firstIndex(where: { $0.id == announcement.id }) else { return }
        let target = announcements[index]
        announcements.remove(at: index)
        _ = await FirebaseService.shared.deleteSeriesAnnouncement(target)
        await refreshSeriesCachesIfNeeded()
    }

    // MARK: - CSV Export

    func exportCSV(for seriesRound: SeriesRound) async -> URL? {
        guard let roundID = seriesRound.roundID else { return nil }
        exportingRoundID = seriesRound.id
        defer { exportingRoundID = nil }

        guard let snapshot = await loadRoundSnapshot(roundID: roundID) else { return nil }
        let rows = buildCSVRows(seriesRound: seriesRound, snapshot: snapshot)
        guard rows.isPopulated else { return nil }

        let header = csvHeader(for: snapshot.holeSegment.holeCount)
        let csv = ([header] + rows).joined(separator: "\n")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("series-round-\(seriesRound.index + 1)-\(seriesRound.id.prefix(6)).csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedCSVURL = fileURL
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

        switch await FirebaseService.shared.getCourseByID(course.courseID) {
        case .success(let loadedCourse):
            seriesCourseTeesByCourseID[course.courseID] = loadedCourse.tees
        case .failure:
            if let round = rounds.first(where: { $0.resolvedCourse(using: series)?.courseID == course.courseID }),
               let roundID = round.roundID,
               let linked = linkedRounds[roundID],
               let tees = linked.configuration.courses.first?.courseInfo.tees,
               tees.isPopulated {
                seriesCourseTeesByCourseID[course.courseID] = tees
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

    func applyScoreCorrections(
        for seriesRound: SeriesRound,
        changes: [SeriesScoreCorrectionChange],
        reason: String
    ) async -> Bool {
        guard let roundID = seriesRound.roundID,
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

    private func mapLinkedRoundStatus(_ status: RoundStatus) -> SeriesRoundStatus {
        switch status {
        case .lobby: return .lobby
        case .live, .paused: return .live
        case .complete: return .complete
        case .archived: return .canceled
        }
    }

    private func roundConfig(from linkedRound: Round, fallback: SeriesRoundConfiguration) -> SeriesRoundConfiguration {
        var updated = fallback
        updated.formatTemplateID = linkedRound.configuration.formatSummary?.templateID ?? fallback.formatTemplateID
        updated.competitionScope = linkedRound.configuration.competitionScope
        updated.teamScoring = linkedRound.configuration.teamScoring
        updated.matchupResolutionStyle = linkedRound.configuration.matchupResolutionStyle
        updated.sequentialTeeStartsEnabled = linkedRound.configuration.sequentialTeeStartsEnabled ?? fallback.sequentialTeeStartsEnabled ?? false
        if linkedRound.configuration.resolvedCompetitionScope == .matchup {
            updated.matchupMode = linkedRound.configuration.primaryFormat.configuration.requiresTeams
                ? .teamVsTeam
                : .individualVsIndividual
        } else {
            updated.matchupMode = .field
        }
        return updated
    }

    private func templateID(for format: GameFormat) -> String {
        switch (format.type, format.configuration.requiresTeams) {
        case (.matchPlay, false): return FormatTemplateRegistry.matchPlayIndividual.id
        case (.strokePlay, true): return FormatTemplateRegistry.bestBall.id
        default: return FormatTemplateRegistry.strokePlay.id
        }
    }

    private func loadRoundSnapshot(roundID: String) async -> RoundSnapshot? {
        async let roundResult = FirebaseService.shared.getRoundByID(roundID)
        async let participantsResult = FirebaseService.shared.getParticipants(for: roundID)
        async let teamsResult = FirebaseService.shared.getTeams(for: roundID)
        async let groupsResult = FirebaseService.shared.getTeeGroups(for: roundID)
        async let segmentsResult = FirebaseService.shared.getSegments(for: roundID)
        async let scoresResult = FirebaseService.shared.getScores(for: roundID)

        guard case .success(let round) = await roundResult,
              case .success(let participants) = await participantsResult,
              case .success(let roundTeams) = await teamsResult,
              case .success(let teeGroups) = await groupsResult,
              case .success(let segments) = await segmentsResult,
              case .success(let scores) = await scoresResult else {
            return nil
        }

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: roundTeams,
            teeGroups: teeGroups,
            segments: segments,
            scoring: scores
        )
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
        let preferredMode: MatchupMode = snapshot.requiresTeams ? .team : .individual
        let currentMatchups = snapshot.roundSegment?.matchups ?? []
        let validTeamMatchups = currentMatchups
            .filter { ($0.mode ?? .team) == .team && $0.teamIDs.count == 2 }
        let validIndividualMatchups = currentMatchups
            .filter { ($0.mode ?? .team) == .individual && ($0.participantIDs?.count ?? 0) == 2 }

        let expectsMatchups = seriesRound.roundConfig.matchupMode == .teamVsTeam
            || seriesRound.roundConfig.matchupMode == .individualVsIndividual
        let hasPreferredMatchups = preferredMode == .team ? validTeamMatchups.isPopulated : validIndividualMatchups.isPopulated
        if !hasPreferredMatchups {
            return expectsMatchups ? [] : nil
        }

        let mappings = await FirebaseService.shared.fetchSeriesRoundMappings(
            seriesID: seriesID,
            seriesRoundID: seriesRound.id
        )
        let reverseTeamMapping = Dictionary(
            uniqueKeysWithValues: mappings
                .filter { $0.roundOwnerType == .team && $0.competitorType == .team }
                .map { ($0.roundOwnerID, $0.competitorID) }
        )
        let reverseParticipantMapping = Dictionary(
            uniqueKeysWithValues: mappings
                .filter { $0.roundOwnerType == .participant && $0.competitorType == .member }
                .map { ($0.roundOwnerID, $0.competitorID) }
        )

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
        let holes = holesForScoring(in: snapshot)
        let template = snapshot.resolvedActiveTemplate

        if snapshot.configuration.primaryFormat.configuration.requiresTeams {
            return ScoringEngine.computeWithTeamScoring(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                teams: snapshot.teams,
                segment: segment,
                holes: holes,
                basis: snapshot.configuration.primaryFormat.configuration.basis,
                template: template,
                teamScoring: snapshot.configuration.teamScoring,
                matchupResolutionStyle: snapshot.configuration.matchupResolutionStyle,
                scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs,
                resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope
            )
        }

        if template.id == FormatTemplateRegistry.strokePlay.id,
           snapshot.configuration.resolvedCompetitionScope != .matchup {
            return ScoringEngine.computeStrokePlay(
                scores: snapshot.scoring,
                participants: snapshot.participants,
                segment: segment,
                holes: holes,
                basis: snapshot.configuration.primaryFormat.configuration.basis,
                template: template,
                scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs
            )
        }

        return ScoringEngine.computeWithPipeline(
            scores: snapshot.scoring,
            participants: snapshot.participants,
            teams: snapshot.teams,
            segment: segment,
            holes: holes,
            basis: snapshot.configuration.primaryFormat.configuration.basis,
            template: template,
            scoreLookupSegmentIDs: snapshot.segmentScoreLookupSegmentIDs,
            resolvedCompetitionScope: snapshot.configuration.resolvedCompetitionScope
        )
    }

    private func holesForScoring(in snapshot: RoundSnapshot) -> [Hole] {
        let preferredTeeID = snapshot.courseSegment?.defaultTee
        let tee = preferredTeeID.flatMap { snapshot.courseSegment?.tee(from: $0) }
            ?? snapshot.courseSegment?.courseInfo.tees.first
        return tee?.holes ?? []
    }

    private struct AwardCompetitor {
        let roundOwnerID: String
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let competitorName: String
        let placement: Int?
        let tieGroupSize: Int?
        let reason: String?
    }

    private func buildIndividualCompetitors(
        result: ScoringResult,
        snapshot: RoundSnapshot,
        mappings: [SeriesRoundMapping]
    ) -> [AwardCompetitor] {
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
        let sections = LeaderboardBuilder.buildTeamSections(result: result, participants: snapshot.participants, teams: snapshot.teams)
        let mappingByTeamID = Dictionary(uniqueKeysWithValues: mappings.compactMap { mapping -> (String, String)? in
            guard mapping.roundOwnerType == .team, mapping.competitorType == .team else { return nil }
            return (mapping.roundOwnerID, mapping.competitorID)
        })
        let rows = sections.map { section in
            AwardPlacementRow(
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
        let mappingByParticipant = Dictionary(uniqueKeysWithValues: mappings.compactMap { mapping -> (String, String)? in
            guard mapping.roundOwnerType == .participant, mapping.competitorType == .member else { return nil }
            return (mapping.roundOwnerID, mapping.competitorID)
        })
        let mappingByTeamID = Dictionary(uniqueKeysWithValues: mappings.compactMap { mapping -> (String, String)? in
            guard mapping.roundOwnerType == .team, mapping.competitorType == .team else { return nil }
            return (mapping.roundOwnerID, mapping.competitorID)
        })

        var competitors: [AwardCompetitor] = []
        let highestWins = result.template.leaderboardSort == .highestWins
        for matchupResult in result.matchupResults {
            let sortedRows = matchupResult.rows.sorted {
                if $0.total != $1.total {
                    return highestWins ? $0.total > $1.total : $0.total < $1.total
                }
                return $0.scoringUnitID < $1.scoringUnitID
            }

            guard let first = sortedRows.first else { continue }
            let isTie = sortedRows.count > 1 && sortedRows.allSatisfy { $0.total == first.total }
            for row in sortedRows {
                let competitorType: SeriesCompetitorType = awardTrack == .team ? .team : .member
                let competitorID: String = {
                    switch competitorType {
                    case .team:
                        return mappingByTeamID[row.scoringUnitID] ?? row.scoringUnitID
                    case .member:
                        return mappingByParticipant[row.scoringUnitID] ?? row.scoringUnitID
                    }
                }()
                let competitorName: String = {
                    switch competitorType {
                    case .team:
                        return snapshot.teams.first(where: { $0.id == row.scoringUnitID })?.name ?? "Team"
                    case .member:
                        return snapshot.participants.first(where: { $0.id == row.scoringUnitID })?.name.fullName ?? "Player"
                    }
                }()

                let placement = isTie ? 1 : (row.scoringUnitID == first.scoringUnitID ? 1 : 2)
                competitors.append(
                    AwardCompetitor(
                        roundOwnerID: row.scoringUnitID,
                        competitorType: competitorType,
                        competitorID: competitorID,
                        competitorName: competitorName,
                        placement: placement,
                        tieGroupSize: isTie ? sortedRows.count : nil,
                        reason: matchupResult.matchup.id
                    )
                )
            }
        }
        return competitors
    }

    private struct AwardPlacementRow {
        let roundOwnerID: String
        let competitorType: SeriesCompetitorType
        let competitorID: String
        let competitorName: String
        let score: Double
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
                        reason: nil
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

    private func buildCSVRows(seriesRound: SeriesRound, snapshot: RoundSnapshot) -> [String] {
        let holeNumbers = snapshot.holeRange?.holeNumbers ?? Array(1...snapshot.holeSegment.holeCount)
        let scoreEntriesByParticipant = Dictionary(grouping: snapshot.scoring, by: \.scoringUnitID)

        return snapshot.participants.map { participant in
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
            let columns = [
                seriesRound.id,
                snapshot.round.id,
                memberID,
                participant.playerID ?? "",
                escapedCSV(participant.name.fullName),
                participant.teamID ?? ""
            ] + holeValues + [String(totalToPar)]
            return columns.joined(separator: ",")
        }
    }

    private func csvHeader(for holeCount: Int) -> String {
        let holeHeaders = (1...holeCount).map { "hole_\($0)_to_par" }
        return ([
            "series_round_id",
            "round_id",
            "series_member_id",
            "player_id",
            "player_name",
            "team_id"
        ] + holeHeaders + ["total_to_par"]).joined(separator: ",")
    }

    private func escapedCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func standingsSort(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.bestPlacement != rhs.bestPlacement { return (lhs.bestPlacement ?? .max) < (rhs.bestPlacement ?? .max) }
        return lhs.competitorName < rhs.competitorName
    }
}
