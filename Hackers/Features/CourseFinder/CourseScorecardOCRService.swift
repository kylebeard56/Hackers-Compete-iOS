//
//  CourseScorecardOCRService.swift
//  Hackers
//
//  Vision API client for OCR scorecard scanning. Uses injectable LLM provider (OpenAI/Anthropic).
//

import CoreLocation
import Foundation
import MapKit
import UIKit

enum CourseScorecardOCRError: Error {
    case apiKeyMissing
    case invalidResponse
    case decodingFailed(String)
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
}

struct ScorecardScanApproximateLocation: Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var promptDescription: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct ScorecardScanContext: Equatable {
    var notes: String?
    var isLocationAssistEnabled: Bool
    var approximateLocation: ScorecardScanApproximateLocation?

    init(
        notes: String? = nil,
        isLocationAssistEnabled: Bool = false,
        approximateLocation: ScorecardScanApproximateLocation? = nil
    ) {
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isLocationAssistEnabled = isLocationAssistEnabled
        self.approximateLocation = approximateLocation
    }
}

@MainActor
protocol CourseScorecardSearchProviding {
    func searchCourses(query: String) async throws -> [GolfCourseAPIModel]
}

@MainActor
protocol CourseScorecardVenueLookupProviding {
    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails?
}

@MainActor
private struct LiveCourseScorecardSearchProvider: CourseScorecardSearchProviding {
    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        try await GolfCourseAPI.shared.searchCourses(with: query)
    }
}

@MainActor
private struct MapKitCourseVenueLookupProvider: CourseScorecardVenueLookupProviding {
    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails? {
        let regionCenter = approximateLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: course.location.latitude, longitude: course.location.longitude)
        guard CLLocationCoordinate2DIsValid(regionCenter) else {
            return CourseVenueDetails(
                websiteURL: normalizedWebsiteURL(course.websiteURL),
                phoneNumber: normalizedPhoneNumber(course.phoneNumber)
            )
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [course.clubName, course.courseName]
            .filter(\.isPopulated)
            .joined(separator: " ")
        request.region = MKCoordinateRegion(
            center: regionCenter,
            latitudinalMeters: 60_000,
            longitudinalMeters: 60_000
        )

        let response = try? await MKLocalSearch(request: request).start()
        let fallbackLocation = approximateLocation?.clLocation
            ?? CLLocation(latitude: course.location.latitude, longitude: course.location.longitude)

        let mapItem = response?.mapItems
            .filter { item in
                guard let name = item.name else { return false }
                return nameSeemsToMatch(name, course: course)
            }
            .sorted { lhs, rhs in
                let lhsDistance = lhs.placemark.location?.distance(from: fallbackLocation) ?? .greatestFiniteMagnitude
                let rhsDistance = rhs.placemark.location?.distance(from: fallbackLocation) ?? .greatestFiniteMagnitude
                return lhsDistance < rhsDistance
            }
            .first

        return CourseVenueDetails(
            websiteURL: normalizedWebsiteURL(mapItem?.url?.absoluteString ?? course.websiteURL),
            phoneNumber: normalizedPhoneNumber(mapItem?.phoneNumber ?? course.phoneNumber)
        )
    }

    private func nameSeemsToMatch(_ name: String, course: GolfCourseAPIModel) -> Bool {
        let normalizedName = CourseNameNormalizer.normalize(name)
        let courseName = CourseNameNormalizer.normalize(course.courseName)
        let clubName = CourseNameNormalizer.normalize(course.clubName)

        guard normalizedName.isPopulated else { return false }
        return normalizedName == courseName
            || normalizedName == clubName
            || normalizedName.contains(courseName)
            || normalizedName.contains(clubName)
            || courseName.contains(normalizedName)
            || clubName.contains(normalizedName)
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

    private func normalizedPhoneNumber(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isPopulated else {
            return nil
        }
        let digits = raw.filter(\.isNumber)
        return digits.count == 10 ? digits.toFullPhoneNumber() : raw
    }
}

@MainActor
final class CourseScorecardEnrichmentService: Loggable {
    static let shared = CourseScorecardEnrichmentService()

    private let searchProvider: CourseScorecardSearchProviding
    private let venueLookupProvider: CourseScorecardVenueLookupProviding

    init(
        searchProvider: CourseScorecardSearchProviding? = nil,
        venueLookupProvider: CourseScorecardVenueLookupProviding? = nil
    ) {
        self.searchProvider = searchProvider ?? LiveCourseScorecardSearchProvider()
        self.venueLookupProvider = venueLookupProvider ?? MapKitCourseVenueLookupProvider()
    }

