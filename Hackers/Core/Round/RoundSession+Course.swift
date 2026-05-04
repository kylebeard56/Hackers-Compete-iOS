//
//  RoundSession+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundSession {
    func setDefaultTee(to teeID: String) async {
        addBreadcrumb(message: "Set default tee to teeBoxID: \(teeID)")
        let previousTeeID = snapshot.courseSegment?.defaultTee
        let previousTee = previousTeeID.flatMap { id in snapshot.tees.first(where: { $0.id == id }) }

        guard previousTeeID != teeID else { return }

        do {
            snapshot.round.configuration.courses[0].defaultTee = teeID
            _ = try await snapshot.round.put().get()

            if snapshot.configuration.handicapEntryFormat == .courseHandicap {
                var updatedSegment = snapshot.courseSegment
                updatedSegment?.defaultTee = teeID
                let recomputed = HandicapCalculator.recomputedParticipants(
                    snapshot.participants,
                    format: .courseHandicap,
                    courseSegment: updatedSegment
                )
                for participant in recomputed where snapshot.participants.first(where: { $0.id == participant.id }) != participant {
                    try await update(participant: participant)
                }
            }

            var props: [String: Any] = [:]
            if let previousTee {
                props.merge(
                    prefixedTelemetryProps(
                        [
                            "tee_id": previousTee.id,
                            "tee_name": previousTee.name
                        ],
                        prefix: "previous"
                    )
                ) { _, new in new }
            }

            emitRoundSetupEvent(
                "round_setup.default_tee_changed",
                teeID: teeID,
                extra: props
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set default tee", error: error)
        }
    }
    
    /// Updates the round's course segment. Option C: also persists to courses collection
    /// when the course is in our DB (PUT) or was edited from API (POST).
    func setCourseSegment(to segment: CourseSegment) async {
        addBreadcrumb()
        let previousSegment = snapshot.courseSegment
        let previousCourse = previousSegment.map { Course(info: $0.courseInfo) }
        let previousTee = previousSegment.flatMap { segment in
            segment.defaultTee.flatMap(segment.tee(from:))
        }

        var segmentToSave = segment
        let course = Course(info: segment.courseInfo)

        if !course.isEmpty {
            switch await FirebaseService.shared.saveCourse(course) {
            case .success(let saved):
                if !segment.courseInfo.id.isPopulated, saved.id.isPopulated {
                    segmentToSave.courseInfo = CourseInfo(course: saved, for: segment.holeSegment)
                }
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to save course to collection", error: error)
            }
        }

        do {
            if snapshot.round.configuration.courses.isEmpty {
                snapshot.round.configuration.courses = [segmentToSave]
            } else {
                snapshot.round.configuration.courses[0] = segmentToSave
            }
            _ = try await snapshot.round.put().get()

            let didSyncSegment = try await syncPrimarySegmentHoleRange(to: segmentToSave.holeRange)

            if snapshot.configuration.usesSequentialTeeStarts {
                try await resequenceTeeGroupsForSequentialStarts()
            }

            if snapshot.configuration.handicapEntryFormat == .courseHandicap {
                let recomputed = HandicapCalculator.recomputedParticipants(
                    snapshot.participants,
                    format: .courseHandicap,
                    courseSegment: segmentToSave
                )
                for participant in recomputed where snapshot.participants.first(where: { $0.id == participant.id }) != participant {
                    try await update(participant: participant)
                }
            }

            guard previousSegment != segmentToSave || didSyncSegment else { return }

            var props: [String: Any] = [:]
            if let previousCourse, let previousSegment {
                props.merge(
                    prefixedTelemetryProps(
                        telemetryCourseProperties(
                            course: previousCourse,
                            holeSegment: previousSegment.holeSegment,
                            selectedTee: previousTee
                        ),
                        prefix: "previous"
                    )
                ) { _, new in new }
            }

            emitRoundSetupEvent(
                "round_setup.course_changed",
                teeID: segmentToSave.defaultTee,
                extra: props
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set course segment", error: error)
        }
    }

    @discardableResult
    private func syncPrimarySegmentHoleRange(to holeRange: HoleRange) async throws -> Bool {
        guard var mainSegment = snapshot.segments.first,
              mainSegment.holeRange != holeRange else {
            return false
        }

        let previousHoleRange = mainSegment.holeRange
        mainSegment.holeRange = holeRange
        mainSegment.lastUpdatedAt = .init()
        snapshot.segments[0] = mainSegment
        _ = try await mainSegment.put().get()

        addBreadcrumb(
            message: "Synced primary segment hole range",
            parameters: [
                "previous_start_hole": previousHoleRange.startHole,
                "previous_end_hole": previousHoleRange.endHole,
                "start_hole": holeRange.startHole,
                "end_hole": holeRange.endHole,
                "segment_id": mainSegment.id
            ]
        )
        return true
    }

    func unsetCourseSegment() async {
        addBreadcrumb()
        guard snapshot.courseSegment != nil else { return }

        do {
            snapshot.round.configuration.courses = []
            _ = try await snapshot.round.put().get()

            emitRoundSetupEvent(
                "round_setup.course_removed",
                teeID: nil
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to unset course segment", error: error)
        }
    }
}
