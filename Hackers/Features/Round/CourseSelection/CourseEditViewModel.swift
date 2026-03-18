//
//  CourseEditViewModel.swift
//  Hackers
//
//  Created for Course OCR and Custom Course plan.
//

import CoreLocation
import MapKit
import SwiftUI

struct CourseAddressSuggestion: Identifiable, Equatable {
    let title: String
    let subtitle: String

    init(title: String, subtitle: String = "") {
        self.title = title
        self.subtitle = subtitle
    }

    var id: String { [title, subtitle].joined(separator: "|") }

    var displayText: String {
        [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func == (lhs: CourseAddressSuggestion, rhs: CourseAddressSuggestion) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }
}

struct ResolvedCourseAddress: Equatable {
    let address: String
    let city: String
    let state: String
    let country: String
    let latitude: Double
    let longitude: Double

    var query: String {
        let fullLine = [address, city, state, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return AddressFormatter.trimmedUSAddress(fullLine)
    }
}

protocol CourseAddressSearchServicing: AnyObject {
    func suggestions(for query: String) async throws -> [CourseAddressSuggestion]
    func resolveSuggestion(_ suggestion: CourseAddressSuggestion) async throws -> ResolvedCourseAddress
    func reverseGeocode(_ location: CLLocation) async throws -> ResolvedCourseAddress
}

@MainActor
final class CourseAddressSearchService: NSObject, CourseAddressSearchServicing {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[CourseAddressSuggestion], Error>?
    private var completionLookup: [String: MKLocalSearchCompletion] = [:]

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func suggestions(for query: String) async throws -> [CourseAddressSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.cancelPendingSuggestions()
                self.continuation = continuation
                self.completer.queryFragment = trimmed
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelPendingSuggestions()
            }
        }
    }

    func resolveSuggestion(_ suggestion: CourseAddressSuggestion) async throws -> ResolvedCourseAddress {
        let request: MKLocalSearch.Request
        if let completion = completionLookup[suggestion.id] {
            request = MKLocalSearch.Request(completion: completion)
        } else {
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = suggestion.displayText
        }
        request.resultTypes = .address

        let response = try await MKLocalSearch(request: request).start()
        guard let placemark = response.mapItems.first?.placemark else {
            throw NSError(domain: "CourseAddressSearchService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No matching address was found."
            ])
        }
        return Self.makeResolvedAddress(from: placemark)
    }

    func reverseGeocode(_ location: CLLocation) async throws -> ResolvedCourseAddress {
        let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
        guard let placemark else {
            throw NSError(domain: "CourseAddressSearchService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't determine an address for your location."
            ])
        }
        return Self.makeResolvedAddress(from: placemark)
    }

    private func cancelPendingSuggestions() {
        continuation?.resume(returning: [])
        continuation = nil
        completionLookup = [:]
    }

    private static func makeResolvedAddress(from placemark: CLPlacemark) -> ResolvedCourseAddress {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let fallbackStreet = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ResolvedCourseAddress(
            address: street.isEmpty ? fallbackStreet : street,
            city: placemark.locality ?? placemark.subLocality ?? "",
            state: placemark.administrativeArea ?? "",
            country: placemark.country ?? "",
            latitude: placemark.location?.coordinate.latitude ?? 0,
            longitude: placemark.location?.coordinate.longitude ?? 0
        )
    }
}

extension CourseAddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            let suggestions = completer.results.map {
                CourseAddressSuggestion(title: $0.title, subtitle: $0.subtitle)
            }
            completionLookup = [:]
            for (suggestion, result) in zip(suggestions, completer.results) {
                completionLookup[suggestion.id] = result
            }
            continuation?.resume(returning: suggestions)
            continuation = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            completionLookup = [:]
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

/// Hole-centric: each hole has par/handicap shared, and tees with yardage per tee.
struct EditableHoleWithTees: Identifiable {
    var id: String { "\(number)" }
    var number: Int
    var par: Int
    var handicap: Int?
    var tees: [EditableTeeData]
}

/// Per-hole tee data: yardage (required), optional overrides for par/handicap.
struct EditableTeeData: Identifiable {
    var id: String { teeId }
    var teeId: String
    var name: String
    var yardage: Int
    var parOverride: Int?
    var hcpOverride: Int?
}

/// Legacy tee-centric struct for backward compatibility during migration.
struct EditableHole: Identifiable {
    var id: String { "\(number)" }
    var number: Int
    var par: Int
    var yardage: Int
    var handicap: Int?
}

struct EditableTee: Identifiable {
    var id: String
    var name: String
    var gender: String
    var holes: [EditableHole]
    var ratingFull: Double
    var slopeFull: Int
    var ratingFront: Double?
    var slopeFront: Int?
    var ratingBack: Double?
    var slopeBack: Int?

