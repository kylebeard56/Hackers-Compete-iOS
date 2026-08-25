//
//  CourseTextLookupService.swift
//  Hackers
//
//  Natural-language course lookup using the app's text LLM provider with a server-side
//  web_search tool. The provider is asked to identify the exact course AND return its
//  current scorecard (par/yardage/HCP per hole) by browsing the web for the official card.
//

import Foundation

enum CourseTextLookupError: Error {
    case apiKeyMissing
    case invalidResponse
    case decodingFailed(String)
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
}

struct AskAICourseLookupContext: Equatable {
    var isLocationAssistEnabled: Bool
    var approximateLocation: ScorecardScanApproximateLocation?
    var model: AskAITextModel

    init(
        isLocationAssistEnabled: Bool = false,
        approximateLocation: ScorecardScanApproximateLocation? = nil,
        model: AskAITextModel = .defaultSelection
    ) {
        self.isLocationAssistEnabled = isLocationAssistEnabled
        self.approximateLocation = approximateLocation
        self.model = model
    }
}

struct AskAICourseCandidate {
    let course: Course
    let requiresReview: Bool
    let isCanonicalMatch: Bool
    let sources: [AskAICourseCandidateSource]

    init(
        course: Course,
        requiresReview: Bool,
        isCanonicalMatch: Bool,
        sources: [AskAICourseCandidateSource]
    ) {
        self.course = course
        self.requiresReview = requiresReview
        self.isCanonicalMatch = isCanonicalMatch
        self.sources = sources
    }
}

enum AskAICourseCandidateSource: String, CaseIterable, Hashable {
    case internet
    case golfCourseAPI = "golf_course_api"

    var label: String {
        switch self {
        case .internet:
            return "Internet"
        case .golfCourseAPI:
            return "Golf Course API"
        }
    }
}

struct AskAICourseChatMessage: Identifiable {
    enum Role: String {
        case user
        case assistant
    }

    let id: String
    let role: Role
    let text: String
    let candidates: [AskAICourseCandidate]

    init(
        id: String = HackersID.string(),
        role: Role,
        text: String,
        candidate: AskAICourseCandidate? = nil,
        candidates: [AskAICourseCandidate] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        if let candidate {
            self.candidates = [candidate]
        } else {
            self.candidates = candidates
        }
    }

    var isUser: Bool {
        role == .user
    }
}

enum AskAICourseLookupSource: String {
    case webScorecard = "web_scorecard"
    case apiFallback = "api_fallback"
    case webAndAPI = "web_and_api"
    case multiple = "multiple"
    case noMatch = "no_match"
}

struct AskAICourseLookupResult {
    let assistantMessage: String
    let candidates: [AskAICourseCandidate]
    let source: AskAICourseLookupSource
}

private enum CourseTextLookupPrompt {
    static func systemPrompt(context: AskAICourseLookupContext) -> String {
        var prompt = """
        Identify the exact golf course the user is about to play. Ask AI is web-first and deterministic.

        Tools:
        - web_search (max 2 uses) — resolve the exact course identity and look for public scorecard data.
        - extract_course_lookup — call exactly once at the end with the structured result. No prose.

        Process:
        1. Resolve the exact course identity from the conversation.
        2. Search the official course, club, resort, operator, or club-managed site first.
        3. Only if the official site does not expose a reliable public scorecard, use other credible public sources.
        4. Return structured public scorecard data only when you have high confidence.
        5. If public scorecard extraction is not high confidence, do not invent data. Instead return ordered Golf Course API backup search strings.

        Web search:
        - Search official or operator-controlled pages first. Examples: the club website, resort site, trail/operator scorecard page, or official member/public scorecard PDF.
        - Acceptable fallback sources only when official pages do not provide the scorecard: GHIN/USGA, GolfPass, GolfNow, respected booking/operator pages with clear structured scorecard data.
        - Avoid blogs, Wikipedia, forums, or single-tee summaries.
        - Two queries max. Keep the search budget fixed and intentional.
        - Par, yardage, and handicap for a tee must come from one public source. Never stitch data across sources.

        Scorecard extraction:
        - Return every publicly listed tee row you can confidently verify. Do not collapse multiple tee rows into one.
        - Tee names should stay verbatim as printed.
        - Gender mapping: "ladies"/"women" => female; "men"/"championship" => male; otherwise unknown.
        - Populate front/back course rating and slope only when explicitly shown.
        - "High confidence" means you resolved the identity and found real public tee/hole data.
        - If the scorecard is missing, partial, ambiguous, paywalled, or inconsistent, set confidence to medium or low and omit the scorecard or return it with empty tees.

        Backup search strings:
        - Always return ordered `apiSearchStrings`, even when you return a high-confidence public scorecard.
        - Put the most official resolved course + routing name first, followed by official club/operator/trail variants that may help a strict API search.
        - For multi-course facilities, include course-specific routing strings like "Oxmoor Valley Ridge" before facility-only strings like "Oxmoor Valley".

        No invention:
        - Never invent tees, holes, par, yardage, handicap, rating, slope, website, phone, or coordinates.
        - Never use approximate user location to identify the course on its own or to fill location fields.
        """

        if context.isLocationAssistEnabled, context.approximateLocation != nil {
            prompt += """


            Location-assist rule:
            - Approximate user location may be appended below only to break ties between otherwise plausible candidates.
            - Never fill address, coordinates, website, or phone from approximate location.
            """
        }

        return prompt
    }

