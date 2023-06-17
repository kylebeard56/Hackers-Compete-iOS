//
//  HoleListView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/23.
//

import SwiftUI

struct HoleListView: View {
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            header
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(1...18, id: \.self) { i in
                        Button(action: {
                            Haptics.fire(.light)
                            viewModel.currentHole = i
                            dismiss()
                        }) {
                            HStack {
                                Text("Hole \(i)")
                                    .font(.dmSans(size: 20, weight: viewModel.currentHole == i ? .bold : .regular))
                                    .foregroundColor(
                                        viewModel.currentHole == i
                                        ? Color.systemGreen
                                        : viewModel.doesRuleExist(for: i) ? Color.systemBlack : Color.systemGray2
                                    )
                                
                                // TODO: Add button here for 3/4/5 par and hole conditions?
                                
                                Spacer(minLength: 0)
                                
                                Text("\(scoreCount(for: i)) scored")
                                    .font(.dmSans(size: 15, weight: viewModel.currentHole == i ? .bold : .regular))
                                    .foregroundColor(
                                        viewModel.players.compactMap({ $0.score[i] }).count == 0
                                        ? Color.systemGray2
                                        : Color.systemBlack
                                    )
                            }
                        }
                        Divider()
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
        .padding(16)
//        .onAppear {
//            printPretty(viewModel.rulesExist)
//        }
    }
    
    private func scoreCount(for i: Int) -> Int {
        return viewModel.players.compactMap({ $0.score[i] }).filter({ $0 != PlayerScore.none.rawValue }).count
    }
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            .padding(.top, 8)
            
            Text("Holes")
                .font(.fugazOne(size: 40))
                .foregroundColor(Color.systemBlack)
                .padding(.top, 8)
        }
    }
}

struct HoleListView_Previews: PreviewProvider {
    static var previews: some View {
        HoleListView(viewModel: RoundViewModel())    }
}
