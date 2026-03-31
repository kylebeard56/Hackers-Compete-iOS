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

extension URL {
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
