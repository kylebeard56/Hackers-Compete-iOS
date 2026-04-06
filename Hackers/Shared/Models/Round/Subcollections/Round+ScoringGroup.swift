//
//  Round+ScoringGroup.swift
//  Hackers
//
//  Created by Codex on 4/4/26.
//

import Foundation

enum RoundScoringGroupKind: String, Codable, CaseIterable {
    case partnership
    case teeGroup = "tee_group"
}

struct RoundScoringGroup: FirebaseSubcollectable, Hashable, Identifiable {
    var id: String
    var teamID: String?
    var teeGroupID: String?
    var kind: RoundScoringGroupKind
    var memberIDs: [String]
    var label: String?
    var seedSeriesPodID: String?
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1

    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.scoringGroups.rawValue }

    init(
        id: String = "",
        teamID: String? = nil,
        teeGroupID: String? = nil,
        kind: RoundScoringGroupKind = .partnership,
        memberIDs: [String] = [],
        label: String? = nil,
        seedSeriesPodID: String? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.teamID = teamID
        self.teeGroupID = teeGroupID
        self.kind = kind
        self.memberIDs = Self.normalizedMemberIDs(memberIDs)
        self.label = label
        self.seedSeriesPodID = seedSeriesPodID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, label, schema
        case teamID = "team_id"
        case teeGroupID = "tee_group_id"
        case memberIDs = "member_ids"
        case seedSeriesPodID = "seed_series_pod_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }

    var isValidPartnership: Bool {
        kind == .partnership && memberIDs.count == 2
    }

    private static func normalizedMemberIDs(_ memberIDs: [String]) -> [String] {
        Array(Set(memberIDs.filter(\.isPopulated))).sorted()
    }
}
