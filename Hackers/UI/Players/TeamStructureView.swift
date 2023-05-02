//
//  TeamStructureView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

struct TeamStructureView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            content
            
            Spacer(minLength: 0)
            
            BigButton(
                title: "Set teams",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    dismiss()
                }
            )
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
        }
        .background(Color.systemViewBackground)
        .padding(.bottom, UIScreen.isSmall ? 8 : 0)
    }
    
    private var header: some View {
        VStack {
            HStack {
                Text("Setup teams")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Set your lineup for who plays with who:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var content: some View {
        VStack(spacing: 12) {
            // TODO: FIFA Xbox left/right organize here
        }
    }
}

struct TeamStructureView_Previews: PreviewProvider {
    static var view: some View {
        TeamStructureView(viewModel: RoundViewModel())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