    static func finalInstruction(context: AskAICourseLookupContext) -> String {
        var instruction = "Use the conversation above to resolve the course. Search the web for the official/public scorecard first, then call extract_course_lookup exactly once with the resolved identity, confidence, optional scorecard, and ordered Golf Course API search strings. Always include API search strings when you can resolve any identity clue."

        if context.isLocationAssistEnabled,
           let approximateLocation = context.approximateLocation {
            instruction += "\nApproximate user location for tie-break only: \(approximateLocation.promptDescription)"
        }

        return instruction
    }
}

@MainActor
final class CourseTextLookupService: Loggable {
    static let shared = CourseTextLookupService()

    private let injectedProvider: LLMProviderProtocol?
    private let enrichmentService: CourseScorecardEnrichmentService

    init(
        provider: LLMProviderProtocol? = nil,
        enrichmentService: CourseScorecardEnrichmentService? = nil
    ) {
        self.injectedProvider = provider
        self.enrichmentService = enrichmentService ?? .shared
    }

    func resolveCourse(
        from transcript: [AskAICourseChatMessage],
        context: AskAICourseLookupContext = .init()
    ) async throws -> AskAICourseLookupResult {
        let provider = injectedProvider ?? lookupProvider(for: context.model)

        let messages = buildMessages(from: transcript, context: context)
        let scanContext = ScorecardScanContext(
            isLocationAssistEnabled: context.isLocationAssistEnabled,
            approximateLocation: context.approximateLocation
        )

        let lookup: AskAICourseLookupDTO
        do {
            lookup = try await callProvider(
                provider,
                messages: messages,
                model: context.model.config.model,
                scanContext: scanContext
            )
        } catch OpenAIProviderError.apiKeyMissing, AnthropicProviderError.apiKeyMissing {
            throw CourseTextLookupError.apiKeyMissing
        } catch OpenAIProviderError.requestTooLarge, AnthropicProviderError.requestTooLarge {
            throw CourseTextLookupError.requestTooLarge
        } catch OpenAIProviderError.rateLimitExceeded, AnthropicProviderError.rateLimitExceeded {
            throw CourseTextLookupError.rateLimitExceeded
        } catch OpenAIProviderError.overloaded, AnthropicProviderError.overloaded {
            throw CourseTextLookupError.overloaded
        } catch {
            throw error
        }

        let webCourse = draftCourse(from: lookup)
        let webCandidate = confirmedWebCandidate(from: lookup, course: webCourse)
        let apiCandidate: AskAICourseCandidate?

        if hasResolvedIdentity(lookup) {
            if let canonicalCourse = await enrichmentService.resolveCanonicalCourse(
                for: webCourse,
                preferredQueries: orderedFallbackQueries(from: lookup),
                scanContext: scanContext
            ) {
                apiCandidate = AskAICourseCandidate(
                    course: canonicalCourse,
                    requiresReview: false,
                    isCanonicalMatch: true,
                    sources: [.golfCourseAPI]
                )
            } else {
                apiCandidate = nil
            }
        } else {
            apiCandidate = nil
        }

        let candidates = mergedCandidates(webCandidate: webCandidate, apiCandidate: apiCandidate)
        if candidates.isPopulated {
            return AskAICourseLookupResult(
                assistantMessage: candidateMessage(for: candidates),
                candidates: candidates,
                source: lookupSource(for: candidates)
            )
        }

        return AskAICourseLookupResult(
            assistantMessage: followUpMessage(for: lookup),
            candidates: [],
            source: .noMatch
        )
    }

    private func confirmedWebCandidate(
        from lookup: AskAICourseLookupDTO,
        course: Course
    ) -> AskAICourseCandidate? {
        guard lookup.confidence == .high, lookup.hasRealScorecard else { return nil }
        return AskAICourseCandidate(
            course: course,
            requiresReview: false,
            isCanonicalMatch: false,
            sources: [.internet]
        )
    }

