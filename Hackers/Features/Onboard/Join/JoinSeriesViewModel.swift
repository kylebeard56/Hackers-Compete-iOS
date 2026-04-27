//
//  JoinSeriesViewModel.swift
//  Hackers
//

import FirebaseAuth
import SwiftUI

@MainActor
final class JoinSeriesViewModel: ObservableObject, Loggable {
    enum FindSeriesError: String {
        case seriesNotFound = "Double-check your code and try again."
        case unknown = "Something went wrong. Please try again."
    }

    enum JoinSeriesError: String {
        case primaryPlayerNotFound = "No player profile found for user account."
        case userNotFound = "No user account found."
        case unknown = "Something went wrong. Please try again."
    }

    private enum LinkError: Error {
        case missingUser
        case missingPrimary
        case missingMember
        case missingSeries
    }

    @Published var series: Series?
    @Published var members: [SeriesMember] = []
    @Published var commissionerName = "Organizer"

    @Published var code = ""
    @Published var isLoading = false
    @Published var route = false
    @Published var findSeriesError: FindSeriesError?
    @Published var joinSeriesError: JoinSeriesError?

    @Published var primaryPlayer: Player?
    @Published var claimedMember: SeriesMember?
    @Published var newClaimedPlayer: Player?
    @Published var isPlayerLocked = false

    @Published var completeFlow = false

    var currentUser: User? { AuthService.shared.getCurrentUser() }

    init(code: String = "") {
        self.code = code
    }

    // MARK: - Find

