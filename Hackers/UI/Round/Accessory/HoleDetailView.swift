//
//  HoleDetailView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct HoleDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    @State private var details: HoleDetails = HoleDetails()
    private var isDisabled: Binding<Bool> { .constant(details.par == 0) }
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.top, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    pars
                        .padding(.top, 16)
                    conditions
                }
            }
            
            Spacer(minLength: 0)
            
            BigButton(
                title: "Save",
                labelColor: .systemWhite,
                buttonColor: .systemGreen,
                isDisabled: isDisabled,
                isLoading: .false,
                onTap: save
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
            .background(Color.systemCard)
        }
        .padding(16)
        .background(Color.systemViewBackground)
        .onAppear() {
            if let d = viewModel.holeDetails[hole] {
                self.details = d
            }
        }
    }
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("Hole \(hole)")
                .font(.fugazOne(size: 40))
                .foregroundColor(Color.systemBlack)
        }
    }
    
    private var pars: some View {
        VStack(spacing: 16) {
            Group {
                Text("What ")
                + Text("par")
                    .bold()
                    .foregroundColor(Color.systemGreen)
                + Text(" is this hole?")
            }
            .font(.dmSans(size: 17, weight: .regular))
            .foregroundColor(Color.systemBlack)
            
            PillDivider()
            
            HStack(spacing: 16) {
                parButton(.three)
                parButton(.four)
                parButton(.five)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder  private func parButton(_ par: HolePar) -> some View {
        let isSelected: Bool = details.par == par.rawValue
        Button(action: {
            details.par = par.rawValue
            Haptics.fire(.light)
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.systemGreen.opacity(0.125) : Color.systemGray6.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.systemGreen : Color.systemGray2, lineWidth: isSelected ? 4 : 2)
                    )
                Text("\(par.rawValue)")
                    .font(.dmSans(size: 32, weight: .medium))
                    .foregroundColor(isSelected ? Color.systemGreen : Color.systemGray2)
            }
        }
    }
    
    private var conditions: some View {
        VStack(spacing: 16) {
            Group {
                Text("What ")
                + Text("hazards")
                    .bold()
                    .foregroundColor(Color.systemGreen)
                + Text(" or ")
                + Text("tough conditions")
                    .bold()
                    .foregroundColor(Color.systemGreen)
                + Text("?")
            }
            .font(.dmSans(size: 17, weight: .regular))
            .foregroundColor(Color.systemBlack)
            
            PillDivider()
            
            LazyVGrid(columns: kDualColumnGrid) {
                conditionButton(.water)
                conditionButton(.bunkers)
                conditionButton(.trees)
                conditionButton(.wind)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func conditionButton(_ c: HoleCondition) -> some View {
        let isSelected: Bool = details.conditions.contains(c.rawValue)
        Button(action: {
            details.conditions.toggle(c.rawValue)
            Haptics.fire(.light)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.systemGreen.opacity(0.125) : Color.systemGray6.opacity(0.2))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.systemGreen : Color.systemGray2, lineWidth: isSelected ? 4 : 2)
                    )
                VStack(spacing: 16) {
                    AwesomeImage(
                        icon: c.icon,
                        style: .regular,
                        size: 30,
                        color: isSelected ? Color.systemGreen : Color.systemGray2)
                    Text("\(c.displayName)")
                        .font(.dmSans(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? Color.systemGreen : Color.systemGray2)
                }
            }
        }
    }
    
    private func save() {
        viewModel.holeDetails.updateValue(self.details, forKey: hole)
        dismiss()
    }
}

struct HoleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        HoleDetailView(
            viewModel: RoundViewModel(),
            hole: 1
        )
        .holisticPreview()
    }
}
