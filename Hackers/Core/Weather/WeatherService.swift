//
//  WeatherService.swift
//  Hackers
//
//  Created by Kyle Beard on 2/18/26.
//

import CoreLocation
import Foundation
import WeatherKit

/// Lightweight weather snapshot for display. WeatherKit types are not Sendable.
struct WeatherSnapshot: Sendable {
    let temperature: Int
    let humidity: Double?
    let windSpeedMph: Double?
    let windDirection: String?
}

extension WeatherSnapshot {
    /// Sample data for previews and tests.
    static let mock = WeatherSnapshot(
        temperature: 72,
        humidity: 0.55,
        windSpeedMph: 8,
        windDirection: "SW"
    )
}

@MainActor
final class WeatherService: ObservableObject {
    private let weatherKit = WeatherKit.WeatherService.shared

    @Published private(set) var currentSnapshot: WeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    /// Apple Weather logo URLs for attribution. Fetched async per WeatherKit requirements.
    @Published private(set) var attributionLogoLightURL: URL?
    @Published private(set) var attributionLogoDarkURL: URL?
    /// Legal attribution page URL. Per Apple: must display trademark + legal link when showing weather data.
    @Published private(set) var attributionLegalPageURL: URL?

    func fetchWeather(for location: CLLocation?, mock: Bool = false) async {
        if mock {
            currentSnapshot = WeatherSnapshot.mock
            await fetchAttribution()
            return
        }
        
        guard let location else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let weather = try await weatherKit.weather(for: location, including: .current)
            currentSnapshot = WeatherSnapshot(
                temperature: Int(round(weather.temperature.converted(to: .fahrenheit).value)),
                humidity: weather.humidity,
                windSpeedMph: weather.wind.speed.converted(to: .milesPerHour).value,
                windDirection: weather.wind.compassDirection.abbreviation
            )
            await fetchAttribution()
        } catch {
            self.error = error
            currentSnapshot = nil
        }
    }
    
    private func fetchAttribution() async {
        do {
            let attribution = try await weatherKit.attribution
            attributionLogoLightURL = attribution.combinedMarkLightURL
            attributionLogoDarkURL = attribution.combinedMarkDarkURL
            attributionLegalPageURL = attribution.legalPageURL ?? URL(string: "https://weather-data.apple.com/legal-attribution.html")
        } catch {
            attributionLegalPageURL = URL(string: "https://weather-data.apple.com/legal-attribution.html")
        }
    }
}