    func findSeries() async {
        guard code.isPopulated else { return }
        addBreadcrumb(message: "Find series with token: \(code)")
        addEvent("series.join_search_started", eventProps: ["token_length": code.count])

        findSeriesError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let s = try await FirebaseService.shared.resolveSeries(byToken: code).get()
            await applyLoadedSeries(s)
        } catch {
            addBreadcrumb(level: .warning, message: "Failed to resolve series, \(code)", error: error)
            addEvent(
                "series.join_search_failed",
                eventProps: [
                    "token_length": code.count,
                    "error": "\(error)"
                ]
            )
            if let err = error as? HackersError, err == .documentNotFound {
                findSeriesError = .seriesNotFound
            } else {
                findSeriesError = .unknown
            }
        }
    }

    func applyLoadedSeries(_ loaded: Series) async {
        series = loaded
        members = await FirebaseService.shared.fetchSeriesMembers(seriesID: loaded.id)
        if let commissioner = members.first(where: { $0.role == .commissioner }) {
            commissionerName = commissioner.name.fullName
        }

        await fetchPrimaryPlayer()

        if isPlayerLocked {
            addEvent("series.join_search_succeeded", eventProps: joinEventProps(["flow": "existing_member"]))
            await enterSeriesIfAlreadyMember()
            return
        }

        addEvent("series.join_search_succeeded", eventProps: joinEventProps())
        route = true
    }

    func fetchPrimaryPlayer() async {
        if let player = await AppData.shared.getPrimaryPlayer() {
            primaryPlayer = player
            if let m = members.first(where: { $0.playerID == player.id && $0.isActive }) {
                claimedMember = m
                isPlayerLocked = true
            }
        }
    }

    // MARK: - Join

    func enterSeriesIfAlreadyMember() async {
        guard series != nil else { return }
        completeFlow = true
    }

    func claimOfflineMember() async {
        do {
            try await linkClaimedMemberWithPrimaryUser()
            addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "claim_offline_member"]))
            completeFlow = true
        } catch {
            joinSeriesError = .unknown
        }
    }

    func continueAsGuest() async {
        await enterSeriesIfAlreadyMember()
    }

    func addPrimaryPlayerToSeries() async {
        guard let user = await AppData.shared.user else {
            joinSeriesError = .userNotFound
            return
        }
        guard let seriesID = series?.id else { return }
        guard let primary = await AppData.shared.getPrimaryPlayer() else {
            joinSeriesError = .primaryPlayerNotFound
            return
        }

        if let matchingOfflineMember = matchingOfflineMember(for: primary) {
            claimedMember = matchingOfflineMember
            do {
                try await linkClaimedMemberWithPrimaryUser()
                addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "claim_matching_offline_member"]))
                completeFlow = true
            } catch {
                joinSeriesError = .unknown
            }
            return
        }

        var member = SeriesMember(
            id: HackersID.string(),
            userID: user.id,
            playerID: primary.id,
            name: primary.name.normalizedForStorage,
            role: .member,
            isActive: true,
            joinedAt: Time(),
            createdAt: Time(),
            lastUpdatedAt: Time(),
            parentID: seriesID
        )

        switch await FirebaseService.shared.addSeriesMember(member) {
        case .success(let created):
            member = created
        case .failure:
            joinSeriesError = .unknown
            return
        }

        do {
            try await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: primary.id)
        } catch {
            addBreadcrumb(level: .error, message: "addPlayerToSeries failed", error: error)
            joinSeriesError = .unknown
            return
        }

        addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "add_primary_player"]))
        completeFlow = true
    }

    func claimNewPlayerAndEnterSeries() async {
        guard var p = newClaimedPlayer else {
            addBreadcrumb(level: .warning, message: "claimNewPlayer: player nil")
            return
        }
        guard let seriesID = series?.id else {
            addBreadcrumb(level: .warning, message: "claimNewPlayer: series nil")
            return
        }

        do {
            let createdPlayer: Player
            switch await p.post() {
            case .success(let saved):
                createdPlayer = saved
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to create player for series join", error: error)
                joinSeriesError = .unknown
                return
            }

            if var user = await AppData.shared.user {
                var linkedPlayer = createdPlayer
                linkedPlayer.userID = user.id
                linkedPlayer.isPrimary = true
                do {
                    linkedPlayer = try await linkedPlayer.put().get()
                } catch {
                    addBreadcrumb(level: .error, message: "Failed to update player for series join", error: error)
                    joinSeriesError = .unknown
                    return
                }

                var member = SeriesMember(
                    id: HackersID.string(),
                    userID: user.id,
                    playerID: linkedPlayer.id,
                    name: linkedPlayer.name.normalizedForStorage,
                    role: .member,
                    isActive: true,
                    joinedAt: Time(),
                    createdAt: Time(),
                    lastUpdatedAt: Time(),
                    parentID: seriesID
                )

                switch await FirebaseService.shared.addSeriesMember(member) {
                case .success(let saved):
                    member = saved
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "addSeriesMember failed", error: error)
                    joinSeriesError = .unknown
                    return
                }

                try await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: createdPlayer.id)

                user.players = [createdPlayer.id]
                user = try await user.put().get()
                await AppData.shared.setUser(user)
                TelemetryService.shared.identify(user: user, authUserID: user.id)

                addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "claim_new_player_authenticated"]))
                completeFlow = true
            } else {
                var member = SeriesMember(
                    id: HackersID.string(),
                    userID: nil,
                    playerID: createdPlayer.id,
                    name: createdPlayer.name.normalizedForStorage,
                    role: .member,
                    isActive: true,
                    joinedAt: Time(),
                    createdAt: Time(),
                    lastUpdatedAt: Time(),
                    parentID: seriesID
                )

                switch await FirebaseService.shared.addSeriesMember(member) {
                case .success:
                    break
                case .failure(let error):
                    addBreadcrumb(level: .error, message: "addSeriesMember guest failed", error: error)
                    joinSeriesError = .unknown
                    return
                }

                try await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: createdPlayer.id)

                addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "claim_new_player_guest"]))
                completeFlow = true
            }
        } catch {
            addBreadcrumb(level: .error, message: "claimNewPlayerAndEnterSeries failed", error: error)
            joinSeriesError = .unknown
        }
    }

    func overrideClaimWithPrimaryPlayer() async {
        do {
            try await linkClaimedMemberWithPrimaryUser()
            addEvent("series.join_succeeded", eventProps: joinEventProps(["flow": "override_with_primary"]))
            completeFlow = true
        } catch {
            joinSeriesError = .unknown
        }
    }

    // MARK: - Private

    private func linkClaimedMemberWithPrimaryUser() async throws {
        guard let user = await AppData.shared.user else { throw LinkError.missingUser }
        guard let primary = await AppData.shared.getPrimaryPlayer() else { throw LinkError.missingPrimary }
        guard var member = claimedMember else { throw LinkError.missingMember }
        guard let seriesID = series?.id else { throw LinkError.missingSeries }

        let claimedName = member.name.normalizedForStorage
        member.userID = user.id
        member.playerID = primary.id
        member.name = claimedName
        member.lastUpdatedAt = Time()

        switch await FirebaseService.shared.updateSeriesMember(member) {
        case .success(let updated):
            member = updated
        case .failure(let error):
            throw error
        }

        try await FirebaseService.shared.addPlayerToSeries(seriesID: seriesID, playerID: primary.id)
        await normalizePrimaryPlayerIfNeeded(primary, to: claimedName)

        claimedMember = member
        if let idx = members.firstIndex(where: { $0.id == member.id }) {
            members[idx] = member
        }
        isPlayerLocked = true
    }

    private func joinEventProps(_ extra: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = ["token_length": code.count]
        if let id = series?.id {
            props["series_id"] = id
        }
        extra.forEach { props[$0.key] = $0.value }
        return props
    }

    private func normalizePrimaryPlayerIfNeeded(_ primary: Player, to claimedName: Name) async {
        guard primary.name.normalizedForStorage != claimedName else { return }

        var updatedPrimary = primary
        updatedPrimary.name = claimedName
        updatedPrimary.lastUpdatedAt = .init()

        do {
            _ = try await updatedPrimary.put().get()
        } catch {
            addBreadcrumb(level: .warning, message: "Series claim linked member but could not normalize primary player name", error: error)
        }
    }
}

extension JoinSeriesViewModel {
    func matchingOfflineMember(for player: Player) -> SeriesMember? {
        Self.matchingOfflineMember(for: player, in: members)
    }

    static func matchingOfflineMember(for player: Player, in members: [SeriesMember]) -> SeriesMember? {
        let key = player.name.normalizedMatchKey
        guard key.isPopulated else { return nil }

        return members.first { member in
            member.isActive
                && member.isOffline
                && member.name.normalizedMatchKey == key
        }
    }
}
