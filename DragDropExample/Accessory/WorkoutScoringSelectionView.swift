//
//  WorkoutScoringSelectionView.swift
//  BoxFox
//
//  Created by Kyle Beard on 2/15/23.
//

import SwiftUI

struct WorkoutScoringSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var type: ScoringType
    var name: String = "this workout"
    
    var body: some View {
        ScrollView {
            content
        }
        .alignTop()
        .background(Color.systemCard)
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("How is \(name) scored?")
                    .font(.dmSans(size: 17, weight: .bold))
                Button(action: { dismiss() }) {
                    AwesomeImage(icon: .xmark, style: .solid, size: 20, color: .systemBlack)
                }
                .alignTrailing()
            }
            .padding(.vertical, 8)
            
            Group {
                FoxDivider {
                    Text("TIME")
                        .font(.dmSans(size: 12, weight: .regular))
                        .foregroundColor(Color.systemGray3)
                }
                HStack(spacing: 16) {
                    tile(for: .speed)
                    tile(for: .endurnce)
                }
            }

            Group {
                FoxDivider {
                    Text("WORK")
                        .font(.dmSans(size: 12, weight: .regular))
                        .foregroundColor(Color.systemGray3)
                }
                HStack(spacing: 16) {
                    tile(for: .roundsReps)
                    tile(for: .reps)
                }
                HStack(spacing: 16) {
                    tile(for: .calories)
                    tile(for: .completion)
                }
            }

            Group {
                FoxDivider {
                    Text("STRENGTH")
                        .font(.dmSans(size: 12, weight: .regular))
                        .foregroundColor(Color.systemGray3)
                }
                HStack(spacing: 16) {
                    tile(for: .weightPounds)
                    tile(for: .weightKilos)
                }
                HStack(spacing: 16) {
                    tile(for: .loadPounds)
                    tile(for: .loadKilos)
                }
            }

            Group {
                FoxDivider {
                    Text("DISTANCE")
                        .font(.dmSans(size: 12, weight: .regular))
                        .foregroundColor(Color.systemGray3)
                }
                HStack(spacing: 16) {
                    tile(for: .kilometers)
                    tile(for: .meter)
                }
                HStack(spacing: 16) {
                    tile(for: .miles)
                    tile(for: .feet)
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    private func tile(for type: ScoringType) -> some View {
        Button(action: {
            self.type = type
            dismiss()
        }) {
            VStack(spacing: 4) {
                Group {
                    Text(type.name)
                        .font(.dmSans(size: 17, weight: .medium))
                    + Text("  \(type.subtitle)")
                        .font(.dmSans(size: 12, weight: .medium))
                }
                .foregroundColor(Color.systemBlack)
                .alignCenter()
            }
            .padding(12)
            .background(Color.systemIconBackground)
            .cornerRadius(4)
        }
    }
}

struct WorkoutScoringSelectionView_Previews: PreviewProvider {
    static var view: some View {
        VStack {
            Color.systemViewBackground
        }
        .sheet(isPresented: .true) {
            WorkoutScoringSelectionView(type: .constant(.speed))
                .presentationDetents([.large])
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
