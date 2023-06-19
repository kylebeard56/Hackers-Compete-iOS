//
//  HoleHeaderView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/28/23.
//

import SwiftUI

struct HoleHeaderView: View {
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    @State private var showHoleList: Bool = false
    @State private var showMenu: Bool = false
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(height: 56)
            .sheet(isPresented: $showMenu) {
                MenuView(onPartyCode: {
                    code in viewModel.sessionCode = code
                }, onEnd: {
                    showMenu = false
                    Task(operation: appSession.endRound)
                })
                .presentationDetents([.height(adminMode ? 500 : 410)])
                .presentationDragIndicator(.visible)
            }
//            .sheet(isPresented: $showHoleList) {
//                HoleListView(viewModel: viewModel)
//                    .presentationDetents([.medium, .large])
//                    .presentationDragIndicator(.visible)
//            }
    }
    
    private var content: some View {
        HStack(spacing: 12) {
            Image(uiImage: Asset.Images.logoGreen.image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
            
            Spacer(minLength: 0)
            
            Button(action: {
                showHoleList = true
                FirebaseEvent.menuTapped.log()
                Haptics.fire(.light)
            }) {
                Text("Hole \(viewModel.currentHole)")
                    .font(.dmSans(size: 20, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
            
            Button(action: {
                showMenu = true
                FirebaseEvent.menuTapped.log()
                Haptics.fire(.light)
            }) {
                AwesomeImage(rawIcon: "f0c9".unicode, style: .regular, size: 20, color: .systemBlack)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
        }
    }
}

struct HoleHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HoleHeaderView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
    }
}
