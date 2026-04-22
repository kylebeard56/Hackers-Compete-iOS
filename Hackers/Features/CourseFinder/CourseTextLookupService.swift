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
}

struct AskAICourseChatMessage: Identifiable {
    enum Role: String {
        case user
        case assistant
    }

    let id: String
    let role: Role
    let text: String
    let candidate: AskAICourseCandidate?

    init(
        id: String = HackersID.string(),
        role: Role,
        text: String,
        candidate: AskAICourseCandidate? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.candidate = candidate
    }

    var isUser: Bool {
        role == .user
    }
}

enum AskAICourseLookupSource: String {
    case webScorecard = "web_scorecard"
    case apiFallback = "api_fallback"
    case draftOnly = "draft_only"
}

struct AskAICourseLookupResult {
    let assistantMessage: String
    let candidate: AskAICourseCandidate?
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
        - Always return ordered `apiSearchStrings` when confidence is not high or when the scorecard is absent.
        - Put the most official resolved course or club name first, followed by other high-quality search variants that may help a strict API search.
        - If you do return a high-confidence public scorecard, you may leave `apiSearchStrings` empty.

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
        var instruction = "Use the conversation above to resolve the course. Search the web for the official/public scorecard first, then call extract_course_lookup exactly once with the resolved identity, confidence, optional scorecard, and ordered API backup search strings."

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

        let draft = draftCourse(from: lookup)

        if lookup.confidence == .high,
           lookup.hasRealScorecard {
            return AskAICourseLookupResult(
                assistantMessage: webScorecardMessage(for: draft),
                candidate: AskAICourseCandidate(
                    course: draft,
                    requiresReview: false,
                    isCanonicalMatch: false
                ),
                source: .webScorecard
            )
        }

        if hasResolvedIdentity(lookup) {
            if let canonicalCourse = await enrichmentService.resolveCanonicalCourse(
                for: draft,
                preferredQueries: orderedFallbackQueries(from: lookup),
                scanContext: scanContext
            ) {
                return AskAICourseLookupResult(
                    assistantMessage: apiFallbackMessage(for: canonicalCourse),
                    candidate: AskAICourseCandidate(
                        course: canonicalCourse,
                        requiresReview: false,
                        isCanonicalMatch: true
                    ),
                    source: .apiFallback
                )
            }

            return AskAICourseLookupResult(
                assistantMessage: draftCourseMessage(for: draft),
                candidate: AskAICourseCandidate(
                    course: draft,
                    requiresReview: true,
                    isCanonicalMatch: false
                ),
                source: .draftOnly
            )
        }

        return AskAICourseLookupResult(
            assistantMessage: "I need a bit more detail to pin it down. Try the course name, club name, city/state, resort or trail, or another identifying clue.",
            candidate: nil,
            source: .draftOnly
        )
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

    private func webScorecardMessage(for course: Course) -> String {
        let name = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
        let tee = preferredSummaryTee(for: course)
        var parts = ["I found an official or credible public scorecard for \(name)."]

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
        }

        return parts.joined(separator: " ")
    }

    private func apiFallbackMessage(for course: Course) -> String {
        let name = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
        let tee = preferredSummaryTee(for: course)
        var parts = ["I resolved the course identity and found a fallback Golf Course API match for \(name)."]

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

        return parts.joined(separator: " ")
    }

    private func draftCourseMessage(for course: Course) -> String {
        let name = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
        if name.isPopulated {
            return "I resolved the course identity for \(name), but I couldn't verify a high-confidence public scorecard and the fallback API search did not confirm a match. Review this draft before continuing, or share another detail and I'll try again."
        }

        return "I found a few hints, but not enough to build a reliable course yet. Try adding the course name, city/state, resort or trail, or another identifying detail."
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
