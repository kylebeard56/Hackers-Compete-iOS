//
//  Round+TeeGroup.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - TeeTimeGroup
struct TeeTimeGroup: FirebaseSubcollectable, IndexIterable {
    var id: String
    var index: Int
    var teeTime: String?        // ISO8601 format (displayed in the time zone of the course)
    var startingHole: Int       // Starting hole number
    let lastCompletedHole: Int? // Current friendly hole number
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    var name: String { "Group \(index + 1)" }
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.teeGroups.rawValue }
    
    init(
        id: String = "",
        index: Int = 1,
        teeTime: String? = nil,
        startingHole: Int = 0,
        lastCompletedHole: Int? = nil,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.index = index
        self.teeTime = teeTime
        self.startingHole = startingHole
        self.lastCompletedHole = lastCompletedHole
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, index, schema
        case teeTime = "tee_time"
        case startingHole = "starting_hole"
        case lastCompletedHole = "last_completed_hole"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

extension TeeTimeGroup {
    static func sequentialStartingHole(forSequenceIndex sequenceIndex: Int, in holeRange: HoleRange?) -> Int {
        let holes = holeRange?.holeNumbers ?? Array(1...18)
        guard !holes.isEmpty else { return 1 }
        return holes[max(0, sequenceIndex) % holes.count]
    }

    static func nextSequentialStartingHole(existingGroups: [TeeTimeGroup], in holeRange: HoleRange?) -> Int {
        sequentialStartingHole(forSequenceIndex: existingGroups.count, in: holeRange)
    }

    func startingHoleDisplayLabel(in groups: [TeeTimeGroup]) -> String {
        let peers = groups
            .filter { $0.startingHole == startingHole }
            .sorted { lhs, rhs in
                if lhs.index != rhs.index { return lhs.index < rhs.index }
                return lhs.id < rhs.id
            }

        guard peers.count > 1,
              let ordinal = peers.firstIndex(where: { $0.id == id }) else {
            return "\(startingHole)"
        }

        return "\(startingHole)\(Self.sequenceSuffix(for: ordinal))"
    }

    private static func sequenceSuffix(for ordinal: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard ordinal >= 0 else { return "A" }

        var value = ordinal
        var suffix = ""

        repeat {
            suffix = String(alphabet[value % alphabet.count]) + suffix
            value = (value / alphabet.count) - 1
        } while value >= 0

        return suffix
    }
}
