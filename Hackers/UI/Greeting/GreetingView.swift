//
//  GreetingView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/4/23.
//

import SwiftUI

struct GreetingView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            header
            content
            
            Spacer(minLength: 0)
            
            Button(action: {
                dismiss()
                Haptics.fire(.light)
            }) {
                Text("Done")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.systemCard)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(spacing: 0) {
                    Text("Welcome to")
                        .font(.fugazOne(size: 20))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()

                    Text("Hackers")
                        .font(.fugazOne(size: 48))
                        .foregroundColor(Color.systemHackersGreen)
                        .alignLeading()
                }

                Spacer(minLength: 0)

                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }

            Text("Here's what you need to know to get started:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var content: some View {
        VStack(spacing: UIScreen.isSmall ? 24 : 40) {
            row(
                icon: "e214",
                title: "Scorecard",
                detail: "Keep score live for each player in your party - this is optional, but a few games need it to play."
            )
            row(
                
                icon: "f451",
                title: "Games",
                detail: "Pick a game format to play with your party - swap back and forth without losing progress."
            )
            row(
                
                icon: "e31b",
                title: "Party codes",
                detail: "Have others join your round and sync up live by creating a party code - set this in the menu."
            )
        }
    }
    
    @ViewBuilder
    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 24) {
            AwesomeImage(rawIcon: icon.unicode, style: .regular, size: 32, color: .systemHackersGreen)
                .frame(width: 80, height: 80)
                .background(Color.systemHackersGreen.opacity(0.125))
                .cornerRadius(12)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                
                Text(detail)
                    .font(.dmSans(size: 15, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .alignLeading()
            }
        }
    }
}

struct GreetingView_Previews: PreviewProvider {
    static var view: some View {
        GreetingView()
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
//            view.notchDevicePreview()
//            view.smallDevicePreview()
        }
    }
}
