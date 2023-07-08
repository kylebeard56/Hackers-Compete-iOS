//
//  CurrentHoleButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct CurrentHoleButton: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    @State private var showHoleList: Bool = false
    
    private func holeLabel() -> String {
        "Currently on"
        //viewModel.didStartOnFirstHole ? "Currently on" : "Thru \(viewModel.netHoleNumber)"
    }
    
    var body: some View {
        button
            .sheet(isPresented: $showHoleList) {
                HoleSelectionView(viewModel: viewModel)
                    .presentationDetents([.height(560), .large])
                    .presentationDragIndicator(.visible)
            }
    }
    
    private var button: some View {
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
                    Text(holeLabel())
                        .font(.dmSans(size: 11, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Hole \(viewModel.currentHole)")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                        .alignLeading()
                }
                
                Text("Change")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemHackersGreen)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(Color.systemHackersGreen.opacity(colorScheme.translucent))
            .cornerRadius(12)
        }
//        .frame(height: 56)
    }
}

struct CurrentHoleButton_Previews: PreviewProvider {
    static var previews: some View {
        CurrentHoleButton(viewModel: RoundViewModel())
            .environmentObject(AppSession())
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