    var totalHoles: Int { holes.count }
    var par: Int { holes.reduce(0) { $0 + $1.par } }
    var yardage: Int { holes.reduce(0) { $0 + $1.yardage } }
}

struct TeeMetadata {
    var gender: String
    var ratingFull: Double
    var slopeFull: Int
    var ratingFront: Double?
    var slopeFront: Int?
    var ratingBack: Double?
    var slopeBack: Int?
}

@MainActor
final class CourseEditViewModel: ObservableObject {
    private let originalCourse: Course
    private let addressSearchService: CourseAddressSearchServicing
    private var teeMetadata: [String: TeeMetadata] = [:]
    private var addressSearchTask: Task<Void, Never>?
    private var resolvedAddressQuery: String?

    let originalOrigin: String

    @Published var courseId: String
    @Published var golfCourseApiID: Int?
    @Published var clubName: String
    @Published var courseName: String
    @Published var address: String
    @Published var city: String
    @Published var state: String
    @Published var country: String
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var addressQuery: String
    @Published var addressSuggestions: [CourseAddressSuggestion] = []
    @Published var isSearchingAddress = false
    @Published var isResolvingAddress = false
    @Published var addressSearchError = ""
    /// Hole-centric: each hole has par, handicap, and tees with yardage.
    @Published var holes: [EditableHoleWithTees]

    init(course: Course, addressSearchService: CourseAddressSearchServicing? = nil) {
        let initialAddressQuery = Self.formattedAddressQuery(
            address: course.location?.address ?? "",
            city: course.location?.city ?? "",
            state: course.location?.state ?? "",
            country: course.location?.country ?? ""
        )

        self.originalCourse = course
        self.addressSearchService = addressSearchService ?? CourseAddressSearchService()
        self.originalOrigin = course.origin
        self.courseId = course.id
        self.golfCourseApiID = course.golfCourseApiID
        self.clubName = course.clubName
        self.courseName = course.courseName
        self.address = course.location?.address ?? ""
        self.city = course.location?.city ?? ""
        self.state = course.location?.state ?? ""
        self.country = course.location?.country ?? ""
        self.latitude = course.location?.latitude ?? 0
        self.longitude = course.location?.longitude ?? 0
        self.addressQuery = initialAddressQuery
        self.resolvedAddressQuery = initialAddressQuery.isEmpty ? nil : initialAddressQuery
        self.holes = Self.teeCentricToHoleCentric(course.tees)

        for tee in course.tees {
            teeMetadata[tee.id] = TeeMetadata(
                gender: tee.gender,
                ratingFull: tee.ratingFull,
                slopeFull: tee.slopeFull,
                ratingFront: tee.ratingFront,
                slopeFront: tee.slopeFront,
                ratingBack: tee.ratingBack,
                slopeBack: tee.slopeBack
            )
        }
    }

    deinit {
        addressSearchTask?.cancel()
    }

    var holeCount: Int { holes.count }

    var teeCount: Int { holes.first?.tees.count ?? 0 }

    var formattedAddressLine: String {
        Self.formattedAddressQuery(address: address, city: city, state: state, country: country)
    }

    func updateAddressQuery(_ query: String) {
        addressQuery = query
        addressSearchError = ""

        if query != resolvedAddressQuery {
            clearDerivedLocation(keeping: query)
        }

        scheduleAddressSearch(for: query)
    }

    func clearAddressSuggestions() {
        addressSearchTask?.cancel()
        addressSearchTask = nil
        addressSuggestions = []
        isSearchingAddress = false
    }

    func applySuggestion(_ suggestion: CourseAddressSuggestion) async {
        addressSearchError = ""
        isResolvingAddress = true
        defer { isResolvingAddress = false }

        do {
            let resolved = try await addressSearchService.resolveSuggestion(suggestion)
            applyResolvedAddress(resolved)
        } catch {
            addressSearchError = error.localizedDescription
        }
    }

    func applyCurrentLocation(_ location: CLLocation) async {
        addressSearchError = ""
        isResolvingAddress = true
        defer { isResolvingAddress = false }

        do {
            let resolved = try await addressSearchService.reverseGeocode(location)
            applyResolvedAddress(resolved)
        } catch {
            addressSearchError = error.localizedDescription
        }
    }

    func gender(for teeId: String) -> Gender? {
        guard let rawValue = teeMetadata[teeId]?.gender, !rawValue.isEmpty else { return nil }
        return Gender(rawValue: rawValue)
    }

