//
//  Session+Nav.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

enum RoundResumeDestination: String, Codable, Sendable {
    case lobby
    case liveRound = "live_round"
}

enum RoundResumeTab: String, Codable, Sendable {
    case scoring
    case table
    case matchups
}

struct RoundResumeState: Codable, Equatable, Sendable {
    var roundID: String
    var seriesID: String?
    var destination: RoundResumeDestination
    var selectedHole: Int?
    var selectedTab: RoundResumeTab
    var timestamp: Date

    init(
        roundID: String,
        seriesID: String? = nil,
        destination: RoundResumeDestination,
        selectedHole: Int? = nil,
        selectedTab: RoundResumeTab = .scoring,
        timestamp: Date = Date()
    ) {
        self.roundID = roundID
        self.seriesID = seriesID
        self.destination = destination
        self.selectedHole = selectedHole
        self.selectedTab = selectedTab
        self.timestamp = timestamp
    }
}

protocol RoundResumeStoring: AnyObject, Sendable {
    func load() -> RoundResumeState?
    func save(_ state: RoundResumeState)
    func clear()
}

final class UserDefaultsRoundResumeStore: RoundResumeStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "live_round_resume_state_v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> RoundResumeState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RoundResumeState.self, from: data)
    }

    func save(_ state: RoundResumeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

enum RoundResumeResolution: Equatable {
    case lobby
    case liveRound
    case outcome
    case discard
}

enum RoundResumeRouter {
    static func resolve(status: RoundStatus) -> RoundResumeResolution {
        switch status {
        case .lobby: .lobby
        case .live, .paused: .liveRound
        case .complete: .outcome
        case .archived: .discard
        }
    }
}

extension AppSession {

    func persistRoundResume(
        destination: RoundResumeDestination,
        selectedHole: Int? = nil,
        selectedTab: RoundResumeTab? = nil
    ) {
        guard let roundID = activeRoundID, roundID.isPopulated else { return }
        let existing = roundResumeState?.roundID == roundID ? roundResumeState : nil
        let state = RoundResumeState(
            roundID: roundID,
            seriesID: activeSeriesID,
            destination: destination,
            selectedHole: selectedHole ?? existing?.selectedHole,
            selectedTab: selectedTab ?? existing?.selectedTab ?? .scoring
        )
        roundResumeState = state
        roundResumeStore.save(state)
    }

    func updateLiveRoundResume(selectedHole: Int?, selectedTab: RoundResumeTab) {
        persistRoundResume(
            destination: .liveRound,
            selectedHole: selectedHole,
            selectedTab: selectedTab
        )
    }

    func clearRoundResume() {
        roundResumeState = nil
        roundResumeStore.clear()
    }

    func restoreRoundOrRouteToDashboard() async {
        guard pendingJoinLink == nil, let state = roundResumeState else {
            routeTo(.dashboard)
            return
        }

        guard case .success(let round) = await FirebaseService.shared.getRoundDocument(byID: state.roundID),
              round.status != .archived else {
            clearRoundResume()
            routeTo(.dashboard)
            return
        }

        activeRoundID = round.id
        activeSeriesID = state.seriesID

        switch RoundResumeRouter.resolve(status: round.status) {
        case .lobby:
            routeTo(.lobby)
        case .liveRound:
            routeTo(.liveRound)
        case .outcome:
            roundOutcomeAllowsEditing = true
            clearRoundResume()
            routeTo(.roundOutcome)
        case .discard:
            clearRoundResume()
            routeTo(.dashboard)
        }
    }

    /// Route to a destination and optional pre-qeueue a list of views prior.
    /// Ex: If routing to .birthday for onboarding, you may want to add the prior onboarding steps for clean navigation.
    /// - Parameter replacingCurrent: When true, pops the current top of the stack before pushing. Use when transitioning lobby→live so exit returns to dashboard.
    func routeTo(_ destination: Destination, prequeue: [Destination] = [], replacingCurrent: Bool = false) {
        addBreadcrumb(message: "route to \(destination)")
        UIApplication.shared.endEditing()

        switch destination {
        case .auth, .dashboard:
            TelemetryService.shared.clearContext()
        case .series(let id):
            activeSeriesID = id
            TelemetryService.shared.clearContext()
            TelemetryService.shared.setContext(seriesID: id)
            addEvent("series.opened", eventProps: ["series_id": id])
        case .lobby:
            persistRoundResume(destination: .lobby)
            TelemetryService.shared.setContext(roundID: activeRoundID, seriesID: activeSeriesID)
            if let activeRoundID {
                addEvent("round.opened", eventProps: ["round_id": activeRoundID, "destination": "lobby"])
            }
        case .liveRound:
            persistRoundResume(destination: .liveRound)
            TelemetryService.shared.setContext(roundID: activeRoundID, seriesID: activeSeriesID)
            if let activeRoundID {
                addEvent("round.opened", eventProps: ["round_id": activeRoundID, "destination": "live_round"])
            }
        case .roundOutcome:
            TelemetryService.shared.setContext(roundID: activeRoundID, seriesID: activeSeriesID)
            if let activeRoundID {
                addEvent("round.opened", eventProps: ["round_id": activeRoundID, "destination": "round_outcome"])
            }
        case .minimumAppVersion:
            break
#if SANDBOX
        case .designStudio:
            // The studio is intentionally local-only: no analytics context or
            // production session state changes are made when it is opened.
            break
#endif
        }
        
        for p in prequeue {
            path.append(p)
        }
        
        if destination == .auth {
            path.removeLast(path.count)
        } else {
            if replacingCurrent, path.count > 0 {
                path.removeLast()
            }
            path.append(destination)
        }
    }
}
