//
//  WhatsNewView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/3/23.
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
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
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack {
            HStack {
                Text("What's new")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Check out the latest features we've been *hacking* away on:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    // TODO: Create another view for welcome
//    private var headerNew: some View {
//        VStack {
//            HStack(alignment: .top) {
//                VStack {
//                    Text("Welcome to")
//                        .font(.fugazOne(size: 17))
//                        .foregroundColor(Color.systemBlack)
//                        .alignLeading()
//
//                    Text("Hackers")
//                        .font(.fugazOne(size: 40))
//                        .foregroundColor(Color.systemHackersGreen)
//                        .alignLeading()
//                }
//
//                Spacer(minLength: 0)
//
//                BackButton(icon: .xmark, onTap: {
//                    dismiss()
//                    Haptics.fire(.light)
//                })
//            }
//
//            Text("Updates in this version:")
//                .font(.dmSans(size: 17, weight: .medium))
//                .foregroundColor(Color.systemGray)
//                .multilineTextAlignment(.leading)
//                .alignLeading()
//        }
//    }
    
    // MARK: - Version Views
    
    private var content: some View {
        VStack(spacing: 8) {
            
        }
    }
}

struct WhatsNewView_Previews: PreviewProvider {
    static var view: some View {
        Color.systemWhite
            .sheet(isPresented: .true) {
                WhatsNewView()
                    .presentationDragIndicator(.visible)
            }
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
