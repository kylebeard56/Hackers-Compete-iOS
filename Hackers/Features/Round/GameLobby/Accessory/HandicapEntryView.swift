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
    var onComplete: CallbackValue<Int>? = nil
    
    @FocusState private var focus: Bool
    @State private var handicapValue: Int = 0
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
                        onTap: { onComplete?(handicapValue) }
                    )
                }
            }
            
            Text("Enter the number of strokes \(participant.name.fullName) should get over \(holes) holes (max of 36).")
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            TextField("00", text: $handicapString)
                .fontStyle(kFontName, size: 64, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .keyboardType(.numberPad)
                .focused($focus)
                .alignCenter()
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear {
            let currentValue = participant.adjustedHandicap
            handicapValue = min(max(currentValue, 0), 36)
            handicapString = String(handicapValue)
        }
        .task(delay: 0.2) {
            focus = true
        }
        .onChange(of: handicapString) {
            if let value = Int(handicapString.filter(\.isNumber)) {
                handicapValue = min(max(value, 0), 36)
                handicapString = String(handicapValue)
            }
        }
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        HandicapEntryView(participant: .constant(.init()))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}
