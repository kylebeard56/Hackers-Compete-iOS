//
//  HoleDetailView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct HoleDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var details: HoleDetails = HoleDetails()
    var hole: Int
    var onSave: OnHoleDetailSelection?
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.top, kPadding / 2)
            ScrollView(showsIndicators: false) {
                VStack(spacing: kPadding * 2) {
                    pars.padding(.top, kPadding)
                    conditions
                }
            }
            
            Spacer(minLength: 0)
            
            BigButton(
                title: "Save",
                labelColor: .systemWhite,
                buttonColor: .systemGreen,
                isDisabled: .constant(details.par == .none),
                isLoading: .false,
                onTap: save
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
            .background(Color.systemCard)
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
            
            Text("Hole \(hole)")
                .font(.dmSans(size: 40, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
    }
    
    private var pars: some View {
        VStack(spacing: kPadding) {
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
            
            HStack {
                parButton(.three)
                Spacer(minLength: 0)
                parButton(.four)
                Spacer(minLength: 0)
                parButton(.five)
            }
            .padding(.top, kPadding)
        }
        .padding(.horizontal, kPadding)
    }
    
    private func parButton(_ par: HolePar) -> some View {
        Button(action: {
            details.par = par
            Haptics.fire(.light)
        }) {
            ZStack {
                Circle()
                    .fill(details.par == par ? Color.systemGreen.opacity(0.125) : Color.systemGray6.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle().stroke(
                            details.par == par ? Color.systemGreen : Color.systemGray2,
                            lineWidth: details.par == par ? 4 : 2)
                    )
                Text("\(par.rawValue)")
                    .font(.dmSans(size: 32, weight: .medium))
                    .foregroundColor(details.par == par ? Color.systemGreen : Color.systemGray2)
            }
        }
    }
    
    private var conditions: some View {
        VStack(spacing: kPadding) {
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
            .padding(.top, kPadding)
        }
        .padding(.horizontal, kPadding)
    }
    
    private func conditionButton(_ c: HoleCondition) -> some View {
        Button(action: {
            details.conditions.toggle(c)
            Haptics.fire(.light)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(details.conditions.contains(c) ? Color.systemGreen.opacity(0.125) : Color.systemGray6.opacity(0.2))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(
                            details.conditions.contains(c) ? Color.systemGreen : Color.systemGray2,
                            lineWidth: details.conditions.contains(c) ? 4 : 2)
                    )
                VStack(spacing: kPadding) {
                    AwesomeImage(
                        icon: c.icon,
                        style: .regular,
                        size: 30,
                        color: details.conditions.contains(c) ? Color.systemGreen : Color.systemGray2)
                    Text("\(c.displayName)")
                        .font(.dmSans(size: 22, weight: .medium))
                        .foregroundColor(details.conditions.contains(c) ? Color.systemGreen : Color.systemGray2)
                }
            }
        }
    }
    
    private func save() {
        if let action = onSave {
            action!(details)
        }
        dismiss()
    }
}

struct HoleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        HoleDetailView(hole: 1)
    }
}
