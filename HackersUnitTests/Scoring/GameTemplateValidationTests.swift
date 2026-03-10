//
//  GameTemplateValidationTests.swift
//  HackersTests
//
//  Created by Kyle Beard on 3/7/26.
//

@testable import Hackers
import XCTest

final class GameTemplateValidationTests: XCTestCase {

    // MARK: - Valid Templates

    func testValidStrokePlayTemplate() {
        let template = FormatTemplateRegistry.strokePlayGross
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Stroke play gross should pass validation: \(errors)")
    }

    func testValidStrokePlayNetTemplate() {
        let template = FormatTemplateRegistry.strokePlayNet
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Stroke play net should pass validation: \(errors)")
    }

    func testValidStablefordTemplate() {
        let template = FormatTemplateRegistry.stableford
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Stableford should pass validation: \(errors)")
    }

    func testValidMatchPlayTemplate() {
        let template = FormatTemplateRegistry.matchPlayIndividual
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Match play should pass validation: \(errors)")
    }

    func testValidBestBallTemplate() {
        let template = FormatTemplateRegistry.bestBall
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Best ball should pass validation: \(errors)")
    }

    func testValidBest2of4Template() {
        let template = FormatTemplateRegistry.bestTwoOfFour
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Best 2 of 4 should pass validation: \(errors)")
    }

    func testValidStrokePlayMatchupIndividualTemplate() {
        let template = FormatTemplateRegistry.strokePlayMatchupIndividual
        let errors = template.validate()
        XCTAssertTrue(errors.isEmpty, "Individual matchup (stroke play) should pass validation: \(errors)")
        XCTAssertEqual(template.competitionScope, .matchup)
        XCTAssertEqual(template.subject, .participant)
        XCTAssertTrue(template.requirements.requiresMatchups)
        XCTAssertFalse(template.requirements.requiresTeams)
    }

    // MARK: - Invalid Templates

    func testInvalid_SelectWithBothIncludeAndExclude() {
        var template = FormatTemplateRegistry.bestBall
        template.pipeline = [
            .select(RankSelection(includeRanks: [1], excludeRanks: [2]))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.selectCannotHaveBothIncludeAndExclude))
    }

    func testInvalid_SelectWithNoRanks() {
        var template = FormatTemplateRegistry.bestBall
        template.pipeline = [
            .select(RankSelection(includeRanks: nil, excludeRanks: nil))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.selectRequiresRanks))
    }

    func testInvalid_SelectWithEmptyRanks() {
        var template = FormatTemplateRegistry.bestBall
        template.pipeline = [
            .select(RankSelection(includeRanks: [], excludeRanks: []))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.selectRequiresRanks))
    }

    func testInvalid_ParRelativeWithoutEntries() {
        var template = FormatTemplateRegistry.stableford
        template.pipeline = [
            .transform(PointsMap(mode: .parRelative, entries: nil))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.parRelativeRequiresEntries))
    }

    func testInvalid_ParRelativeWithEmptyEntries() {
        var template = FormatTemplateRegistry.stableford
        template.pipeline = [
            .transform(PointsMap(mode: .parRelative, entries: []))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.parRelativeRequiresEntries))
    }

    func testInvalid_ParDependentWithoutMultiplier() {
        var template = FormatTemplateRegistry.strokePlayGross
        template.pipeline = [
            .transform(PointsMap(mode: .parDependent, parMultiplier: nil))
        ]

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.parDependentRequiresMultiplier))
    }

    func testInvalid_TeamSubjectWithoutRequiresTeams() {
        var template = FormatTemplateRegistry.bestBall
        template.requirements.requiresTeams = false

        let errors = template.validate()
        XCTAssertTrue(errors.contains(.teamSubjectRequiresTeams))
    }

    // MARK: - JSON Round-Trip

    func testTemplateJsonRoundTrip() throws {
        let template = FormatTemplateRegistry.stableford
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(template)
        let decoded = try JSONDecoder().decode(GameTemplate.self, from: data)

        XCTAssertEqual(decoded.id, template.id)
        XCTAssertEqual(decoded.name, template.name)
        XCTAssertEqual(decoded.category, template.category)
        XCTAssertEqual(decoded.pipeline.count, template.pipeline.count)
        XCTAssertEqual(decoded.leaderboardSort, template.leaderboardSort)
    }

    func testScoringStageJsonRoundTrip() throws {
        let stages: [ScoringStage] = [
            .select(RankSelection(includeRanks: [1])),
            .transform(.stableford),
            .modify(ConditionalModifier(predicate: .scoreToPar(.lessThanOrEqual, -1), effect: .multiply(2.0))),
            .reduce(Reduction(mode: .sum, scope: .perRound)),
            .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half)),
        ]

        let data = try JSONEncoder().encode(stages)
        let decoded = try JSONDecoder().decode([ScoringStage].self, from: data)

        XCTAssertEqual(decoded.count, stages.count)
    }

    // MARK: - Template Registry

    func testAllRegistryTemplatesPassValidation() {
        for template in FormatTemplateRegistry.allTemplates {
            let errors = template.validate()
            XCTAssertTrue(errors.isEmpty, "Template '\(template.name)' (\(template.id)) failed validation: \(errors)")
        }
    }

    func testRegistryLookupReturnsCorrectTemplate() {
        let template = FormatTemplateRegistry.template(for: "stableford")
        XCTAssertEqual(template.id, "stableford")
        XCTAssertEqual(template.name, "Stableford")
    }

    func testRegistryLookupFallsBackToStrokePlay() {
        let template = FormatTemplateRegistry.template(for: "nonexistent_template_id")
        XCTAssertEqual(template.id, "stroke_play")
    }
}
