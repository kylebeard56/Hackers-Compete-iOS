//
//  SeriesRoundSnapshotRepository.swift
//  Hackers
//

import Foundation

enum SeriesRoundSnapshotComponent: String, CaseIterable, Sendable {
    case round
    case participants
    case teams
    case teeGroups = "tee_groups"
    case segments
    case scores
    case scoringGroups = "scoring_groups"
}

struct SeriesRoundSnapshotLoadFailure: Error, Equatable, Sendable {
    let roundID: String
    let component: SeriesRoundSnapshotComponent
    let message: String
}

enum SeriesRoundSnapshotCachePolicy: Equatable, Sendable {
    case useCache
    case reload
}

@MainActor
protocol SeriesRoundSnapshotSource: AnyObject {
    func round(id: String) async -> Result<Round, Error>
    func participants(roundID: String) async -> Result<[RoundParticipant], Error>
    func teams(roundID: String) async -> Result<[RoundTeam], Error>
    func teeGroups(roundID: String) async -> Result<[TeeTimeGroup], Error>
    func segments(roundID: String) async -> Result<[RoundSegment], Error>
    func scores(roundID: String) async -> Result<[ScoreEntry], Error>
    func scoringGroups(roundID: String) async -> Result<[RoundScoringGroup], Error>
}

@MainActor
final class FirebaseSeriesRoundSnapshotSource: SeriesRoundSnapshotSource {
    func round(id: String) async -> Result<Round, Error> {
        await FirebaseService.shared.getRoundDocument(byID: id)
    }

    func participants(roundID: String) async -> Result<[RoundParticipant], Error> {
        await FirebaseService.shared.getParticipants(for: roundID)
    }

    func teams(roundID: String) async -> Result<[RoundTeam], Error> {
        await FirebaseService.shared.getTeams(for: roundID)
    }

    func teeGroups(roundID: String) async -> Result<[TeeTimeGroup], Error> {
        await FirebaseService.shared.getTeeGroups(for: roundID)
    }

    func segments(roundID: String) async -> Result<[RoundSegment], Error> {
        await FirebaseService.shared.getSegments(for: roundID)
    }

    func scores(roundID: String) async -> Result<[ScoreEntry], Error> {
        await FirebaseService.shared.getScores(for: roundID)
    }

    func scoringGroups(roundID: String) async -> Result<[RoundScoringGroup], Error> {
        await FirebaseService.shared.getScoringGroups(for: roundID)
    }
}

@MainActor
private final class SeriesRoundSnapshotAccumulator {
    var round: Result<Round, Error>?
    var participants: Result<[RoundParticipant], Error>?
    var teams: Result<[RoundTeam], Error>?
    var teeGroups: Result<[TeeTimeGroup], Error>?
    var segments: Result<[RoundSegment], Error>?
    var scores: Result<[ScoreEntry], Error>?
    var scoringGroups: Result<[RoundScoringGroup], Error>?
}

@MainActor
final class SeriesRoundSnapshotLoader {
    private let source: any SeriesRoundSnapshotSource

    init(source: (any SeriesRoundSnapshotSource)? = nil) {
        self.source = source ?? FirebaseSeriesRoundSnapshotSource()
    }

