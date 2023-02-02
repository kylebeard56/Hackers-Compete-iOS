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
        VStack(spacing: kPadding) {
            header
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(1...18, id: \.self) { i in
                        Button(action: {
                            Haptics.fire(.light)
                            viewModel.currentHole = i
                            dismiss()
                        }) {
                            Text("Hole \(i)")
                                .font(.dmSans(size: 20, weight: viewModel.currentHole == i ? .bold : .regular))
                                .foregroundColor(
                                    viewModel.currentHole == i
                                    ? Color.systemGreen
                                    : viewModel.rulesExist[i] ?? false ? Color.systemBlack : Color.systemGray2)
                                .alignLeading()
                        }
                        Divider()
                    }
                }
                .padding(.horizontal, kPadding)
            }
            .padding(.horizontal, -kPadding)
        }
        .padding(kPadding)
    }
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("Change hole")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
    }
}

struct HoleListView_Previews: PreviewProvider {
    static var previews: some View {
        HoleListView(viewModel: RoundViewModel())    }
}
