//
//  ScorecardPopupView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/22/26.
//


import SwiftUI

// MARK: - Usage
// Just call this from any view:
//
//   .sheet(isPresented: .constant(true)) {
//       ScorecardPopupView()
//   }
//
// The sheet manages its own detents, background interaction,
// dismiss lock, and drag indicator internally.

// MARK: - Main View

struct ScorecardPopupView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Detent definitions — tweak heights to match your design
    private let low  = PresentationDetent.height(120)
    private let mid  = PresentationDetent.height(300)
    private let high = PresentationDetent.height(700)

    @State private var currentDetent: PresentationDetent = .height(120)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // ── Always visible ──────────────────────────────────────
                HStack {
                    NavButton(style: .glass, icon: "f00a", weight: .regular)
                    Spacer(minLength: 0)
                    Text("hole tab")
                    Spacer(minLength: 0)
                    NavButton(style: .glass, icon: "e3ac", weight: .regular)
                }

                HStack(spacing: 16) {
                    StatLabel(title: "Par",     value: "4")
                    StatLabel(title: "Yards",   value: "385")
                    StatLabel(title: "HCP",     value: "7")
                    StatLabel(title: "Tee",     value: "Blue")
                }

                Button("Enter Scores") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                // ── Revealed at mid ─────────────────────────────────────
                Divider()

                VStack(spacing: 8) {
                    PlayerRow(name: "Alice",   score: 4)
                    PlayerRow(name: "Bob",     score: 5)
                    PlayerRow(name: "Charlie", score: 3)
                }

                // ── Revealed at high ────────────────────────────────────
                Divider()

                VStack(spacing: 8) {
                    ScoreHistoryRow(hole: 1, par: 4, score: 5)
                    ScoreHistoryRow(hole: 2, par: 3, score: 3)
                    ScoreHistoryRow(hole: 3, par: 5, score: 6)
                    ScoreHistoryRow(hole: 4, par: 4, score: nil)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .scrollDisabled(true)
        .edgesIgnoringSafeArea(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // ── Sheet config ────────────────────────────────────────────
        .presentationDetents([low, mid, high], selection: $currentDetent)
        .presentationDragIndicator(.visible)
        //.presentationBackground(.regularMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(700)))
        .interactiveDismissDisabled()
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThickMaterial)
                //Color.red.opacity(0.4)
            }
        }
    }
}

// MARK: - Sub-components

private struct StatLabel: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlayerRow: View {
    let name: String
    let score: Int
    var body: some View {
        HStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.caption.bold())
                }
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(score)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
    }
}

private struct ScoreHistoryRow: View {
    let hole: Int
    let par: Int
    let score: Int?

    private var relation: Int? { score.map { $0 - par } }

    var body: some View {
        HStack {
            Text("Hole \(hole)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Par \(par)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let score, let rel = relation {
                Text("\(score)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(rel < 0 ? .red : rel > 0 ? .blue : .primary)
                    .monospacedDigit()
                    .frame(width: 28)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(width: 28)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Simulate a map/background behind the sheet
        Color.green.opacity(0.3).ignoresSafeArea()
        Text("Map content here")
    }
    .sheet(isPresented: .constant(true)) {
        ScorecardPopupView()
    }
}
