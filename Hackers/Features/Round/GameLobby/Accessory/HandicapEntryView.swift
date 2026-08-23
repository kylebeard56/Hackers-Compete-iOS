//
//  HandicapEntryView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/20/25.
//

import SwiftUI

struct HandicapEntryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var participant: RoundParticipant
    var holes: Int = 18
    var maximumValue: Int = 36
    var entryFormat: HandicapEntryFormat = .strokes
    var courseSegment: CourseSegment? = nil
    var handicapStrokeBasis: SeriesHandicapStrokeBasis = .eighteenHole
    var onComplete: CallbackValue<RoundParticipant>? = nil
    
    @FocusState private var focus: Bool
    @State private var handicapValue: Double = 0
    @State private var handicapString: String = ""
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Handicap")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
                
                if handicapString.isPopulated {
                    NavButton(
                        icon: "f00c",
                        color: palette.backgroundColor,
                        background: palette.foregroundColor,
                        onTap: {
                            onComplete?(
                                HandicapCalculator.participant(
                                    participant,
                                    applying: handicapValue,
                                    format: entryFormat,
                                    courseSegment: courseSegment,
                                    maximumHandicap: maximumValue,
                                    handicapStrokeBasis: handicapStrokeBasis
                                )
                            )
                        }
                    )
                }
            }
            
            Text(entryFormat == .courseHandicap ? "Enter \(participant.name.fullName)'s handicap index." : "Enter the number of strokes \(participant.name.fullName) should get over \(holes) holes (max of \(maximumValue)).")
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            TextField("00", text: $handicapString)
                .fontStyle(kFontName, size: 64, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .keyboardType(entryFormat == .courseHandicap ? .decimalPad : .numberPad)
                .focused($focus)
                .alignCenter()

            if entryFormat == .courseHandicap, let computedCourseHandicap {
                Text("Course HCP: \(Int(computedCourseHandicap.rounded(.toNearestOrAwayFromZero)))")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear {
            let currentValue = entryFormat == .courseHandicap
                ? participant.handicapIndex ?? Double(participant.originalHandicap)
                : Double(participant.adjustedHandicap)
            handicapValue = min(max(currentValue, 0), Double(maximumValue))
            handicapString = entryFormat == .courseHandicap ? String(format: "%.1f", handicapValue) : String(Int(handicapValue.rounded()))
        }
        .task(delay: 0.2) {
            focus = true
        }
        .onChange(of: handicapString) {
            if entryFormat == .courseHandicap {
                let filtered = decimalHandicapText(handicapString)
                if filtered != handicapString {
                    handicapString = filtered
                }
                handicapValue = max(Double(filtered) ?? 0, 0)
            } else if let value = Int(handicapString.filter(\.isNumber)) {
                let clamped = min(max(value, 0), maximumValue)
                handicapValue = Double(clamped)
                handicapString = String(clamped)
            }
        }
    }

    private var computedCourseHandicap: Double? {
        HandicapCalculator.rawCourseHandicap(
            index: handicapValue,
            participant: participant,
            courseSegment: courseSegment,
            handicapStrokeBasis: handicapStrokeBasis
        )
    }

    private func decimalHandicapText(_ text: String) -> String {
        var hasDecimal = false
        var decimalPlaces = 0
        var output = ""
        for character in text {
            if character.isNumber {
                if hasDecimal {
                    guard decimalPlaces < 1 else { continue }
                    decimalPlaces += 1
                }
                output.append(character)
            } else if character == ".", !hasDecimal {
                hasDecimal = true
                output.append(character)
            }
        }
        return output
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        HandicapEntryView(participant: .constant(.init()))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}
