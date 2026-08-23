//
//  URL.swift
//  Hackers
//
//  Created by Kyle Beard on 1/8/26.
//

import Foundation

enum JoinDeepLinkPayload: Equatable {
    case roundID(String)
    case seriesID(String)
    /// Legacy `?code=` round share links.
    case legacyCode(String)

    var token: String {
        switch self {
        case .roundID(let value), .seriesID(let value), .legacyCode(let value):
            return value
        }
    }
}

struct LiveRoundDeepLinkPayload: Equatable {
    let roundID: String
    let holeNumber: Int?
}

extension URL {
    /// Parses the presentation-only destination used by Live Activities and the Watch app.
    var liveRoundDeepLinkPayload: LiveRoundDeepLinkPayload? {
        let normalizedPath = path.hasSuffix("/live-round") ? "/live-round" : path
        guard normalizedPath == "/live-round" else { return nil }
        let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let rawRoundID = items.first(where: { $0.name == "round_id" })?.value else {
            return nil
        }
        let roundID = rawRoundID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard roundID.isPopulated else { return nil }
        let holeNumber = items.first(where: { $0.name == "hole" })?.value.flatMap(Int.init)
        return LiveRoundDeepLinkPayload(roundID: roundID, holeNumber: holeNumber)
    }

    /// Parses `hackersgolf:///join?...` or `hackersgolfsandbox:///join?...` (path may be `/join` or include a host with suffix `/join`).
    var joinDeepLinkPayload: JoinDeepLinkPayload? {
        let normalizedPath = path.hasSuffix("/join") ? "/join" : path
        guard normalizedPath == "/join" else { return nil }
        let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func firstValue(named name: String) -> String? {
            guard let raw = items.first(where: { $0.name == name })?.value else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let round = firstValue(named: "round_id") {
            return .roundID(round)
        }
        if let series = firstValue(named: "series_id") {
            return .seriesID(series)
        }
        if let code = firstValue(named: "code") {
            return .legacyCode(code)
        }
        return nil
    }

    /// QR / clipboard compatibility: token only (caller must still know intended target when ambiguous).
    var extractedShareCode: String? {
        joinDeepLinkPayload?.token
    }
}
