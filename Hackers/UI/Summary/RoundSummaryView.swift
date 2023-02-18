//
//  RoundSummaryView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/5/23.
//

import SwiftUI

struct RoundSummaryView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var viewModel = RoundSummaryViewModel()
    
    var body: some View {
        ZStack {
            //ScrollView {
                content
//            }
//            .alignTop()
            
            BigButton(
                title: "Finish",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { appSession.goToLanding() }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
            .padding(.horizontal, kPadding)
            .padding(.vertical, kPadding / 2)
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Round Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
        })
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Coming Soon").bold()
            Spacer()
            
            /**
             [ Results rows ]
             [ Total | Team ]
             [ Hardest | Easiest ]
             [ Best Challenge | Best Favor ]
             [ See full breakdown rows... ]
             [ Feedback and ratings ]
             [ Finish button ]
             
             
             - Winner -> Results of the round (1st 2nd 3rd etc)
             - Tile: Total favor vs challenge cards throughout round (Your party played X favor and X challenge)
             - Tile: Total team favor vs challenge (Your team collectively played X favor and X challenge holes)
             - <player> had the hardest round with X challenge cards
             - <player> had the easiest round with X favor cards
             - <player> performed best against a challenge with a scoring avg +0.3 over par
             - <player> performed best with favors with a scoring avg -0.4 under par
             - Area to provide rate round, give feedback, for the round or improve the app (text box).
                - If 4 stars or more, prompt user for app store rating.
             */
        }
    }
}

struct RoundSummaryView_Previews: PreviewProvider {
    static var view: some View {
        RoundSummaryView().environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
