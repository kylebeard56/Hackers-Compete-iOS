//
//  PlayerEntry.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PlayerEntry: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @State private var navigateToRound: Bool = false
    
    var body: some View {
        VStack(spacing: kPadding) {
            Text("Player One")
            Text("Player Two")
            Text("Player Three")
            Text("Player Four")
            Text("Player Five")
            Spacer()
            BigButton(
                title: "Start round",
                labelColor: .white,
                buttonColor: .black,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    navigateToRound = true
                    Haptics.fire(.light)
                }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
        }
        .padding(kPadding)
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.largeTitleTextAttributes = [.font: UIFont.dmSans(size: 40, weight: .bold)]
        })
    }
}

struct PlayerEntry_Previews: PreviewProvider {
    static var previews: some View {
        PlayerEntry()
    }
}
