//
//  CourseEditViewModelTests.swift
//  HackersUnitTests
//
//  Created by Codex on 3/17/26.
//

import CoreLocation
import Testing
@testable import Hackers

@MainActor
@Suite("Course Edit ViewModel")
struct CourseEditViewModelTests {
    @Test("Applying a suggestion updates address parts and coordinates")
    func applySuggestionUpdatesAddressFields() async {
        let service = MockAddressSearchService()
        service.resolvedSuggestion = ResolvedCourseAddress(
            address: "650 Verdae Blvd",
            city: "Greenville",
            state: "SC",
            country: "United States",
            latitude: 34.825,
            longitude: -82.338
        )

        let viewModel = CourseEditViewModel(course: makeCourse(), addressSearchService: service)
        let suggestion = CourseAddressSuggestion(title: "650 Verdae Blvd", subtitle: "Greenville, SC")

        await viewModel.applySuggestion(suggestion)

        #expect(viewModel.address == "650 Verdae Blvd")
        #expect(viewModel.city == "Greenville")
        #expect(viewModel.state == "SC")
        #expect(viewModel.country == "United States")
        #expect(abs(viewModel.latitude - 34.825) < 0.000_001)
        #expect(abs(viewModel.longitude + 82.338) < 0.000_001)
        #expect(viewModel.addressQuery == "650 Verdae Blvd, Greenville, SC")
    }

    @Test("Applying current location reverse geocodes into the same fields")
    func applyCurrentLocationPopulatesAddressFields() async {
        let service = MockAddressSearchService()
        service.reversedLocation = ResolvedCourseAddress(
            address: "201 Gold Bridge Rd",
            city: "Marietta",
            state: "SC",
            country: "United States",
            latitude: 35.030,
            longitude: -82.518
        )

        let viewModel = CourseEditViewModel(course: makeCourse(), addressSearchService: service)
        let location = CLLocation(latitude: 35.030, longitude: -82.518)

        await viewModel.applyCurrentLocation(location)

        #expect(service.lastReverseGeocodeLocation?.coordinate.latitude == location.coordinate.latitude)
        #expect(service.lastReverseGeocodeLocation?.coordinate.longitude == location.coordinate.longitude)
        #expect(viewModel.address == "201 Gold Bridge Rd")
        #expect(viewModel.city == "Marietta")
        #expect(viewModel.state == "SC")
        #expect(viewModel.addressQuery == "201 Gold Bridge Rd, Marietta, SC")
    }

    @Test("Manual address entry clears stale derived coordinates but still builds")
    func manualAddressClearsDerivedLocation() throws {
        let initialLocation = CourseLocation(
            address: "650 Verdae Blvd",
            city: "Greenville",
            state: "SC",
            country: "United States",
            latitude: 34.825,
            longitude: -82.338
        )
        let viewModel = CourseEditViewModel(
            course: makeCourse(location: initialLocation),
            addressSearchService: MockAddressSearchService()
        )

        viewModel.updateAddressQuery("123 Practice Rd")

        #expect(viewModel.address == "123 Practice Rd")
        #expect(viewModel.city.isEmpty)
        #expect(viewModel.state.isEmpty)
        #expect(viewModel.country.isEmpty)
        #expect(viewModel.latitude == 0)
        #expect(viewModel.longitude == 0)

        let built = viewModel.buildCourse()
        let location = try #require(built.location)

        #expect(location.address == "123 Practice Rd")
        #expect(location.city == nil)
        #expect(location.state == nil)
        #expect(location.latitude == 0)
        #expect(location.longitude == 0)
    }

    @Test("Adding a tee applies it across every hole")
    func addTeeAddsAcrossEveryHole() {
        let viewModel = CourseEditViewModel(course: makeCourse(), addressSearchService: MockAddressSearchService())
        let initialCount = viewModel.holes.first?.tees.count ?? 0

        viewModel.addTee()

        #expect(viewModel.holes.allSatisfy { $0.tees.count == initialCount + 1 })
        let newTeeIDs = Set(viewModel.holes.compactMap { $0.tees.last?.teeId })
        #expect(newTeeIDs.count == 1)
    }

    @Test("Tee overrides are written only where present")
    func teeOverridesPersistIntoBuiltCourse() throws {
        let viewModel = CourseEditViewModel(course: makeCourse(), addressSearchService: MockAddressSearchService())
        let teeID = try #require(viewModel.holes.first?.tees.last?.teeId)

        viewModel.holes[0].tees[1].parOverride = 5
        viewModel.holes[0].tees[1].hcpOverride = 11

        let built = viewModel.buildCourse()
        let overriddenTee = try #require(built.tees.first(where: { $0.id == teeID }))

        #expect(overriddenTee.holes[0].par == 5)
        #expect(overriddenTee.holes[0].handicap == 11)
        #expect(overriddenTee.holes[1].par == viewModel.holes[1].par)
        #expect(overriddenTee.holes[1].handicap == viewModel.holes[1].handicap)
    }

    private func makeCourse(location: CourseLocation? = nil) -> Course {
        let teeOneHoles = (1...3).map { holeNumber in
            Hole(number: holeNumber, par: 4, yardage: 320 + holeNumber, handicap: 18 - holeNumber)
        }
        let teeTwoHoles = (1...3).map { holeNumber in
            Hole(number: holeNumber, par: 4, yardage: 300 + holeNumber, handicap: 18 - holeNumber)
        }

        let tees = [
            Tee(
                id: "white_male",
                name: "White",
                gender: Gender.male.rawValue,
                totalHoles: 3,
                holes: teeOneHoles,
                ratingFull: 72,
                slopeFull: 120,
                ratingFront: nil,
                slopeFront: nil,
                ratingBack: nil,
                slopeBack: nil
            ),
            Tee(
                id: "gold_female",
                name: "Gold",
                gender: Gender.female.rawValue,
                totalHoles: 3,
                holes: teeTwoHoles,
                ratingFull: 70,
                slopeFull: 115,
                ratingFront: nil,
                slopeFront: nil,
                ratingBack: nil,
                slopeBack: nil
            ),
        ]

        return Course(
            id: "course_1",
            origin: .hackers,
            clubName: "Test Club",
            courseName: "Test Course",
            location: location,
            tees: tees
        )
    }
}

@MainActor
private final class MockAddressSearchService: CourseAddressSearchServicing {
    var suggestionsResponse: [CourseAddressSuggestion] = []
    var resolvedSuggestion = ResolvedCourseAddress(
        address: "",
        city: "",
        state: "",
        country: "",
        latitude: 0,
        longitude: 0
    )
    var reversedLocation = ResolvedCourseAddress(
        address: "",
        city: "",
        state: "",
        country: "",
        latitude: 0,
        longitude: 0
    )
    var lastReverseGeocodeLocation: CLLocation?

    func suggestions(for query: String) async throws -> [CourseAddressSuggestion] {
        suggestionsResponse
    }

    func resolveSuggestion(_ suggestion: CourseAddressSuggestion) async throws -> ResolvedCourseAddress {
        resolvedSuggestion
    }

    func reverseGeocode(_ location: CLLocation) async throws -> ResolvedCourseAddress {
        lastReverseGeocodeLocation = location
        return reversedLocation
    }
}
