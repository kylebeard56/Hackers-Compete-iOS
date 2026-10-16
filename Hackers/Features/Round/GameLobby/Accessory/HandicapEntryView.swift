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
    var handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole
    var onComplete: CallbackValue<RoundParticipant>? = nil
    
    @FocusState private var focus: Bool
    @State private var handicapValue: Double = 0
    @State private var approveEstimate = false
    @State private var manualStrokes = false
    @State private var handicapString: String = ""
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private var effectiveFormat: HandicapEntryFormat { manualStrokes ? .strokes : entryFormat }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Handicap")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
                
                if Double(handicapString)?.isFinite == true {
                    NavButton(
                        icon: "f00c",
                        color: palette.backgroundColor,
                        background: palette.foregroundColor,
                        onTap: {
                            onComplete?(
                                HandicapCalculator.participant(
                                    participant,
                                    applying: handicapValue,
                                    format: effectiveFormat,
                                    courseSegment: courseSegment,
                                    maximumHandicap: maximumValue,
                                    handicapStrokeBasis: handicapStrokeBasis,
                                    approveEstimate: approveEstimate
                                )
                            )
                        }
                    )
                }
            }
            
            Text(effectiveFormat == .courseHandicap ? "Enter \(participant.name.fullName)'s handicap index." : "Enter the number of strokes \(participant.name.fullName) should get over \(holes) holes (max of \(maximumValue)).")
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            TextField("00", text: $handicapString)
                .fontStyle(kFontName, size: 64, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .keyboardType(effectiveFormat == .courseHandicap ? .numbersAndPunctuation : .numberPad)
                .focused($focus)
                .alignCenter()

            if effectiveFormat == .courseHandicap {
                CourseHandicapStatusView(
                    calculation: calculation,
                    strokes: calculation.allowedStrokes(maximum: maximumValue, estimateApproved: approveEstimate),
                    estimateApproved: approveEstimate,
                    onUseEstimate: { approveEstimate = true },
                    onEnterStrokes: {
                        if let value = Double(handicapString) {
                            participant = HandicapCalculator.participant(participant, applying: value, format: .courseHandicap,
                                courseSegment: courseSegment, handicapStrokeBasis: handicapStrokeBasis)
                        }
                        manualStrokes = true
                        handicapString = ""
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear {
            manualStrokes = participant.handicapResolution?.entryFormat == .strokes
            if effectiveFormat == .courseHandicap {
                handicapValue = participant.handicapIndex ?? 0
                handicapString = participant.handicapIndex.map { String(format: "%.1f", $0) } ?? ""
            } else {
                handicapValue = Double(participant.adjustedHandicap)
                handicapString = String(participant.adjustedHandicap)
            }
        }
        .task(delay: 0.2) {
            focus = true
        }
        .onChange(of: calculation) { approveEstimate = false }
        .onChange(of: handicapString) {
            if effectiveFormat == .courseHandicap {
                let filtered = decimalHandicapText(handicapString)
                if filtered != handicapString {
                    handicapString = filtered
                }
                handicapValue = Double(filtered) ?? 0
            } else if let value = Int(handicapString.filter(\.isNumber)) {
                let clamped = min(max(value, 0), maximumValue)
                handicapValue = Double(clamped)
                handicapString = String(clamped)
            }
        }
    }

    private var calculation: CourseHandicapCalculation {
        HandicapCalculator.calculation(index: Double(handicapString), participant: participant,
            courseSegment: courseSegment, indexBasis: handicapStrokeBasis)
    }

    private func decimalHandicapText(_ text: String) -> String {
        HandicapIndexEntry.filtered(text)
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        HandicapEntryView(participant: .constant(.init()))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}

/// Shared status within existing setup editors; never used in live score entry.
struct CourseHandicapStatusView: View {
    let calculation: CourseHandicapCalculation
    let strokes: Int?
    var estimateApproved = false
    var onUseEstimate: (() -> Void)? = nil
    var onFixCourseData: (() -> Void)? = nil
    var onEnterStrokes: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let index = calculation.handicapIndex {
                Text("Handicap Index: \(String(format: "%.1f", index))")
            }
            switch calculation.status {
            case .exact:
                Text("Course HCP: \(calculation.courseHandicap ?? 0) · Exact")
            case .estimated:
                Text("Estimated Course HCP: \(calculation.courseHandicap ?? 0)")
                Text("Estimated from 18-hole tee data. Not an official nine-hole Course Handicap.")
                if !estimateApproved, let onUseEstimate {
                    Button("Use Estimate", action: onUseEstimate)
                }
            case .unavailable:
                Text("Course HCP: Unavailable")
                Text(calculation.handicapIndex == nil
                    ? "Handicap Index unavailable. Enter an Index or strokes for this round."
                    : calculation.indexBasis == nil
                    ? "Index basis is missing. Choose the source Index's 9-hole or 18-hole basis."
                    : "Rating or slope missing. Handicap Index saved; Course HCP cannot be calculated.")
                if let onFixCourseData { Button("Fix Course Data", action: onFixCourseData) }
                if let onEnterStrokes { Button("Enter strokes for this round", action: onEnterStrokes) }
            }
            if let strokes { Text("Strokes Received: \(strokes)") }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
