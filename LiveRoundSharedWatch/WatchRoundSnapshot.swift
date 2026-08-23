import Foundation

enum WatchScoreBasis: String, CaseIterable, Codable, Identifiable, Sendable {
    case gross
    case net

    var id: Self { self }

    var label: String {
        rawValue.capitalized
    }
}

struct WatchCumulativeScoreSummary: Equatable, Sendable {
    let displayValue: String
    let completedHoles: Int
    let totalHoles: Int
    let isComplete: Bool
}

struct WatchRoundSnapshot: Codable, Equatable, Sendable {
    // All fields added after v1 are optional, so continue emitting v1 for
    // compatibility with Watch installs that have not updated alongside iPhone.
    static let currentSchemaVersion = 1
    static let supportedSchemaVersions = 1...2

    static func supports(schemaVersion: Int) -> Bool {
        supportedSchemaVersions.contains(schemaVersion)
    }

    enum Phase: String, Codable, Sendable {
        case live
        case paused
    }

    enum ScoreInputMode: String, Codable, Sendable {
        case strokes
        case relativeToPar = "relative_to_par"
    }

    struct Hole: Codable, Equatable, Identifiable, Sendable {
        var id: Int { number }

        let number: Int
        let par: Int
        let inputMinimum: Int?
        let inputMaximum: Int?

        init(
            number: Int,
            par: Int,
            inputMinimum: Int? = nil,
            inputMaximum: Int? = nil
        ) {
            self.number = number
            self.par = par
            self.inputMinimum = inputMinimum
            self.inputMaximum = inputMaximum
        }
    }

    struct Subject: Codable, Equatable, Identifiable, Sendable {
        struct HoleUnit: Codable, Equatable, Identifiable, Sendable {
            var id: Int { holeNumber }

            let holeNumber: Int
            let scoringUnitID: String
            let participantIDs: [String]
            let strokesReceived: Int?

            init(
                holeNumber: Int,
                scoringUnitID: String,
                participantIDs: [String],
                strokesReceived: Int? = nil
            ) {
                self.holeNumber = holeNumber
                self.scoringUnitID = scoringUnitID
                self.participantIDs = participantIDs
                self.strokesReceived = strokesReceived
            }
        }

        let id: String
        let title: String
        let compactTitle: String?
        let subtitle: String?
        let anchorParticipantID: String
        let teeGroupID: String
        let holeUnits: [HoleUnit]

        init(
            id: String,
            title: String,
            compactTitle: String? = nil,
            subtitle: String?,
            anchorParticipantID: String,
            teeGroupID: String,
            holeUnits: [HoleUnit]
        ) {
            self.id = id
            self.title = title
            self.compactTitle = compactTitle
            self.subtitle = subtitle
            self.anchorParticipantID = anchorParticipantID
            self.teeGroupID = teeGroupID
            self.holeUnits = holeUnits
        }

        func unit(for holeNumber: Int) -> HoleUnit? {
            holeUnits.first { $0.holeNumber == holeNumber }
        }
    }

    struct Score: Codable, Equatable, Identifiable, Sendable {
        var id: String { "\(holeNumber):\(scoringUnitID)" }

        let holeNumber: Int
        let scoringUnitID: String
        let value: Int?
        let revision: String?
    }

    struct Competition: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable {
            case matchup
            case field
        }

        struct Summary: Codable, Equatable, Sendable {
            let label: String
            let primary: String
            let secondary: String?
            let detail: String
        }

        struct Section: Codable, Equatable, Identifiable, Sendable {
            let id: String
            let title: String
            let detail: String?
            let isCurrentUserSection: Bool
            let rows: [Row]
        }

        struct LeaderboardVariant: Codable, Equatable, Identifiable, Sendable {
            let id: String
            let label: String
            let sections: [Section]
        }

        struct Row: Codable, Equatable, Identifiable, Sendable {
            let id: String
            let position: String?
            let title: String
            let subtitle: String?
            let score: String
            let thru: String?
            let winPercentage: Int?
            let isCurrentUser: Bool
            let grossScore: String?
            let netScore: String?
            let handicapLabel: String?

