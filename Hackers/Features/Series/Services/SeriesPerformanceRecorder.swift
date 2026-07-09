//
//  SeriesPerformanceRecorder.swift
//  Hackers
//

import Foundation
import OSLog

enum SeriesPerformanceOperation: String, Sendable {
    case coreLoad = "core_load"
    case fullLoad = "full_load"
    case linkedRoundRootsLoad = "linked_round_roots_load"
    case roundSnapshotLoad = "round_snapshot_load"
    case attendancePreload = "attendance_preload"
    case roundSync = "round_sync"
    case automaticAwardsRefresh = "automatic_awards_refresh"
    case standingsRebuild = "standings_rebuild"
    case teamInsight = "team_insight"
}

struct SeriesPerformanceSample: Equatable, Sendable {
    let operation: SeriesPerformanceOperation
    let durationMilliseconds: Int
    let logicalReadCount: Int
    let logicalWriteCount: Int
    let activeListenerCount: Int
    let itemCount: Int
    let context: String?
}

@MainActor
final class SeriesPerformanceRecorder {
    static let shared = SeriesPerformanceRecorder()
    static let retainedSampleLimit = 200

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tigermindlabs.Hackers",
        category: "SeriesPerformance"
    )

    private(set) var samples: [SeriesPerformanceSample] = []

    private init() {}

    func record(
        _ operation: SeriesPerformanceOperation,
        startedAt: ContinuousClock.Instant,
        logicalReadCount: Int = 0,
        logicalWriteCount: Int = 0,
        activeListenerCount: Int = 0,
        itemCount: Int = 0,
        context: String? = nil
    ) {
        let sample = SeriesPerformanceSample(
            operation: operation,
            durationMilliseconds: Self.elapsedMilliseconds(since: startedAt),
            logicalReadCount: logicalReadCount,
            logicalWriteCount: logicalWriteCount,
            activeListenerCount: activeListenerCount,
            itemCount: itemCount,
            context: context
        )
        samples.append(sample)
        if samples.count > Self.retainedSampleLimit {
            samples.removeFirst(samples.count - Self.retainedSampleLimit)
        }

        logger.info(
            "operation=\(sample.operation.rawValue, privacy: .public) duration_ms=\(sample.durationMilliseconds) reads=\(sample.logicalReadCount) writes=\(sample.logicalWriteCount) listeners=\(sample.activeListenerCount) items=\(sample.itemCount) context=\(sample.context ?? "none", privacy: .private)"
        )
    }

    func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    nonisolated static func elapsedMilliseconds(
        since startedAt: ContinuousClock.Instant,
        endingAt: ContinuousClock.Instant = .now
    ) -> Int {
        let components = startedAt.duration(to: endingAt).components
        let millisecondsFromSeconds = components.seconds * 1_000
        let millisecondsFromAttoseconds = components.attoseconds / 1_000_000_000_000_000
        return max(0, Int(millisecondsFromSeconds + millisecondsFromAttoseconds))
    }
}
