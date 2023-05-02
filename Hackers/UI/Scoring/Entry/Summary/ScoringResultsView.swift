//
//  ScoringResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

struct ScoringResultsView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    /**
     Sort players by lowest to highest and show player score view to swipe through
     */
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
    
    private var header: some View {
        VStack {
            HStack {
                Text("Results")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("View your performance:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
}

struct ScoringResultsView_Previews: PreviewProvider {
    static var previews: some View {
        ScoringResultsView()
    }
}
