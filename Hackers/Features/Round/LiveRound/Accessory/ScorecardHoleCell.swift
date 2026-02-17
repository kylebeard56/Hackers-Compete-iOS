//
//  ScorecardHoleCell.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct ScorecardHoleCell: View {
    let palette: DesignPalette
    let holeNumber: Int
    let par: Int?
    let gross: Int?
    let net: Int?
    let strokesReceived: Int
    let basis: ScoreBasis
    
    private var displayed: Int? { basis == .gross ? gross : net }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Hole \(holeNumber)")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            
           //popDots
            
            ZStack {
                decoration
                
                Text(displayed.map(String.init) ?? "—")
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(height: 36)
            
            if let par {
                Text("Par \(par)")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral2)
            }
        }
        .alignCenter()
        .padding(12)
//        .glassCardEffect(cornerRadius: 16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
//        .overlay {
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .stroke(palette.borderColor.opacity(0.6), lineWidth: 1)
//        }
        .overlay(alignment: .topTrailing) {
            popDots
        }
    }
    
    @ViewBuilder
    private var popDots: some View {
        if basis == .gross && strokesReceived > 0 {
            HStack(spacing: 2) {
                ForEach(0..<strokesReceived, id: \.self) { _ in
                    Circle()
                        .fill(palette.foregroundColor.opacity(0.7))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(6)
        }
    }
    
    @ViewBuilder
    private var decoration: some View {
        if let par, let strokes = displayed {
            let diff = strokes - par
            
            // Eagle or better: solid circle
            if diff <= -2 {
                Circle()
                    .fill(palette.foregroundColor.opacity(0.14))
                    .frame(width: 34, height: 34)
            }
            
            // Birdie: outline circle
            else if diff == -1 {
                Circle()
                    .stroke(palette.foregroundColor, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
            
            // Bogey: outline square
            else if diff == 1 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(palette.foregroundColor, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
            
            // Double or worse: solid square
            else if diff >= 2 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.foregroundColor.opacity(0.14))
                    .frame(width: 34, height: 34)
            }
            
            else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
}

#Preview("Scorecard Hole Cell") {
    ScorecardHoleCell(
        palette: .init(theme: .primary, scheme: .light),
        holeNumber: 1,
        par: 4,
        gross: 4,
        net: 3,
        strokesReceived: 1,
        basis: .gross
    )
    .padding(16)
}
