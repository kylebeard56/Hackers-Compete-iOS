//
//  TeeRow.swift
//  Hackers
//
//  Created by Kyle Beard on 9/26/25.
//

import SwiftUI

struct TeeRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    var tee: Tee
    var showGender: Bool = false
    var showDifficulty: Bool = false
    var segment: HoleSegment = .full18
    
    private var gender: Gender? { Gender(rawValue: tee.gender) }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                if let gender, showGender {
                    Text("\(tee.name) (\(gender.name.possessive))")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                } else {
                    Text(tee.name)
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                }

                
                Spacer()
                
                if showDifficulty {
                    HStack(spacing: 4) {
                        Text("\(tee.difficultyScore(for: segment))")
                            .fontStyle(.poppins, size: 13, weight: .medium)
                        Icon(name: "f06d", size: 13, weight: .regular)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .foregroundStyle(tee.difficultyColor(for: segment))
                    .background(tee.difficultyColor(for: segment).opacity(colorScheme.translucent))
                    .cornerRadius(radius: 6)
                }
            }
            
            HStack {
                Text("Par \(tee.par(for: segment))")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    
                Dot()
                
                Text("\(tee.yardage(for: segment)) yards")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    
                if let rating = tee.prettyRating(for: segment), let slope = tee.slope(for: segment) {
                    Dot()
                    
                    Text("\(rating) / \(slope)")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                }

                Spacer()
            }
        }
    }
}
