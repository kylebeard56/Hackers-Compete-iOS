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
    
    @State private var showPartyCode: Bool = false
    @State private var showManageRound: Bool = false
    
    var body: some View {
        HStack(spacing: 20) {
            Image(uiImage: Asset.Images.logoGreen.image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                
            Spacer(minLength: 0)
            
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
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .fullScreenCover(isPresented: $showPartyCode) {
            PartyCodeView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showManageRound) {
            ManageRoundView(viewModel: viewModel)
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