    func buildCourse() -> Course {
        let hasLocation = latitude != 0 || longitude != 0 || !address.isEmpty || !city.isEmpty || !state.isEmpty
        let loc: CourseLocation? = hasLocation
            ? CourseLocation(
                address: address.isEmpty ? nil : address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? nil : country,
                latitude: latitude,
                longitude: longitude
            )
            : nil

        let builtTees = holeCentricToTeeCentric()
        return Course(
            id: courseId,
            golfCourseApiID: golfCourseApiID,
            origin: .hackers,
            clubName: clubName.isEmpty ? courseName : clubName,
            courseName: courseName.isEmpty ? clubName : courseName,
            location: loc,
            locationGeohash: loc?.geohash,
            tees: builtTees,
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
    }

    /// Returns true if the built course differs from the original (excluding createdAt/lastUpdatedAt).
    func wasEdited() -> Bool {
        let built = buildCourse()
        return !coursesEqualIgnoringTimestamps(built, originalCourse)
    }

    func setHoleCount(_ count: Int) {
        let clamped = min(18, max(9, count))
        if clamped < holes.count {
            holes = Array(holes.prefix(clamped))
            for i in holes.indices {
                holes[i].number = i + 1
            }
        } else if clamped > holes.count {
            let template = holes.first?.tees.map {
                EditableTeeData(
                    teeId: $0.teeId,
                    name: $0.name,
                    yardage: 350,
                    parOverride: nil,
                    hcpOverride: nil
                )
            } ?? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]

            for num in (holes.count + 1)...clamped {
                holes.append(EditableHoleWithTees(number: num, par: 4, handicap: nil, tees: template))
            }
        }
    }

    func addHole() {
        let nextNum = (holes.map(\.number).max() ?? 0) + 1
        let defaultTees: [EditableTeeData] = holes.first.map { hole in
            hole.tees.isEmpty
                ? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
                : hole.tees.map {
                    EditableTeeData(
                        teeId: $0.teeId,
                        name: $0.name,
                        yardage: 350,
                        parOverride: nil,
                        hcpOverride: nil
                    )
                }
        } ?? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
        holes.append(EditableHoleWithTees(number: nextNum, par: 4, handicap: nil, tees: defaultTees))
    }

    func removeHole(at index: Int) {
        guard index >= 0, index < holes.count, holes.count > 9 else { return }
        holes.remove(at: index)
        for i in holes.indices {
            holes[i].number = i + 1
        }
    }

    func addTee() {
        let newId = HackersID.string()
        let teeNumber = max((holes.first?.tees.count ?? 0) + 1, 1)
        let defaultName = "Tee \(teeNumber)"
        teeMetadata[newId] = TeeMetadata(
            gender: Gender.unknown.rawValue,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )

        for holeIndex in holes.indices {
            holes[holeIndex].tees.append(
                EditableTeeData(
                    teeId: newId,
                    name: defaultName,
                    yardage: 350,
                    parOverride: nil,
                    hcpOverride: nil
                )
            )
        }
    }

    func removeTee(holeIndex: Int, teeIndex: Int) {
        guard holeIndex >= 0, holeIndex < holes.count, holes[holeIndex].tees.count > 1 else { return }
        let teeId = holes[holeIndex].tees[teeIndex].teeId
        holes[holeIndex].tees.remove(at: teeIndex)
        for i in holes.indices where i != holeIndex {
            if let idx = holes[i].tees.firstIndex(where: { $0.teeId == teeId }) {
                holes[i].tees.remove(at: idx)
            }
        }
    }

    func setTeeName(teeId: String, name: String) {
        for i in holes.indices {
            if let idx = holes[i].tees.firstIndex(where: { $0.teeId == teeId }) {
                holes[i].tees[idx].name = name
            }
        }
    }

    /// Default tee for display (first tee's yardage per hole).
    var defaultTeeYardage: (Int) -> Int {
        { holeNum in
            self.holes.first(where: { $0.number == holeNum })?.tees.first?.yardage ?? 0
        }
    }

