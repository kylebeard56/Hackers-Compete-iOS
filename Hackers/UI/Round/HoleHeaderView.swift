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
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(height: 56)
            .padding(.bottom, 20)
            .sheet(isPresented: $showHoleList) {
                VStack {
                    Text("todo")
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
    
    private var content: some View {
        HStack(spacing: 12) {
            Image(uiImage: Asset.Images.logoGreen.image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                
            Spacer(minLength: 0)
            
            Button(action: {
                showHoleList = true
                Haptics.fire(.light)
            }) {
                HStack(spacing: 20) {
                    AwesomeImage(
                        rawIcon: "f450".unicode,
                        style: .regular,
                        size: 24,
                        color: .systemHackersGreen
                    )
                    
                    VStack(spacing: 0) {
                        Text("Currently on")
                            .font(.dmSans(size: 11, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                        
                        Text("Hole \(viewModel.currentHole)")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(Color.systemHackersGreen)
                            .alignLeading()
                    }
                    .frame(width: 72)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .background(Color.systemHackersGreen.opacity(0.1))
                .cornerRadius(12)
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