    func enrich(course ocrCourse: Course, scanContext: ScorecardScanContext = .init()) async -> Course {
        let queries = searchQueries(for: ocrCourse)
        guard queries.isPopulated else { return ocrCourse }

        var candidatesByID: [Int: GolfCourseAPIModel] = [:]
        for query in queries {
            do {
                let candidates = try await searchProvider.searchCourses(query: query)
                for candidate in candidates {
                    candidatesByID[candidate.id] = candidate
                }
            } catch {
                addBreadcrumb(level: .warning, message: "Scorecard enrichment search failed for query \(query)", error: error)
            }
        }

        let candidates = Array(candidatesByID.values)
        guard let confirmed = confirmedMatch(
            for: ocrCourse,
            candidates: candidates,
            approximateLocation: scanContext.isLocationAssistEnabled ? scanContext.approximateLocation : nil
        ) else {
            return ocrCourse
        }

        let venueDetails = await venueLookupProvider.venueDetails(
            for: confirmed.model,
            approximateLocation: scanContext.isLocationAssistEnabled ? scanContext.approximateLocation : nil
        )

        return mergedCourse(
            ocrCourse: ocrCourse,
            matchedCourse: confirmed.model,
            venueDetails: venueDetails
        )
    }

    func resolveCanonicalCourse(
        for draftCourse: Course,
        scanContext: ScorecardScanContext = .init()
    ) async -> Course? {
        let queries = searchQueries(for: draftCourse)
        guard queries.isPopulated else { return nil }

        var candidatesByID: [Int: GolfCourseAPIModel] = [:]
        for query in queries {
            do {
                let candidates = try await searchProvider.searchCourses(query: query)
                for candidate in candidates {
                    candidatesByID[candidate.id] = candidate
                }
            } catch {
                addBreadcrumb(level: .warning, message: "Canonical course search failed for query \(query)", error: error)
            }
        }

        let candidates = Array(candidatesByID.values)
        guard let confirmed = confirmedMatch(
            for: draftCourse,
            candidates: candidates,
            approximateLocation: scanContext.isLocationAssistEnabled ? scanContext.approximateLocation : nil
        ) else {
            return nil
        }

        let venueDetails = await venueLookupProvider.venueDetails(
            for: confirmed.model,
            approximateLocation: scanContext.isLocationAssistEnabled ? scanContext.approximateLocation : nil
        )

        return canonicalCourse(
            for: confirmed.model,
            venueDetails: venueDetails
        )
    }

    private func searchQueries(for course: Course) -> [String] {
        var queries: [String] = []

        func append(_ query: String?) {
            guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), query.isPopulated else {
                return
            }
            if !queries.contains(query) {
                queries.append(query)
            }
        }

        append(course.courseName)
        append(course.clubName)

        if course.clubName.isPopulated,
           course.courseName.isPopulated,
           course.clubName != course.courseName {
            append("\(course.clubName) \(course.courseName)")
        }

        return queries
    }

    private func confirmedMatch(
        for ocrCourse: Course,
        candidates: [GolfCourseAPIModel],
        approximateLocation: ScorecardScanApproximateLocation?
    ) -> MatchCandidate? {
        let evaluated = candidates
            .map { evaluate(candidate: $0, against: ocrCourse, approximateLocation: approximateLocation) }
            .filter(\.isPlausible)
            .sorted { lhs, rhs in
                if lhs.totalScore != rhs.totalScore {
                    return lhs.totalScore > rhs.totalScore
                }
                if lhs.nameScore != rhs.nameScore {
                    return lhs.nameScore > rhs.nameScore
                }
                let lhsDistance = lhs.distance ?? .greatestFiniteMagnitude
                let rhsDistance = rhs.distance ?? .greatestFiniteMagnitude
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.model.id > rhs.model.id
            }

        guard let top = evaluated.first else { return nil }
        let second = evaluated.dropFirst().first

        if second == nil, top.nameScore >= 4 {
            return top
        }

        if let second, top.totalScore >= second.totalScore + 2, top.nameScore >= 4 {
            return top
        }

        guard let approximateLocation else { return nil }
        let strongestNameMatches = evaluated.filter { $0.nameScore == top.nameScore && $0.totalScore == top.totalScore && $0.nameScore >= 4 }
        guard strongestNameMatches.count > 1 else { return nil }

        let nearby = strongestNameMatches
            .filter { ($0.distance ?? .greatestFiniteMagnitude) <= 80_467 }
            .sorted {
                ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude)
            }

        guard let bestByDistance = nearby.first else { return nil }
        let nextDistance = nearby.dropFirst().first?.distance ?? .greatestFiniteMagnitude
        let bestDistance = bestByDistance.distance ?? .greatestFiniteMagnitude