    /// Convert tee-centric Course.tees to hole-centric holes.
    private static func teeCentricToHoleCentric(_ tees: [Tee]) -> [EditableHoleWithTees] {
        guard let firstTee = tees.first, !firstTee.holes.isEmpty else {
            let defaultTeeId = HackersID.string()
            return (1...18).map { num in
                EditableHoleWithTees(
                    number: num,
                    par: 4,
                    handicap: nil,
                    tees: [EditableTeeData(teeId: defaultTeeId, name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
                )
            }
        }

        let holeNumbers = firstTee.holes.map(\.number).sorted()
        return holeNumbers.map { holeNum in
            let firstHole = firstTee.holes.first(where: { $0.number == holeNum })
            let par = firstHole?.par ?? 4
            let handicap = firstHole?.handicap
            let teesData = tees.map { tee in
                let hole = tee.holes.first(where: { $0.number == holeNum })
                return EditableTeeData(
                    teeId: tee.id,
                    name: tee.name,
                    yardage: hole?.yardage ?? 0,
                    parOverride: nil,
                    hcpOverride: nil
                )
            }
            return EditableHoleWithTees(number: holeNum, par: par, handicap: handicap, tees: teesData)
        }
    }

    /// Convert hole-centric to tee-centric Tee array.
    private func holeCentricToTeeCentric() -> [Tee] {
        guard !holes.isEmpty, let firstHole = holes.first, !firstHole.tees.isEmpty else {
            return [Tee(
                id: HackersID.string(),
                name: "Default",
                gender: Gender.unknown.rawValue,
                totalHoles: 18,
                holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: nil) },
                ratingFull: 72.0,
                slopeFull: 113,
                ratingFront: nil,
                slopeFront: nil,
                ratingBack: nil,
                slopeBack: nil
            )]
        }

        return firstHole.tees.map { teeData in
            let teeHoles = holes.map { hole in
                let teeDataForHole = hole.tees.first(where: { $0.teeId == teeData.teeId }) ?? teeData
                let par = teeDataForHole.parOverride ?? hole.par
                let handicap = teeDataForHole.hcpOverride ?? hole.handicap
                return Hole(
                    number: hole.number,
                    par: par,
                    yardage: teeDataForHole.yardage,
                    handicap: handicap
                )
            }

            let metadata = teeMetadata[teeData.teeId]
            return Tee(
                id: teeData.teeId,
                name: teeData.name,
                gender: metadata?.gender ?? Gender.unknown.rawValue,
                totalHoles: teeHoles.count,
                holes: teeHoles,
                ratingFull: metadata?.ratingFull ?? 72.0,
                slopeFull: metadata?.slopeFull ?? 113,
                ratingFront: metadata?.ratingFront,
                slopeFront: metadata?.slopeFront,
                ratingBack: metadata?.ratingBack,
                slopeBack: metadata?.slopeBack
            )
        }
    }

    private func scheduleAddressSearch(for query: String) {
        addressSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            addressSuggestions = []
            isSearchingAddress = false
            return
        }

        addressSearchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.loadSuggestions(for: trimmed)
        }
    }

    private func loadSuggestions(for query: String) async {
        isSearchingAddress = true
        defer { isSearchingAddress = false }

        do {
            let suggestions = try await addressSearchService.suggestions(for: query)
            guard !Task.isCancelled else { return }
            addressSuggestions = suggestions
        } catch is CancellationError {
            addressSuggestions = []
        } catch {
            addressSuggestions = []
            addressSearchError = error.localizedDescription
        }
    }

    private func applyResolvedAddress(_ resolved: ResolvedCourseAddress) {
        addressSearchTask?.cancel()
        addressSearchTask = nil
        address = resolved.address
        city = resolved.city
        state = resolved.state
        country = resolved.country
        latitude = resolved.latitude
        longitude = resolved.longitude
        addressQuery = resolved.query
        resolvedAddressQuery = resolved.query
        addressSuggestions = []
        isSearchingAddress = false
        addressSearchError = ""
    }

    private func clearDerivedLocation(keeping query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        address = trimmed
        city = ""
        state = ""
        country = ""
        latitude = 0
        longitude = 0
        resolvedAddressQuery = nil
    }

    private func coursesEqualIgnoringTimestamps(_ a: Course, _ b: Course) -> Bool {
        a.id == b.id
            && a.golfCourseApiID == b.golfCourseApiID
            && a.origin == b.origin
            && a.clubName == b.clubName
            && a.courseName == b.courseName
            && teesEqual(a.tees, b.tees)
            && locationsEqual(a.location, b.location)
    }

    private func teesEqual(_ a: [Tee], _ b: [Tee]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { teeA, teeB in
            teeA.id == teeB.id
                && teeA.name == teeB.name
                && teeA.gender == teeB.gender
                && teeA.holes.count == teeB.holes.count
                && zip(teeA.holes, teeB.holes).allSatisfy { holeA, holeB in
                    holeA.number == holeB.number
                        && holeA.par == holeB.par
                        && holeA.yardage == holeB.yardage
                        && holeA.handicap == holeB.handicap
                }
        }
    }

    private func locationsEqual(_ a: CourseLocation?, _ b: CourseLocation?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.address == rhs.address
                && lhs.city == rhs.city
                && lhs.state == rhs.state
                && lhs.country == rhs.country
                && abs(lhs.latitude - rhs.latitude) < 0.0001
                && abs(lhs.longitude - rhs.longitude) < 0.0001
        default:
            return false
        }
    }

    private static func formattedAddressQuery(address: String, city: String, state: String, country: String) -> String {
        let fullLine = [address, city, state, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return AddressFormatter.trimmedUSAddress(fullLine)
    }
}
