import SwiftUI
import XCTest
@testable import Hackers

@MainActor
final class ScorecardStrokeDotRegressionTests: XCTestCase {
    func testPolicyShowsOnlyPositiveReceivedStrokesOnGross() {
        for allocation in [-3, -1, 0, 1, 2, 3] {
            XCTAssertEqual(ScorecardStrokeDotPolicy.visibleCount(strokesReceived: allocation, basis: .gross), max(0, allocation))
            XCTAssertEqual(ScorecardStrokeDotPolicy.visibleCount(strokesReceived: allocation, basis: .net), 0)
        }
    }

    // Render the production cell, not just the policy: the RC's isScored gate
    // passed allocation-only tests while still hiding dots in the view.
    func testFullAndLiveScorecardCellsShowDotsBeforeAndAfterScoring() throws {
        let model = model(snapshot: fixture())
        let participant = try XCTUnwrap(model.snapshot.participants.first)
        for scheme in [ColorScheme.light] {
            for presentation in [FullScorecardPresentation.modal, .embeddedLiveTable, .embeddedInsights] {
                let card = FullScorecardView(viewModel: model, participant: participant, presentation: presentation)
                for scored in [false, true] {
                    for allocation in [0, 1, 2, 3] {
                        let cell = card.scoreCell(
                            par: 4, gross: scored ? 4 : nil, net: scored ? 4 - allocation : nil,
                            strokesReceived: allocation, isSelected: false, highlightColor: .blue
                        )
                        let image = try render(cell, width: 60, height: 64, scheme: scheme)
                        XCTAssertEqual(try dotCount(image, diameter: 3, scheme: scheme), allocation,
                                       "\(presentation), \(scheme), scored=\(scored), allocation=\(allocation)")
                    }
                }
            }
        }
    }

    func testHoleCellShowsDotsBeforeAndAfterScoring() throws {
        for scheme in [ColorScheme.light, .dark] {
            for scored in [false, true] {
                for allocation in [0, 1, 2, 3] {
                    let cell = ScorecardHoleCell(
                        palette: .init(theme: .primary, scheme: scheme), holeNumber: 1, par: 4,
                        gross: scored ? 4 : nil, net: scored ? 4 - allocation : nil,
                        strokesReceived: allocation, basis: .gross
                    )
                    let image = try render(cell, width: 100, height: 116, scheme: scheme)
                    XCTAssertEqual(try dotCount(image, diameter: 4, scheme: scheme), allocation)
                }
            }
        }
    }

    func testNetCellsHideDotsAndDisplayNetRatherThanGross() throws {
        let model = model(snapshot: fixture())
        model.scoreBasis = .net
        let participant = try XCTUnwrap(model.snapshot.participants.first)
        let card = FullScorecardView(viewModel: model, participant: participant)
        for scheme in [ColorScheme.light] {
            for allocation in [-2, 0, 1, 2, 3] {
                for scored in [false, true] {
                    let cell = card.scoreCell(
                        par: 4, gross: scored ? 8 : nil, net: scored ? 4 : nil,
                        strokesReceived: allocation, isSelected: false, highlightColor: .blue
                    )
                    let reference = card.scoreCell(
                        par: 4, gross: scored ? 4 : nil, net: scored ? 4 : nil,
                        strokesReceived: 0, isSelected: false, highlightColor: .blue
                    )
                    let image = try render(cell, width: 60, height: 64, scheme: scheme)
                    XCTAssertEqual(try dotCount(image, diameter: 3, scheme: scheme), 0)
                    XCTAssertEqual(image.pngData(), try render(reference, width: 60, height: 64, scheme: scheme).pngData())

                    let hole = ScorecardHoleCell(
                        palette: .init(theme: .primary, scheme: scheme), holeNumber: 1, par: 4,
                        gross: scored ? 8 : nil, net: scored ? 4 : nil,
                        strokesReceived: allocation, basis: .net
                    )
                    XCTAssertEqual(try dotCount(render(hole, width: 100, height: 116, scheme: scheme), diameter: 4, scheme: scheme), 0)
                }
            }
        }
    }