        guard bestDistance.isFinite else { return nil }
        guard bestDistance + 16_093 <= nextDistance || !nextDistance.isFinite else { return nil }

        addBreadcrumb(
            message: "Resolved scorecard course tie using approximate location near \(approximateLocation.promptDescription)"
        )
        return bestByDistance
    }

    private func evaluate(
        candidate: GolfCourseAPIModel,
        against ocrCourse: Course,
        approximateLocation: ScorecardScanApproximateLocation?
    ) -> MatchCandidate {
        let ocrIdentityClues = identityClues(for: ocrCourse)
        let candidateClues = identityClues(for: candidate)

        let nameScore = candidateClues.reduce(into: 0) { result, candidateClue in
            let bestForCandidate = ocrIdentityClues.map { nameMatchScore(clue: $0, candidate: candidateClue) }.max() ?? 0
            result = max(result, bestForCandidate)
        }

        var supportScore = 0
        if let ocrCity = ocrCourse.location?.city?.lowercased(),
           ocrCity.isPopulated,
           ocrCity == candidate.location.city?.lowercased() {
            supportScore += 1
        }
        if let ocrState = ocrCourse.location?.state?.lowercased(),
           ocrState.isPopulated,
           ocrState == candidate.location.state?.lowercased() {
            supportScore += 1
        }

        let ocrTeeNames = Set(ocrCourse.tees.map { CourseNameNormalizer.normalize($0.name) }.filter(\.isPopulated))
        let candidateTeeNames = Set(candidate.tees.filteredFemale.map(\.teeName) + candidate.tees.filteredMale.map(\.teeName))
            .map { CourseNameNormalizer.normalize($0) }
            .filter(\.isPopulated)
        if !ocrTeeNames.isEmpty, !candidateTeeNames.isEmpty, !ocrTeeNames.isDisjoint(with: candidateTeeNames) {
            supportScore += 1
        }

        let distance: CLLocationDistance?
        if let approximateLocation {
            let origin = approximateLocation.clLocation
            let destination = CLLocation(latitude: candidate.location.latitude, longitude: candidate.location.longitude)
            distance = origin.distance(from: destination)
        } else {
            distance = nil
        }

        return MatchCandidate(
            model: candidate,
            nameScore: nameScore,
            supportScore: supportScore,
            distance: distance
        )
    }

    private func identityClues(for course: Course) -> [String] {
        var clues: [String] = []
        let raw = [course.courseName, course.clubName]
        for value in raw {
            let normalized = CourseNameNormalizer.normalize(value)
            if normalized.isPopulated, !clues.contains(normalized) {
                clues.append(normalized)
            }
        }
        return clues
    }

    private func identityClues(for candidate: GolfCourseAPIModel) -> [String] {
        var clues: [String] = []
        let raw = [candidate.courseName, candidate.clubName]
        for value in raw {
            let normalized = CourseNameNormalizer.normalize(value)
            if normalized.isPopulated, !clues.contains(normalized) {
                clues.append(normalized)
            }
        }
        return clues
    }

    private func nameMatchScore(clue: String, candidate: String) -> Int {
        guard clue.isPopulated, candidate.isPopulated else { return 0 }
        if clue == candidate {
            return 6
        }
        if clue.contains(candidate) || candidate.contains(clue) {
            return min(clue.count, candidate.count) >= 6 ? 4 : 2
        }

        let clueTokens = Set(clue.split(separator: " ").map(String.init))
        let candidateTokens = Set(candidate.split(separator: " ").map(String.init))
        let overlap = clueTokens.intersection(candidateTokens).count
        guard overlap > 0 else { return 0 }

        if overlap >= min(clueTokens.count, candidateTokens.count) {
            return 4
        }
        if overlap >= 2 {
            return 3
        }
        return 2
    }

    private func mergedCourse(
        ocrCourse: Course,
        matchedCourse: GolfCourseAPIModel,
        venueDetails: CourseVenueDetails?
    ) -> Course {
        let canonicalCourse = Course(from: matchedCourse, with: ocrCourse.id, useStableTeeIDs: true)
        let mergedLocation = canonicalCourse.location ?? ocrCourse.location
        let mergedVenueDetails = CourseVenueDetails(
            websiteURL: venueDetails?.websiteURL ?? canonicalCourse.venueDetails?.websiteURL ?? ocrCourse.venueDetails?.websiteURL,
            phoneNumber: venueDetails?.phoneNumber ?? canonicalCourse.venueDetails?.phoneNumber ?? ocrCourse.venueDetails?.phoneNumber
        )

        return Course(
            id: ocrCourse.id,
            golfCourseApiID: matchedCourse.id,
            origin: .ocr,
            clubName: ocrCourse.clubName.isPopulated ? ocrCourse.clubName : canonicalCourse.clubName,
            courseName: ocrCourse.courseName.isPopulated ? ocrCourse.courseName : canonicalCourse.courseName,
            location: mergedLocation,
            venueDetails: (mergedVenueDetails.websiteURL?.isPopulated == true || mergedVenueDetails.phoneNumber?.isPopulated == true)
                ? mergedVenueDetails
                : nil,
            locationGeohash: mergedLocation?.geohash,
            tees: ocrCourse.tees,
            createdAt: ocrCourse.createdAt,
            lastUpdatedAt: .init()
        )
    }

    private func canonicalCourse(
        for matchedCourse: GolfCourseAPIModel,
        venueDetails: CourseVenueDetails?
    ) -> Course {
        let canonicalCourse = Course(from: matchedCourse, with: String(matchedCourse.id), useStableTeeIDs: true)
        let mergedVenueDetails = CourseVenueDetails(
            websiteURL: venueDetails?.websiteURL ?? canonicalCourse.venueDetails?.websiteURL,
            phoneNumber: venueDetails?.phoneNumber ?? canonicalCourse.venueDetails?.phoneNumber
        )

        return Course(
            id: canonicalCourse.id,
            golfCourseApiID: canonicalCourse.golfCourseApiID,
            origin: .golfCourseAPI,
            clubName: canonicalCourse.clubName,
            courseName: canonicalCourse.courseName,
            location: canonicalCourse.location,
            venueDetails: (mergedVenueDetails.websiteURL?.isPopulated == true || mergedVenueDetails.phoneNumber?.isPopulated == true)
                ? mergedVenueDetails
                : nil,
            locationGeohash: canonicalCourse.locationGeohash,
            tees: canonicalCourse.tees,
            createdAt: canonicalCourse.createdAt,
            lastUpdatedAt: .init()
        )
    }

    private struct MatchCandidate {
        let model: GolfCourseAPIModel
        let nameScore: Int
        let supportScore: Int
        let distance: CLLocationDistance?

        var totalScore: Int {
            nameScore + supportScore
        }

        var isPlausible: Bool {
            nameScore >= 4 || totalScore >= 5
        }
    }
}

