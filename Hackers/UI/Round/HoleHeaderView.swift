//
//  HoleHeaderView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/28/23.
//

import SwiftUI

struct HoleHeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    @State private var showSpectatorView: Bool = false
    @State private var showPartyCode: Bool = false
    @State private var showManageRound: Bool = false
    
    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .sheet(isPresented: $showSpectatorView) {
                VStack {
                    Text("todo: coming soon view")
                }
            }
            .fullScreenCover(isPresented: $showPartyCode) {
                PartyCodeView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showManageRound) {
                ManageRoundView(viewModel: viewModel)
            }
    }
    
    private var content: some View {
        HStack(spacing: 24) {
            Image(uiImage: Asset.Images.logoGreen.image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                
            Spacer(minLength: 0)
            
            Button(action: {
                showSpectatorView = true
                Haptics.fire(.light)
            }) {
                AwesomeImage(rawIcon: "e03e".unicode, style: .regular, size: 24, color: Color.systemBlack)
            }
            
            Button(action: {
                showPartyCode = true
                Haptics.fire(.light)
            }) {
                AwesomeImage(rawIcon: "e31b".unicode, style: .regular, size: 24, color: Color.systemBlack)
            }
            
            Button(action: {
                showManageRound = true
                Haptics.fire(.light)
            }) {
                AwesomeImage(rawIcon: "e0ae".unicode, style: .regular, size: 24, color: Color.systemBlack)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
    }
}

struct HoleHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HoleHeaderView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
            .holisticPreview()
    }
}
