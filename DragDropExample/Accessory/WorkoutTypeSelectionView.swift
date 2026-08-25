//
//  WorkoutTypeSelectionView.swift
//  BoxFox
//
//  Created by Kyle Beard on 2/15/23.
//

import SwiftUI

struct WorkoutTypeSelectionView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var type: WorkoutType
//    var pickFromLibrary: Bool = true
//    var pickTapped: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            header
            
//            if pickFromLibrary {
//                Button(action: {
//                    if let p = pickTapped { p() }
//                    dismiss()
//                }) {
//                    HStack {
//                        AwesomeImage(icon: .books, style: .regular, size: 17, color: .systemOrange)
//                        .frame(width: 36, height: 36)
//                        .background(Color.systemIconBackground)
//                        .cornerRadius(4)
//
//                        Text("Pick from library")
//                            .font(.dmSans(size: 17, weight: .medium))
//                            .foregroundColor(Color.systemBlack)
//
//                        Spacer(minLength: 0)
//                    }
//                }
//
//                HStack(spacing: 16) {
//                    Rectangle()
//                        .fill(Color.systemGray5)
//                        .frame(height: 1)
//                    Text("OR PICK TYPE")
//                        .font(.dmSans(size: 12, weight: .regular))
//                        .foregroundColor(Color.systemGray3)
//                    Rectangle()
//                        .fill(Color.systemGray5)
//                        .frame(height: 1)
//                }
//            }
            
            row(for: .warmup)
            row(for: .strength)
            row(for: .metcon)
            row(for: .cardio)
            row(for: .cooldown)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.systemCard)
    }
    
    private var header: some View {
        ZStack {
            Text("Workout type")
                .font(.dmSans(size: 17, weight: .bold))
            Button(action: { dismiss() }) {
                AwesomeImage(icon: .xmark, style: .solid, size: 20, color: .systemBlack)
            }
            .alignTrailing()
        }
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private func row(for type: WorkoutType) -> some View {
        Button(action: {
            self.type = type
            dismiss()
        }) {
            HStack {
                Group {
                    if let i = type.icon.awesome {
                        AwesomeImage(icon: i, style: .regular, size: 20, color: type.color)
                    }
                    if let i = type.icon.system {
                        Image(systemName: i)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(type.color)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.systemIconBackground)
                .cornerRadius(4)

                Group {
                    Text(type.name)
                        .font(.dmSans(size: 17, weight: .medium))
                    + Text("  \(type.subtitle)")
                        .font(.dmSans(size: 13, weight: .medium))
                }
                .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
            }
        }
    }
}

struct WorkoutTypeSelectionView_Previews: PreviewProvider {
    static var view: some View {
        VStack {
            Color.systemViewBackground
        }
        .sheet(isPresented: .true) {
            WorkoutTypeSelectionView(type: .constant(.metcon))
                .presentationDetents([.height(360)])
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