    private func mergedCandidates(
        webCandidate: AskAICourseCandidate?,
        apiCandidate: AskAICourseCandidate?
    ) -> [AskAICourseCandidate] {
        guard let webCandidate else {
            return apiCandidate.map { [$0] } ?? []
        }
        guard let apiCandidate else {
            return [webCandidate]
        }

        if coursesReferToSameCourse(webCandidate.course, apiCandidate.course) {
            return [
                AskAICourseCandidate(
                    course: apiCandidate.course,
                    requiresReview: false,
                    isCanonicalMatch: true,
                    sources: orderedSources(apiCandidate.sources + webCandidate.sources)
                )
            ]
        }

        return [webCandidate, apiCandidate]
    }

    private func orderedSources(_ sources: [AskAICourseCandidateSource]) -> [AskAICourseCandidateSource] {
        AskAICourseCandidateSource.allCases.filter { sources.contains($0) }
    }

    private func coursesReferToSameCourse(_ lhs: Course, _ rhs: Course) -> Bool {
        if let lhsID = lhs.golfCourseApiID,
           let rhsID = rhs.golfCourseApiID,
           lhsID == rhsID {
            return true
        }

        let lhsClues = identityClues(for: lhs)
        let rhsClues = identityClues(for: rhs)
        guard lhsClues.isPopulated, rhsClues.isPopulated else { return false }

        let lhsCourseName = CourseNameNormalizer.normalize(lhs.courseName)
        let rhsCourseName = CourseNameNormalizer.normalize(rhs.courseName)
        if lhsCourseName.isPopulated,
           rhsCourseName.isPopulated,
           lhsCourseName != rhsCourseName,
           !lhsCourseName.contains(rhsCourseName),
           !rhsCourseName.contains(lhsCourseName) {
            return false
        }

        let hasStrongNameMatch = lhsClues.contains { lhsClue in
            rhsClues.contains { rhsClue in
                lhsClue == rhsClue
                    || (min(lhsClue.count, rhsClue.count) >= 6 && (lhsClue.contains(rhsClue) || rhsClue.contains(lhsClue)))
            }
        }
        guard hasStrongNameMatch else { return false }

        let lhsCity = lhs.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhsCity = rhs.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lhsState = lhs.location?.state?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhsState = rhs.location?.state?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if lhsCity?.isPopulated == true,
           rhsCity?.isPopulated == true,
           lhsCity != rhsCity {
            return false
        }
        if lhsState?.isPopulated == true,
           rhsState?.isPopulated == true,
           lhsState != rhsState {
            return false
        }

        return true
    }

    private func identityClues(for course: Course) -> [String] {
        var clues: [String] = []
        for value in [course.courseName, course.clubName] {
            let normalized = CourseNameNormalizer.normalize(value)
            if normalized.isPopulated, !clues.contains(normalized) {
                clues.append(normalized)
            }
        }
        return clues
    }

    private func lookupSource(for candidates: [AskAICourseCandidate]) -> AskAICourseLookupSource {
        let sourceSet = Set(candidates.flatMap(\.sources))
        if candidates.count > 1 {
            return .multiple
        }
        if sourceSet == Set([.internet, .golfCourseAPI]) {
            return .webAndAPI
        }
        if sourceSet == Set([.internet]) {
            return .webScorecard
        }
        return .apiFallback
    }

    private func draftCourse(from lookup: AskAICourseLookupDTO) -> Course {
        var draft = CourseScorecardDTOMapper.mapToCourse(
            lookup.mergedScorecard,
            origin: .manual,
            defaultTeeIfEmpty: false
        )

        let websiteURL = normalizedWebsiteURL(lookup.officialWebsiteURL)
        if websiteURL?.isPopulated == true {
            draft = Course(
                id: draft.id,
                golfCourseApiID: draft.golfCourseApiID,
                origin: .manual,
                clubName: draft.clubName,
                courseName: draft.courseName,
                location: draft.location,
                venueDetails: CourseVenueDetails(
                    websiteURL: websiteURL,
                    phoneNumber: draft.venueDetails?.phoneNumber
                ),
                locationGeohash: draft.locationGeohash,
                tees: draft.tees,
                createdAt: draft.createdAt,
                lastUpdatedAt: draft.lastUpdatedAt
            )
        }

        return draft
    }

    private func lookupProvider(for model: AskAITextModel) -> LLMProviderProtocol {
        switch model.config.provider {
        case .openAI:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        }
    }

