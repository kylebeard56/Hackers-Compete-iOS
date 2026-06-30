//
//  SeriesDashboardTileChip.swift
//  Hackers
//
//  Next-round / live status chip for dashboard series rows.
//

import SwiftUI

// MARK: - Logic

enum SeriesDashboardTileChipMode: Equatable {
    case live
    case text(String)
    case scheduleTBD
    case none
}

enum SeriesDashboardTileChip {
    static func linkedRoundsMap(from rounds: Set<Round>) -> [String: Round] {
        Dictionary(uniqueKeysWithValues: rounds.map { ($0.id, $0) })
    }

    static func effectiveStatus(for seriesRound: SeriesRound, linkedRounds: [String: Round]) -> SeriesRoundStatus {
        guard let roundID = seriesRound.roundID, let linked = linkedRounds[roundID] else { return seriesRound.status }
        return SeriesViewModel.resolvedLinkedRoundStatus(
            previousStatus: seriesRound.status,
            linkedRoundStatus: linked.status
        )
    }

    static func chipMode(
        seriesRounds: [SeriesRound],
        linkedRounds: [String: Round],
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> SeriesDashboardTileChipMode {
        let upcoming = seriesRounds
            .filter {
                let s = effectiveStatus(for: $0, linkedRounds: linkedRounds)
                return s == .planned || s == .lobby || s == .live
            }
            .sorted {
                let lhs = $0.scheduledAt?.unix ?? .greatestFiniteMagnitude
                let rhs = $1.scheduledAt?.unix ?? .greatestFiniteMagnitude
                if lhs != rhs { return lhs < rhs }
                return $0.index < $1.index
            }

        guard let first = upcoming.first else { return .none }
        let status = effectiveStatus(for: first, linkedRounds: linkedRounds)
        if status == .live { return .live }
        if let scheduled = first.scheduledAt {
            let date = Date(timeIntervalSince1970: scheduled.unix)
            return .text(formatScheduledChip(date: date, now: now, calendar: calendar))
        }
        return .scheduleTBD
    }

    static func formatScheduledChip(date: Date, now: Date, calendar: Calendar) -> String {
        let time = date.toTimeFormat
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfEvent = calendar.startOfDay(for: date)
        let dayDelta = calendar.dateComponents([.day], from: startOfToday, to: startOfEvent).day ?? 0

        if dayDelta >= 2, dayDelta <= 6 {
            return "In \(dayDelta) days · \(time)"
        }
        return "\(date.toShortFormatYearless) · \(time)"
    }
}

// MARK: - View

struct SeriesDashboardTileStatusChip: View {
    let mode: SeriesDashboardTileChipMode

    var body: some View {
        switch mode {
        case .none:
            EmptyView()
        case .live:
            LiveStatusView(
                color: .accentPurple,
                fontSize: 12,
                label: "Live",
                rippleColor: .white.opacity(0.3)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentPurple.opacity(0.2))
            .cornerRadius(radius: 8)
        case .text(let value):
            Text(value)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassCardEffect(cornerRadius: 8)
        case .scheduleTBD:
            Text("Schedule TBD")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassCardEffect(cornerRadius: 8)
        }
    }
}
