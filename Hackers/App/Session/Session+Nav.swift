//
//  Session+Nav.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {

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
            TelemetryService.shared.setContext(roundID: activeRoundID, seriesID: activeSeriesID)
            if let activeRoundID {
                addEvent("round.opened", eventProps: ["round_id": activeRoundID, "destination": "lobby"])
            }
        case .liveRound:
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