@MainActor
final class CourseScorecardOCRService: Loggable {
    static let shared = CourseScorecardOCRService()

    /// When set (e.g. unit tests), used instead of resolving a provider from `vision.config`.
    private let injectedProvider: LLMProviderProtocol?

    init(provider: LLMProviderProtocol? = nil) {
        self.injectedProvider = provider
    }

    /// Extracts course data from a scorecard image using Vision API.
    /// Prefers structured output via tools (OpenAI/Anthropic); falls back to text + JSON parsing.
    /// Returns a Course with origin `.ocr`; caller should save to Firebase (Option C).
    func extractCourse(
        from image: UIImage,
        scanContext: ScorecardScanContext = .init(),
        vision: ScorecardScanVisionModel = .defaultSelection
    ) async throws -> Course {
        let config = vision.config
        guard let provider = injectedProvider ?? LLMProviderRegistry.provider(for: config) else {
            addBreadcrumb(level: .error, message: "LLM provider not available; check AI config and API keys")
            throw CourseScorecardOCRError.apiKeyMissing
        }

        guard let base64 = image.base64 else {
            addBreadcrumb(level: .error, message: "Failed to compress JPEG data for scorecard scanning")
            throw CourseScorecardOCRError.invalidResponse
        }

        /// Reasoning models (e.g. gpt-5-nano) use tokens for thinking; need headroom for tool output.
        let maxTokens = 16384

        let dto: CourseScorecardDTO
        do {
            if let anthropic = provider as? AnthropicProvider {
                dto = try await anthropic.extractScorecardWithTools(
                    imageBase64: base64,
                    model: config.model,
                    maxTokens: maxTokens,
                    scanContext: scanContext
                )
            } else if let openai = provider as? OpenAIProvider {
                dto = try await openai.extractScorecardWithTools(
                    imageBase64: base64,
                    model: config.model,
                    maxTokens: maxTokens,
                    scanContext: scanContext
                )
            } else {
                let messages = buildOCRMessages(imageBase64: base64, scanContext: scanContext)
                let rawResponse = try await provider.complete(messages: messages, model: config.model, maxTokens: maxTokens)
                dto = try parseDTO(from: rawResponse)
            }
        } catch OpenAIProviderError.apiKeyMissing, AnthropicProviderError.apiKeyMissing {
            throw CourseScorecardOCRError.apiKeyMissing
        } catch OpenAIProviderError.requestTooLarge, AnthropicProviderError.requestTooLarge {
            throw CourseScorecardOCRError.requestTooLarge
        } catch OpenAIProviderError.rateLimitExceeded, AnthropicProviderError.rateLimitExceeded {
            throw CourseScorecardOCRError.rateLimitExceeded
        } catch OpenAIProviderError.overloaded, AnthropicProviderError.overloaded {
            throw CourseScorecardOCRError.overloaded
        } catch {
            throw error
        }

        return mapToCourse(dto)
    }

