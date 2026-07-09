//
//  SeriesStandingsPublication.swift
//  Hackers
//

import Foundation

struct SeriesPointAwardsPublicationPlan {
    let deleting: [SeriesPointAward]
    let upserting: [SeriesPointAward]

    var writeCount: Int {
        deleting.count + upserting.count
    }
}

enum SeriesPointAwardsPublicationPlanner {
    static func plan(
        existing: [SeriesPointAward],
        computed: [SeriesPointAward],
        rebuiltTracks: Set<SeriesAwardTrack>
    ) -> SeriesPointAwardsPublicationPlan {
        let replaceableExisting = existing.filter {
            $0.source == .automatic && rebuiltTracks.contains($0.awardTrack)
        }
        let existingByID = Dictionary(uniqueKeysWithValues: replaceableExisting.map { ($0.id, $0) })
        let computedIDs = Set(computed.map(\.id))
        let deleting = replaceableExisting.filter { !computedIDs.contains($0.id) }
        let upserting = computed.compactMap { candidate -> SeriesPointAward? in
            guard let current = existingByID[candidate.id] else { return candidate }
            guard !semanticallyEqual(current, candidate) else { return nil }
            var updated = candidate
            updated.createdAt = current.createdAt
            return updated
        }
        return SeriesPointAwardsPublicationPlan(deleting: deleting, upserting: upserting)
    }

    static func semanticallyEqual(_ lhs: SeriesPointAward, _ rhs: SeriesPointAward) -> Bool {
        lhs.id == rhs.id
            && lhs.seriesRoundID == rhs.seriesRoundID
            && lhs.awardTrack == rhs.awardTrack
            && lhs.competitorType == rhs.competitorType
            && lhs.competitorID == rhs.competitorID
            && lhs.competitorName == rhs.competitorName
            && lhs.profileKind == rhs.profileKind
            && lhs.placement == rhs.placement
            && lhs.tieGroupSize == rhs.tieGroupSize
            && lhs.basePoints == rhs.basePoints
            && lhs.bonusPoints == rhs.bonusPoints
            && lhs.totalPoints == rhs.totalPoints
            && lhs.source == rhs.source
            && lhs.roundOwnerID == rhs.roundOwnerID
            && lhs.reason == rhs.reason
            && lhs.awardedByMemberID == rhs.awardedByMemberID
            && lhs.parentID == rhs.parentID
            && lhs.schema == rhs.schema
    }
}

struct SeriesStandingsPublicationPlan {
    let deleting: [SeriesStanding]
    let upserting: [SeriesStanding]
    let published: [SeriesStanding]

    var writeCount: Int {
        deleting.count + upserting.count
    }
}

enum SeriesStandingsPublicationPlanner {
    static func plan(
        existing: [SeriesStanding],
        computed: [SeriesStanding],
        track: SeriesAwardTrack?,
        now: Time = .init()
    ) -> SeriesStandingsPublicationPlan {
        let existingForTarget = track.map { target in
            existing.filter { $0.awardTrack == target }
        } ?? existing
        let untouched = track.map { target in
            existing.filter { $0.awardTrack != target }
        } ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingForTarget.map { ($0.id, $0) })
        let computedIDs = Set(computed.map(\.id))
        let deleting = existingForTarget.filter { !computedIDs.contains($0.id) }

        var upserting: [SeriesStanding] = []
        let targetPublished = computed.map { candidate -> SeriesStanding in
            guard let current = existingByID[candidate.id] else {
                var inserted = candidate
                inserted.lastUpdatedAt = now
                upserting.append(inserted)
                return inserted
            }
            guard !semanticallyEqual(current, candidate) else {
                return current
            }

            var updated = candidate
            updated.createdAt = current.createdAt
            updated.lastUpdatedAt = now
            upserting.append(updated)
            return updated
        }

        return SeriesStandingsPublicationPlan(
            deleting: deleting,
            upserting: upserting,
            published: untouched + targetPublished
        )
    }

    static func semanticallyEqual(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        lhs.id == rhs.id
            && lhs.awardTrack == rhs.awardTrack
            && lhs.competitorType == rhs.competitorType
            && lhs.competitorID == rhs.competitorID
            && lhs.competitorName == rhs.competitorName
            && lhs.totalPoints == rhs.totalPoints
            && lhs.roundsCounted == rhs.roundsCounted
            && lhs.wins == rhs.wins
            && lhs.topThrees == rhs.topThrees
            && lhs.lastPlacement == rhs.lastPlacement
            && lhs.bestPlacement == rhs.bestPlacement
            && lhs.rank == rhs.rank
            && lhs.parentID == rhs.parentID
            && lhs.schema == rhs.schema
    }
}

@MainActor
protocol SeriesStandingsWriting: AnyObject {
    func replace(
        deleting: [SeriesStanding],
        upserting: [SeriesStanding]
    ) async -> Result<Void, Error>
}

@MainActor
final class FirebaseSeriesStandingsWriter: SeriesStandingsWriting {
    func replace(
        deleting: [SeriesStanding],
        upserting: [SeriesStanding]
    ) async -> Result<Void, Error> {
        await FirebaseService.shared.batchReplaceStandings(
            deleting: deleting,
            upserting: upserting
        )
    }
}

@MainActor
final class SeriesStandingsPublicationService {
    private let writer: any SeriesStandingsWriting

    init(writer: (any SeriesStandingsWriting)? = nil) {
        self.writer = writer ?? FirebaseSeriesStandingsWriter()
    }

    func publish(
        existing: [SeriesStanding],
        computed: [SeriesStanding],
        track: SeriesAwardTrack?
    ) async -> Result<SeriesStandingsPublicationPlan, Error> {
        let plan = SeriesStandingsPublicationPlanner.plan(
            existing: existing,
            computed: computed,
            track: track
        )
        guard plan.writeCount > 0 else { return .success(plan) }

        switch await writer.replace(deleting: plan.deleting, upserting: plan.upserting) {
        case .success:
            return .success(plan)
        case .failure(let error):
            return .failure(error)
        }
    }
}
