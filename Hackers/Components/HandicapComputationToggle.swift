//
//  HandicapComputationToggle.swift
//  Hackers
//
//  Created by Kyle Beard on 6/16/24.
//

import SwiftUI

private enum Scoring { case gross, net }

struct HandicapComputationToggle: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var useHCP: Bool
    var label: String = "Show using"
    @State private var scoring: Scoring = .net
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.dmSans, size: 15, weight: .medium)
                .foregroundColor(Color.systemGray)
            
            Button(action: {
                useHCP = scoring == .net
                scoring = useHCP ? .gross : .net
                Haptics.fire(.light)
            }) {
                ChipButton(
                    text: scoring == .net ? "net scoring" : "gross scoring",
                    backgroundColor: colorScheme.superlightGray
                )
            }
            
            Spacer(minLength: 0)
        }
    }
}

struct HandicapComputationToggle_Previews: PreviewProvider {
    static var previews: some View {
        HandicapComputationToggle(useHCP: .false)
            .holisticPreview()
    }
}