    func testIndividualGrossRowShowsDotsAndNetRowDoesNot() throws {
        for scheme in [ColorScheme.light] {
            for scored in [false, true] {
                for allocation in [0, 1, 2, 3] {
                    let model = model(snapshot: fixture(handicap: allocation * 18, scored: scored))
                    let participant = try XCTUnwrap(model.snapshot.participants.first)
                    let card = IndividualScorecardView(viewModel: model, participant: participant, presentation: .embedded)
                    let gross = try render(card.scorecardScoreRow(holes: [1, 2]), width: 240, height: 48, scheme: scheme)
                    let net = try render(card.scorecardNetRow(holes: [1, 2]), width: 240, height: 48, scheme: scheme)
                    XCTAssertEqual(try dotCount(gross, diameter: 3, scheme: scheme), allocation * 2,
                                   "\(scheme), scored=\(scored), allocation=\(allocation)")
                    XCTAssertEqual(try dotCount(net, diameter: 3, scheme: scheme), 0)
                }
            }
        }
    }

    func testHostedScorecardsRenderUnscoredDotsInLightAndDarkModes() async throws {
        for scheme in [ColorScheme.light, .dark] {
            for individual in [false, true] {
                let snapshot = fixture()
                let model = model(snapshot: snapshot)
                let participant = try XCTUnwrap(model.snapshot.participants.first)
                let card: AnyView = individual
                    ? AnyView(IndividualScorecardView(viewModel: model, participant: participant, presentation: .embedded, showsPlayerHeader: false))
                    : AnyView(FullScorecardView(viewModel: model, participant: participant, allowsScoreEditing: false, presentation: .embeddedLiveTable))
                let withDots = try await hostedImage(card, scheme: scheme) { model.scoreBasis = .gross }
                var disabled = snapshot
                disabled.round.configuration.handicapsEnabled = false
                model.set(snapshot: disabled)
                let withoutDots = try await hostedImage(card, scheme: scheme) { model.scoreBasis = .gross }
                XCTAssertGreaterThan(try dotCount(withDots, diameter: 3, scheme: scheme),
                                     try dotCount(withoutDots, diameter: 3, scheme: scheme),
                                     "Expected rendered allocations: individual=\(individual), scheme=\(scheme)")
                let attachment = XCTAttachment(image: withDots)
                attachment.name = "Scorecard-\(individual ? "individual" : "live")-\(scheme == .light ? "light" : "dark")-unscored"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testNineAndEighteenHoleAllocationsDoNotDependOnScoresOrDisplayBasis() throws {
        for range in [HoleRange(startHole: 1, endHole: 9), HoleRange(startHole: 10, endHole: 18), HoleRange(startHole: 1, endHole: 18)] {
            for basis in [SeriesHandicapStrokeBasis.nineHole, .eighteenHole] {
                var snapshot = fixture(handicap: basis == .nineHole ? 20 : 40, range: range)
                snapshot.round.configuration.handicapStrokeBasis = basis
                let model = model(snapshot: snapshot)
                let participant = try XCTUnwrap(model.snapshot.participants.first)
                let before = range.holeNumbers.map { model.strokesReceivedOnHole(participant: participant, holeNumber: $0) }
                // 20 over nine => two holes get three, seven get two;
                // 40 over eighteen => four get three, fourteen get two.
                XCTAssertEqual(before.reduce(0, +), range.count == 9 ? 20 : 40)
                XCTAssertEqual(before.filter { $0 == 3 }.count, range.count == 9 ? 2 : 4)
                XCTAssertNil(model.grossStrokes(for: participant.id, holeNumber: range.startHole))
                snapshot.scoring = [score(snapshot: snapshot, hole: range.startHole)]
                model.set(snapshot: snapshot)
                model.scoreBasis = .net
                XCTAssertEqual(range.holeNumbers.map { model.strokesReceivedOnHole(participant: participant, holeNumber: $0) }, before)
                XCTAssertEqual(model.netStrokesOnHole(participant: participant, holeNumber: range.startHole), 1)
            }
        }
    }

    func testNegativeAllocationsKeepExistingNetMathWithoutReceivedDots() throws {
        let snapshot = fixture(handicap: -2, scored: true)
        let model = model(snapshot: snapshot)
        let participant = try XCTUnwrap(model.snapshot.participants.first)
        for hole in model.courseOrderHoleNumbers {
            let received = model.strokesReceivedOnHole(participant: participant, holeNumber: hole)
            XCTAssertLessThanOrEqual(received, 0)
            XCTAssertEqual(ScorecardStrokeDotPolicy.visibleCount(strokesReceived: received, basis: .gross), 0)
            if let gross = model.grossStrokes(for: participant.id, holeNumber: hole) {
                XCTAssertEqual(model.netStrokesOnHole(participant: participant, holeNumber: hole), gross - received)
            }
        }
    }

    func testDisabledHandicapsDoNotAllocateDots() throws {
        var snapshot = fixture(handicap: 40)
        snapshot.round.configuration.handicapsEnabled = false
        let model = model(snapshot: snapshot)
        let participant = try XCTUnwrap(model.snapshot.participants.first)
        XCTAssertTrue(model.courseOrderHoleNumbers.allSatisfy { model.strokesReceivedOnHole(participant: participant, holeNumber: $0) == 0 })
    }

    func testSharedTeamAndPartnershipAllocationsExistBeforeScores() throws {
        for team in [false, true] {
            var snapshot = sharedFixture(team: team)
            snapshot.round.configuration.handicapsEnabled = true
            snapshot.participants = snapshot.participants.map {
                var participant = $0
                participant.adjustedHandicap = 72
                return participant
            }
            snapshot.scoring = []
            let model = model(snapshot: snapshot)
            let rows = model.scorecardParticipants
            XCTAssertFalse(rows.isEmpty)
            for row in rows {
                XCTAssertTrue(row.isSharedScoreUnit)
                let received = model.scoringUnitStrokesReceived(scoringUnitID: row.scoringUnitID, holeNumber: 1)
                XCTAssertGreaterThan(received, 0)
                XCTAssertNil(model.scoringUnitGrossStrokes(scoringUnitID: row.scoringUnitID, holeNumber: 1))
                XCTAssertEqual(ScorecardStrokeDotPolicy.visibleCount(strokesReceived: received, basis: .gross), received)
            }
        }
    }

    func testCompletedSeriesAllowancesAndSnapshotRemainUnchanged() throws {
        var snapshot = fixture(handicap: 36, scored: true)
        snapshot.round.status = .complete
        snapshot.participants[0].seriesMemberID = "series_member"
        snapshot.participants[0].leagueHandicapStrokesAtCreation = 36
        snapshot.participants[0].handicapSnapshot = RoundParticipantHandicapSnapshot(
            authoritativeCourseHandicap: 36, handicapIndex: 31.2, effectiveStrokes: 36,
            courseID: "dots_course", courseName: "Dot Club", teeBoxID: "dots_tee", teeName: "White", teeGender: "male",
            holeSegment: .full18, courseRating: 72, courseSlope: 113, par: 72,
            handicapStrokeBasis: .eighteenHole, maximumHandicap: nil, entryFormat: .courseHandicap,
            calculatorFingerprint: "frozen-series", selectedHandicapScoreIDs: ["historical_score"], calculatedAt: .init(), source: .league
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(snapshot.participants)
        let scoresBefore = try encoder.encode(snapshot.scoring)
        let model = model(snapshot: snapshot)
        let participant = try XCTUnwrap(model.snapshot.participants.first)
        for basis in [ScoreBasis.gross, .net, .gross] {
            model.scoreBasis = basis
            for hole in model.courseOrderHoleNumbers {
                let received = model.strokesReceivedOnHole(participant: participant, holeNumber: hole)
                XCTAssertEqual(received, 2)
                XCTAssertEqual(ScorecardStrokeDotPolicy.visibleCount(strokesReceived: received, basis: basis), basis == .gross ? 2 : 0)
            }
        }
        XCTAssertEqual(try encoder.encode(model.snapshot.participants), before)
        XCTAssertEqual(try encoder.encode(model.snapshot.scoring), scoresBefore)
    }

    private func model(snapshot: RoundSnapshot) -> LiveRoundViewModel {
        let model = LiveRoundViewModel()
        model.set(snapshot: snapshot)
        model.scoreBasis = .gross
        return model
    }

    private func fixture(handicap: Int = 36, scored: Bool = false, range: HoleRange = .init(startHole: 1, endHole: 18)) -> RoundSnapshot {
        let tee = Tee(id: "dots_tee", name: "White", gender: Gender.male.rawValue, totalHoles: 18,
                      holes: (1...18).map { Hole(number: $0, par: 4, yardage: 360, handicap: $0) },
                      ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let participant = RoundParticipant(id: "dots_player", name: Name("Dot", "Player"), teeBoxID: tee.id,
                                           originalHandicap: handicap, adjustedHandicap: handicap, parentID: "dots_round")
        let format = GameFormat.strokePlay
        let round = Round(id: "dots_round", status: .live, configuration: RoundConfiguration(
            primaryFormat: format,
            courses: [CourseSegment(courseInfo: CourseInfo(id: "dots_course", name: "Dot Club", totalHoles: 18, tees: [tee]), holeRange: range, defaultTee: tee.id)],
            handicapStrokeBasis: .eighteenHole, handicapsEnabled: true
        ))
        let segment = RoundSegment(id: "dots_segment", roundID: round.id, holeRange: range, gameFormat: format,
                                   scoringUnits: [ScoringUnit(id: participant.id, owner: .participant, ownerIDs: [participant.id], scoringMethod: .individual)], parentID: round.id)
        var snapshot = RoundSnapshot(round: round, participants: [participant], segments: [segment])
        if scored { snapshot.scoring = [score(snapshot: snapshot, hole: range.startHole)] }
        return snapshot
    }

    private func sharedFixture(team: Bool) -> RoundSnapshot {
        var snapshot = fixture()
        var second = snapshot.participants[0]
        second.id = "dots_partner"
        snapshot.participants.append(second)
        snapshot.participants = snapshot.participants.map {
            var participant = $0
            participant.teamID = "dots_team"
            return participant
        }
        snapshot.teams = [RoundTeam(id: "dots_team", name: "Team", color: "blue", index: 0, createdAt: .init(), parentID: snapshot.round.id)]
        snapshot.round.configuration.formatSummary = RoundFormatSummary(from: FormatTemplateRegistry.captainsChoice)
        snapshot.round.configuration.scoreOwnerScope = team ? .individual : .partnership
        snapshot.round.configuration.sharedScoreHandicapConfig = .scramble2Player
        snapshot.round.configuration.primaryFormat.configuration.method = .aggregate
        snapshot.round.configuration.primaryFormat.configuration.requiresTeams = true
        snapshot.scoringGroups = [RoundScoringGroup(id: "dots_pair", teamID: "dots_team", teeGroupID: "", kind: .partnership,
                                                  memberIDs: snapshot.participants.map(\.id), parentID: snapshot.round.id)]
        snapshot.segments[0].gameFormat = snapshot.round.configuration.primaryFormat
        snapshot.segments[0].templateID = FormatTemplateRegistry.captainsChoice.id
        snapshot.segments[0].scoringUnits = [ScoringUnit(id: "opaque_shared_unit", owner: team ? .team : .scoreOwner,
                                                       ownerIDs: team ? ["dots_team"] : snapshot.participants.map(\.id), scoringMethod: .aggregate)]
        return snapshot
    }

    private func score(snapshot: RoundSnapshot, hole: Int) -> ScoreEntry {
        ScoreEntry(id: "dots_score", holeNumber: hole, segmentID: "dots_segment", groupID: "",
                   scoringUnitID: "dots_player", participantIDs: ["dots_player"], strokes: 4,
                   entryID: "dots_player", parentID: snapshot.round.id)
    }

    private func render<V: View>(_ content: V, width: CGFloat, height: CGFloat, scheme: ColorScheme) throws -> UIImage {
        let renderer = ImageRenderer(content: content
            .frame(width: width, height: height)
            .background(scheme == .light ? Color.white : Color.black)
            .environment(\.colorScheme, scheme))
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
    }

    private func hostedImage(_ content: AnyView, scheme: ColorScheme, prepare: () -> Void) async throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let host = UIHostingController(rootView: content.environment(\.colorScheme, scheme))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        // FullScorecardView applies the round's default (net) on appearance.
        // Exercise the user's Gross selection after that lifecycle work.
        prepare()
        try await Task.sleep(for: .milliseconds(100))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
    }

    // Count isolated circular pixel components at the actual design diameter.
    // Score glyphs and decorations are larger. This catches a removed dot row,
    // the isScored gate, wrong allocations, and light/dark contrast regressions.
    private func dotCount(_ image: UIImage, diameter: Int, scheme: ColorScheme) throws -> Int {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var active = (0..<(width * height)).map { i in
            let brightness = (Int(pixels[i * 4]) + Int(pixels[i * 4 + 1]) + Int(pixels[i * 4 + 2])) / 3
            return scheme == .light ? brightness < 160 : brightness > 160
        }
        var count = 0
        for start in active.indices where active[start] {
            active[start] = false
            var queue = [start], cursor = 0
            var minX = start % width, maxX = minX, minY = start / width, maxY = minY
            while cursor < queue.count {
                let i = queue[cursor]; cursor += 1
                let x = i % width, y = i / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let next = ny * width + nx
                    if active[next] { active[next] = false; queue.append(next) }
                }
            }
            let w = maxX - minX + 1, h = maxY - minY + 1
            if abs(w - diameter * 3) <= 2 && abs(h - diameter * 3) <= 2 { count += 1 }
        }
        return count
    }
}