    private func normalizedWebsiteURL(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isPopulated else {
            return nil
        }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }
        return "https://\(raw)"
    }

    private func hasResolvedIdentity(_ lookup: AskAICourseLookupDTO) -> Bool {
        lookup.courseName.isPopulated || lookup.clubName.isPopulated
    }

    private func orderedFallbackQueries(from lookup: AskAICourseLookupDTO) -> [String] {
        var queries: [String] = []

        func append(_ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isPopulated else {
                return
            }
            if !queries.contains(value) {
                queries.append(value)
            }
        }

        (lookup.apiSearchStrings ?? []).forEach(append)
        append(lookup.courseName)
        append(lookup.clubName)

        if let clubName = lookup.clubName?.trimmingCharacters(in: .whitespacesAndNewlines),
           let courseName = lookup.courseName?.trimmingCharacters(in: .whitespacesAndNewlines),
           clubName.isPopulated,
           courseName.isPopulated,
           clubName != courseName {
            append("\(clubName) \(courseName)")
        }

        return queries
    }

    private func callProvider(
        _ provider: LLMProviderProtocol,
        messages: [LLMMessage],
        model: String,
        scanContext: ScorecardScanContext
    ) async throws -> AskAICourseLookupDTO {
        if let anthropic = provider as? AnthropicProvider {
            return try await anthropic.extractCourseFromConversation(
                messages: messages,
                model: model,
                scanContext: scanContext
            )
        }
        if let openai = provider as? OpenAIProvider {
            return try await openai.extractCourseFromConversation(
                messages: messages,
                model: model,
                scanContext: scanContext
            )
        }

        do {
            let content = try await provider.complete(
                messages: messages,
                model: model,
                maxTokens: 4_096
            )
            return try AskAICourseLookupLLMDecoding.decode(from: content)
        } catch let error as AskAICourseLookupLLMDecodingError {
            throw CourseTextLookupError.decodingFailed(String(describing: error))
        } catch let error as DecodingError {
            throw CourseTextLookupError.decodingFailed(String(describing: error))
        } catch {
            throw error
        }
    }

    private func buildMessages(
        from transcript: [AskAICourseChatMessage],
        context: AskAICourseLookupContext
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = [
            LLMMessage(
                role: "system",
                content: [.text(CourseTextLookupPrompt.systemPrompt(context: context))]
            )
        ]

        messages += transcript.map { message in
            LLMMessage(
                role: message.role.rawValue,
                content: [.text(message.text)]
            )
        }

        messages.append(
            LLMMessage(
                role: "user",
                content: [.text(CourseTextLookupPrompt.finalInstruction(context: context))]
            )
        )

        return messages
    }

    private func candidateMessage(for candidates: [AskAICourseCandidate]) -> String {
        if candidates.count == 1, let candidate = candidates.first {
            let name = displayName(for: candidate.course)
            let sourceText = candidate.sources.map(\.label).joined(separator: " + ")
            var parts = ["I found a confirmed \(sourceText) match for \(name)."]

            if let summary = courseSummary(for: candidate.course) {
                parts.append(summary)
            }

            return parts.joined(separator: " ")
        }

        return "I found \(candidates.count) possible confirmed course matches. Pick the one that looks right, or send another detail and I’ll narrow it down."
    }

    private func followUpMessage(for lookup: AskAICourseLookupDTO) -> String {
        let name = [lookup.clubName, lookup.courseName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(\.isPopulated)
            .joined(separator: " ")

        if name.isPopulated {
            return "I found hints for \(name), but neither the public web result nor Golf Course API confirmed a usable scorecard. Can you send the city/state, the exact course routing, or a more specific scorecard URL?"
        }

        return "I need a bit more detail to pin it down. Try the course name, club name, city/state, resort or trail, or a more specific scorecard URL."
    }

    private func displayName(for course: Course) -> String {
        course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
    }

    private func courseSummary(for course: Course) -> String? {
        let tee = preferredSummaryTee(for: course)
        var parts: [String] = []

        if let location = course.location,
           let city = location.city,
           let state = location.state,
           city.isPopulated,
           state.isPopulated {
            parts.append("\(city), \(state).")
        }

        if let tee {
            let segment = course.defaultSegment
            parts.append("\(tee.totalHoles) holes, par \(tee.par(for: segment)), \(tee.yardage(for: segment)) yards from the \(tee.name) tees.")
        } else if course.defaultSegment.holeCount > 0 {
            parts.append("\(course.defaultSegment.holeCount) holes.")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func preferredSummaryTee(for course: Course) -> Tee? {
        if let male = course.tees.male.first {
            return male
        }
        if let other = course.tees.other.first {
            return other
        }
        return course.tees.first
    }
}
