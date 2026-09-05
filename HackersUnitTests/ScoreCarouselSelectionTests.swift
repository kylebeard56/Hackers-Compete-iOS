//
//  ScoreCarouselSelectionTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class ScoreCarouselSelectionTests: XCTestCase {
    func testFriendlyModeCentersEachHolesPar() {
        for par in [3, 4, 5] {
            let selection = ScoreCarouselSelection.initialValue(
                savedScore: nil,
                par: par,
                isFriendlyMode: true
            )

            XCTAssertEqual(selection, 0)
            XCTAssertEqual(
                ScoreCarouselSelection.displayedTriplet(
                    centeredOn: selection,
                    par: par,
                    isFriendlyMode: true
                ),
                [par - 1, par, par + 1]
            )
        }
    }

    func testStandardModeCentersEachHolesPar() {
        for par in [3, 4, 5] {
            let selection = ScoreCarouselSelection.initialValue(
                savedScore: nil,
                par: par,
                isFriendlyMode: false
            )

            XCTAssertEqual(selection, par)
            XCTAssertEqual(
                ScoreCarouselSelection.displayedTriplet(
                    centeredOn: selection,
                    par: par,
                    isFriendlyMode: false
                ),
                [par - 1, par, par + 1]
            )
        }
    }

    func testSavedScoreRemainsCentered() {
        XCTAssertEqual(
            ScoreCarouselSelection.initialValue(savedScore: -1, par: 5, isFriendlyMode: true),
            -1
        )
        XCTAssertEqual(
            ScoreCarouselSelection.displayedTriplet(centeredOn: -1, par: 5, isFriendlyMode: true),
            [3, 4, 5]
        )

        XCTAssertEqual(
            ScoreCarouselSelection.initialValue(savedScore: 6, par: 5, isFriendlyMode: false),
            6
        )
        XCTAssertEqual(
            ScoreCarouselSelection.displayedTriplet(centeredOn: 6, par: 5, isFriendlyMode: false),
            [5, 6, 7]
        )
    }

    func testRepeatedPlayerAndHoleTransitionsDoNotReusePreviousPar() {
        let transitions: [(par: Int, savedScore: Int?)] = [
            (5, nil), (5, nil), (5, nil), (5, nil),
            (4, nil), (4, nil), (4, nil), (4, nil),
            (3, nil), (5, nil), (4, nil)
        ]

        let centeredStrokes = transitions.map { transition in
            let selection = ScoreCarouselSelection.initialValue(
                savedScore: transition.savedScore,
                par: transition.par,
                isFriendlyMode: true
            )
            return ScoreCarouselSelection.displayedStrokes(
                for: selection,
                par: transition.par,
                isFriendlyMode: true
            )
        }

        XCTAssertEqual(centeredStrokes, transitions.map(\.par))
    }
}
