//
//  MaxScoreView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/23.
//

import SwiftUI

struct MaxScoreView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            List {
                Section(header: Text("Max score over par")) {
                    row(value: 3)
                    row(value: 4)
                    row(value: 5)
                    row(value: 6)
                }
            }
            .padding(.top, 10)
            .background(Color.systemGray6)
            .scrollContentBackground(.hidden)
        }
    }
    
    @ViewBuilder private func row(value: Int) -> some View {
        let isSelected = deviceDefaults.maxScoreOverPar == value
        Button(action: {
            deviceDefaults.maxScoreOverPar = value
            Haptics.fire(.light)
            dismiss()
        }) {
            HStack {
                Text("\(value) over par")
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Image(systemName: "checkmark")
                    .foregroundColor(Color.systemBlack)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, 4)
        }
    }
}

struct ButtonRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // nothing
        }.sheet(isPresented: .true) {
            MaxScoreView()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .holisticPreview()
    }
}