    func extractCourse(
        from image: UIImage,
        userNotes: String? = nil,
        vision: ScorecardScanVisionModel = .defaultSelection
    ) async throws -> Course {
        try await extractCourse(
            from: image,
            scanContext: .init(notes: userNotes),
            vision: vision
        )
    }

    private func buildOCRMessages(imageBase64: String, scanContext: ScorecardScanContext) -> [LLMMessage] {
        let userMessage = LLMMessage(
            role: "user",
            content: [
                .image(base64: imageBase64, mediaType: "image/jpeg"),
                .text(CourseScorecardOCRPrompt.userPrompt(scanContext: scanContext))
            ]
        )

        return [
            LLMMessage(
                role: "system",
                content: [.text(CourseScorecardOCRPrompt.systemPrompt(includeJSONSchema: true, scanContext: scanContext))]
            ),
            userMessage
        ]
    }

    private func parseDTO(from content: String) throws -> CourseScorecardDTO {
        do {
            return try CourseScorecardLLMDecoding.decode(from: content)
        } catch {
            let truncated = String(content.prefix(500))
            throw CourseScorecardOCRError.decodingFailed("\(error.localizedDescription). Raw (truncated): \(truncated)")
        }
    }

    private func mapToCourse(_ dto: CourseScorecardDTO) -> Course {
        let clubName = dto.clubName ?? dto.courseName ?? ""
        let courseName = dto.courseName ?? dto.clubName ?? clubName

        let location: CourseLocation?
        if let loc = dto.location, (loc.latitude != nil || loc.longitude != nil) {
            let lat = loc.latitude ?? 0
            let lon = loc.longitude ?? 0
            location = CourseLocation(
                address: loc.address,
                city: loc.city,
                state: loc.state,
                country: loc.country,
                latitude: lat,
                longitude: lon
            )
        } else {
            location = nil
        }

        let tees: [Tee] = (dto.tees ?? []).compactMap { mapTee($0) }

        return Course(
            golfCourseApiID: nil,
            origin: .ocr,
            clubName: clubName,
            courseName: courseName,
            location: location,
            locationGeohash: location?.geohash,
            tees: tees.isEmpty ? [defaultTee()] : tees
        )
    }

    private func mapTee(_ dto: CourseScorecardTeeDTO) -> Tee? {
        let holesDTO = dto.holes ?? []
        guard !holesDTO.isEmpty else { return nil }

        let holes: [Hole] = holesDTO.enumerated().map { index, h in
            Hole(
                number: h.number ?? (index + 1),
                par: h.par ?? 4,
                yardage: h.yardage ?? 0,
                handicap: h.handicap
            )
        }

        let gender = mapGender(dto.gender)
        let rating = dto.courseRating ?? dto.frontCourseRating ?? dto.backCourseRating ?? 72.0
        let slope = dto.slopeRating ?? dto.frontSlopeRating ?? dto.backSlopeRating ?? 113

        return Tee(
            name: dto.name ?? "Tee \(holes.count)",
            gender: gender,
            totalHoles: holes.count,
            holes: holes,
            ratingFull: rating,
            slopeFull: slope,
            ratingFront: dto.frontCourseRating,
            slopeFront: dto.frontSlopeRating,
            ratingBack: dto.backCourseRating,
            slopeBack: dto.backSlopeRating
        )
    }

    private func mapGender(_ value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "male", "men", "man", "mens":
            return Gender.male.rawValue
        case "female", "women", "woman", "womens", "ladies", "lady":
            return Gender.female.rawValue
        default:
            return Gender.unknown.rawValue
        }
    }

    private func defaultTee() -> Tee {
        let holes = (1...18).map { n in
            Hole(number: n, par: n % 4 == 0 ? 5 : (n % 4 == 3 ? 3 : 4), yardage: 350, handicap: nil)
        }
        return Tee(
            name: "Default",
            gender: Gender.unknown.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
    }
}
