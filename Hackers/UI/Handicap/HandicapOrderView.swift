//
//  HandicapOrderView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/26/24.
//

import SwiftUI

struct HandicapOrderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var order: [Int] = []
    @State private var remaining: [Int] = []
    
    private var holes: [Int] { roundSession.holeRange.sorted(by: { $0 < $1 }) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    content
                    Spacer(minLength: 0).frame(height: 40)
                }
                
                VStack(spacing: 20) {
                    Divider()
                    
                    SmallButton(
                        title: "Clear order",
                        isDisabled: .constant(order.isEmpty),
                        isLoading: .false
                    )
                    .onTap {
                        remaining = holes
                        order = []
                    }
                    .padding(.horizontal, 20)
                    
                    BigButton(
                        title: "Save order",
                        isDisabled: .constant(order.count != roundSession.holeRange.count),
                        isLoading: .false
                    )
                    .onTap {
                        roundSession.session?.handicapHoleOrder = order
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 20)
            .background(Color.systemViewBackground)
            .environmentObject(roundSession)
            .navigationTitle("Handicap hole order")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton(icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
            .onAppear() {
                if let o = roundSession.session?.handicapHoleOrder, !o.isEmpty {
                    order = o
                    remaining = roundSession.holeRange.difference(from: order)
                } else {
                    order = []
                    remaining = holes
                }
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 40) {
//            ZStack {
//                Text("Hole order")
//                    .font(.dmSans, size: 28, weight: .bold)
//                    .foregroundColor(Color.systemBlack)
//                    .alignCenter()
//
//                BackButton( icon: .xmark, onTap: { dismiss() })
//                    .alignTrailing()
//            }
//            .padding(.bottom, 10)
            
            Text("Tap holes in the order as they appear on your scorecard from **hardest (1)** to **easiest (\(roundSession.holeRange.max() ?? 18))**.")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans, size: 17, weight: .regular)
                .minimumScaleFactor(0.8)
                .alignLeading()
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            if !remaining.isEmpty {
                buttonGrid
            }
            
            if !order.isEmpty {
                buttonList
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private var buttonGrid: some View {
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)
        
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(remaining, id: \.self) { hole in
                Button(action: {
                    set(hole)
                    Haptics.fire(.light)
                }) {
                    Text("\(hole)")
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(Color.systemHackersGreen)
                        .padding(.vertical, 8)
                        .alignCenter()
                        .background(Color.systemHackersGreen.opacity(colorScheme.translucent))
                        .border(Color.systemHackersGreen, width: 2, cornerRadius: 8)
                }
            }
        }
    }
    
    @ViewBuilder private var buttonList: some View {
        VStack(spacing: 20) {
            Text("Hole order (hardest to easiest)")
                .font(.dmSans, size: 15, weight: .medium)
                .foregroundColor(Color.systemGray)
                .alignLeading()
            
            VStack(spacing: 10) {
                ForEach(Array(zip(order.indices, order)), id: \.0) { index, hole in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.dmSans, size: 15, weight: .medium)
                            .foregroundColor(Color.systemGray2)
                            .frame(width: 30)
                        
                        Text("Hole \(hole)")
                            .font(.dmSans, size: 20, weight: .medium)
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        Button(action: {
                            unset(hole)
                            Haptics.fire(.light)
                        }) {
                            Icon(name: "f00d", size: 15, weight: .regular)
                                .foregroundColor(Color.systemGray2)
                                .padding(4)
                        }
                    }
                    Divider()
                }
            }

        }
    }
    
    private func set(_ hole: Int) {
        //withAnimation(.linear(duration: 0.15)) {
            order.append(hole)
            remaining.removeAll(where: { $0 == hole })
            
            /// Pre-select k=last hole
            if let final = remaining.first, remaining.count == 1 {
                set(final)
            }
        //}
    }
    
    private func unset(_ hole: Int) {
        //withAnimation(.linear(duration: 0.015)) {
            order.removeAll(where: { $0 == hole })
            remaining.append(hole)
            remaining.sort(by: { $0 < $1 })
        //}
    }
}

struct HandicapOrderView_Previews: PreviewProvider {
    static var round = RoundSession()
    
    static var previews: some View {
        VStack { 
            Color.systemGray
        }.sheet(isPresented: .true) {
            HandicapOrderView()
                .presentationDragIndicator(.visible)
        }
        .environmentObject(round)
        .holisticPreview()
        .onAppear() {
            round.holeRange = Array(1...18)
        }
    }
}
