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
        VStack(spacing: 4) {
            header
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            ScrollView {
                content
                    .padding(16)
            }
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .onAppear() {
            if let s = appSession.session {
                viewModel.load(s, appSession.rules)
            }
        }
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let s = data.object as? Session {
                viewModel.load(s, appSession.rules)
            } else if let s = appSession.session {
                viewModel.load(s, appSession.rules)
            }
        })
    }
    
    private var header: some View {
        ZStack {
            Text("Round Summary")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
            
            BackButton(icon: .xmark, onTap: { dismiss() })
                .alignTrailing()
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            ForEach(0..<viewModel.playerResult.count, id: \.self) { i in
                PlayerSummary(result: viewModel.playerResult[i], place: i + 1)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
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