            init(
                id: String,
                position: String?,
                title: String,
                subtitle: String?,
                score: String,
                thru: String?,
                winPercentage: Int?,
                isCurrentUser: Bool,
                grossScore: String? = nil,
                netScore: String? = nil,
                handicapLabel: String? = nil
            ) {
                self.id = id
                self.position = position
                self.title = title
                self.subtitle = subtitle
                self.score = score
                self.thru = thru
                self.winPercentage = winPercentage
                self.isCurrentUser = isCurrentUser
                self.grossScore = grossScore
                self.netScore = netScore
                self.handicapLabel = handicapLabel
            }
        }

        let kind: Kind
        let title: String
        let formatLabel: String
        let summary: Summary
        let sections: [Section]
        let leaderboardVariants: [LeaderboardVariant]?

        init(
            kind: Kind,
            title: String,
            formatLabel: String,
            summary: Summary,
            sections: [Section],
            leaderboardVariants: [LeaderboardVariant]? = nil
        ) {
            self.kind = kind
            self.title = title
            self.formatLabel = formatLabel
            self.summary = summary
            self.sections = sections
            self.leaderboardVariants = leaderboardVariants
        }
    }

    let schemaVersion: Int
    let revision: Int64
    let roundID: String
    let title: String
    let phase: Phase
    let inputMode: ScoreInputMode
    let selectedHole: Int
    let holes: [Hole]
    let subjects: [Subject]
    var scores: [Score]
    let competition: Competition?
    let additionalCompetitions: [Competition]?
    let acknowledgedMutationIDs: Set<UUID>
    let generatedAt: Date

    var competitions: [Competition] {
        var values = competition.map { [$0] } ?? []
        values.append(contentsOf: additionalCompetitions ?? [])
        return values
    }

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        revision: Int64,
        roundID: String,
        title: String,
        phase: Phase,
        inputMode: ScoreInputMode,
        selectedHole: Int,
        holes: [Hole],
        subjects: [Subject],
        scores: [Score],
        competition: Competition? = nil,
        additionalCompetitions: [Competition]? = nil,
        acknowledgedMutationIDs: Set<UUID> = [],
        generatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.roundID = roundID
        self.title = title
        self.phase = phase
        self.inputMode = inputMode
        self.selectedHole = selectedHole
        self.holes = holes
        self.subjects = subjects
        self.scores = scores
        self.competition = competition
        self.additionalCompetitions = additionalCompetitions
        self.acknowledgedMutationIDs = acknowledgedMutationIDs
        self.generatedAt = generatedAt
    }

    func score(for scoringUnitID: String, holeNumber: Int) -> Score? {
        scores.first {
            $0.scoringUnitID == scoringUnitID && $0.holeNumber == holeNumber
        }
    }

    func hasSamePresentation(as other: Self) -> Bool {
        schemaVersion == other.schemaVersion
            && revision == other.revision
            && roundID == other.roundID
            && title == other.title
            && phase == other.phase
            && inputMode == other.inputMode
            && selectedHole == other.selectedHole
            && holes == other.holes
            && subjects == other.subjects
            && scores == other.scores
            && competition == other.competition
            && additionalCompetitions == other.additionalCompetitions
            && acknowledgedMutationIDs == other.acknowledgedMutationIDs
    }

    func cumulativeScore(
        for subject: Subject,
        basis: WatchScoreBasis,
        value: (Subject, Int) -> Int?
    ) -> WatchCumulativeScoreSummary {
        let scoredHoles = holes.compactMap { hole -> (score: Int, par: Int)? in
            guard let inputValue = value(subject, hole.number) else { return nil }
            let gross = inputMode == .relativeToPar
                ? max(1, hole.par + inputValue)
                : inputValue
            let score: Int
            switch basis {
            case .gross:
                score = gross
            case .net:
                score = max(0, gross - (subject.unit(for: hole.number)?.strokesReceived ?? 0))
            }
            return (score, hole.par)
        }
        let isComplete = !holes.isEmpty && scoredHoles.count == holes.count
        guard !scoredHoles.isEmpty else {
            return .init(
                displayValue: "—",
                completedHoles: 0,
                totalHoles: holes.count,
                isComplete: false
            )
        }

        let strokes = scoredHoles.reduce(0) { $0 + $1.score }
        let par = scoredHoles.reduce(0) { $0 + $1.par }
        return .init(
            displayValue: isComplete ? String(strokes) : Self.scoreToParLabel(strokes - par),
            completedHoles: scoredHoles.count,
            totalHoles: holes.count,
            isComplete: isComplete
        )
    }

    private static func scoreToParLabel(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : String(score)
    }
}