    func load(roundID: String) async -> Result<RoundSnapshot, SeriesRoundSnapshotLoadFailure> {
        let accumulator = SeriesRoundSnapshotAccumulator()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [source] in
                accumulator.round = await source.round(id: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.participants = await source.participants(roundID: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.teams = await source.teams(roundID: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.teeGroups = await source.teeGroups(roundID: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.segments = await source.segments(roundID: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.scores = await source.scores(roundID: roundID)
            }
            group.addTask { @MainActor [source] in
                accumulator.scoringGroups = await source.scoringGroups(roundID: roundID)
            }
        }

        let round: Round
        switch accumulator.round {
        case .success(let value): round = value
        case .failure(let error): return .failure(failure(roundID, .round, error))
        case nil: return .failure(missingFailure(roundID, .round))
        }

        let participants: [RoundParticipant]
        switch accumulator.participants {
        case .success(let value): participants = value
        case .failure(let error): return .failure(failure(roundID, .participants, error))
        case nil: return .failure(missingFailure(roundID, .participants))
        }

        let teams: [RoundTeam]
        switch accumulator.teams {
        case .success(let value): teams = value
        case .failure(let error): return .failure(failure(roundID, .teams, error))
        case nil: return .failure(missingFailure(roundID, .teams))
        }

        let teeGroups: [TeeTimeGroup]
        switch accumulator.teeGroups {
        case .success(let value): teeGroups = value
        case .failure(let error): return .failure(failure(roundID, .teeGroups, error))
        case nil: return .failure(missingFailure(roundID, .teeGroups))
        }

        let segments: [RoundSegment]
        switch accumulator.segments {
        case .success(let value): segments = value
        case .failure(let error): return .failure(failure(roundID, .segments, error))
        case nil: return .failure(missingFailure(roundID, .segments))
        }

        let scores: [ScoreEntry]
        switch accumulator.scores {
        case .success(let value): scores = value
        case .failure(let error): return .failure(failure(roundID, .scores, error))
        case nil: return .failure(missingFailure(roundID, .scores))
        }

        let scoringGroups: [RoundScoringGroup]
        switch accumulator.scoringGroups {
        case .success(let value): scoringGroups = value
        case .failure(let error): return .failure(failure(roundID, .scoringGroups, error))
        case nil: return .failure(missingFailure(roundID, .scoringGroups))
        }

        return .success(
            RoundSnapshot(
                round: round,
                participants: participants,
                teams: teams,
                teeGroups: teeGroups,
                scoringGroups: scoringGroups,
                segments: segments,
                scoring: scores
            )
        )
    }

    private func failure(
        _ roundID: String,
        _ component: SeriesRoundSnapshotComponent,
        _ error: Error
    ) -> SeriesRoundSnapshotLoadFailure {
        SeriesRoundSnapshotLoadFailure(
            roundID: roundID,
            component: component,
            message: error.localizedDescription
        )
    }

    private func missingFailure(
        _ roundID: String,
        _ component: SeriesRoundSnapshotComponent
    ) -> SeriesRoundSnapshotLoadFailure {
        SeriesRoundSnapshotLoadFailure(
            roundID: roundID,
            component: component,
            message: "Snapshot component did not complete."
        )
    }
}

@MainActor
private final class SeriesRoundSnapshotBulkAccumulator {
    var results: [String: Result<RoundSnapshot, SeriesRoundSnapshotLoadFailure>] = [:]
}

@MainActor
final class SeriesRoundSnapshotRepository {
    private struct InFlightLoad {
        let token: UUID
        let task: Task<Result<RoundSnapshot, SeriesRoundSnapshotLoadFailure>, Never>
    }

    private let loader: SeriesRoundSnapshotLoader
    private var cache: [String: RoundSnapshot] = [:]
    private var inFlight: [String: InFlightLoad] = [:]

    init(loader: SeriesRoundSnapshotLoader? = nil) {
        self.loader = loader ?? SeriesRoundSnapshotLoader()
    }

    func snapshot(
        roundID: String,
        policy: SeriesRoundSnapshotCachePolicy
    ) async -> Result<RoundSnapshot, SeriesRoundSnapshotLoadFailure> {
        if policy == .useCache, let cached = cache[roundID] {
            return .success(cached)
        }
        if let existing = inFlight[roundID] {
            return await existing.task.value
        }

        let token = UUID()
        let task = Task { @MainActor [loader] in
            await loader.load(roundID: roundID)
        }
        inFlight[roundID] = InFlightLoad(token: token, task: task)

        let result = await task.value
        if inFlight[roundID]?.token == token {
            inFlight[roundID] = nil
            if case .success(let snapshot) = result {
                cache[roundID] = snapshot
            }
        }
        return result
    }

    func snapshots(
        roundIDs: [String],
        policy: SeriesRoundSnapshotCachePolicy,
        maxConcurrent: Int = 3
    ) async -> [String: Result<RoundSnapshot, SeriesRoundSnapshotLoadFailure>] {
        let uniqueRoundIDs = Array(Set(roundIDs.filter(\.isPopulated))).sorted()
        guard uniqueRoundIDs.isPopulated else { return [:] }

        let concurrencyLimit = max(1, min(maxConcurrent, uniqueRoundIDs.count))
        let accumulator = SeriesRoundSnapshotBulkAccumulator()
        var iterator = uniqueRoundIDs.makeIterator()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrencyLimit {
                guard let roundID = iterator.next() else { break }
                group.addTask { @MainActor [weak self] in
                    guard let self else { return }
                    accumulator.results[roundID] = await self.snapshot(roundID: roundID, policy: policy)
                }
            }

            while await group.next() != nil {
                guard let roundID = iterator.next() else { continue }
                group.addTask { @MainActor [weak self] in
                    guard let self else { return }
                    accumulator.results[roundID] = await self.snapshot(roundID: roundID, policy: policy)
                }
            }
        }
        return accumulator.results
    }

    func invalidate(roundID: String) {
        cache[roundID] = nil
        inFlight[roundID]?.task.cancel()
        inFlight[roundID] = nil
    }

    func invalidateAll() {
        inFlight.values.forEach { $0.task.cancel() }
        inFlight = [:]
        cache = [:]
    }

    func retain(roundIDs: Set<String>) {
        for roundID in cache.keys where !roundIDs.contains(roundID) {
            cache[roundID] = nil
        }
        for roundID in inFlight.keys where !roundIDs.contains(roundID) {
            inFlight[roundID]?.task.cancel()
            inFlight[roundID] = nil
        }
    }
}
