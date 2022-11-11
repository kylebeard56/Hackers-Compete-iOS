//
//  MenuView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct MenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    @State private var showRuleEditor: Bool = false
    
    private var background: Color {
        colorScheme == .light ? .systemGray6 : .systemGray5
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            Button(action: { print("todo") }) {
                Text("Edit players")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
            .padding(.top, 8)
            
            if kAdminDeviceIDs.contains(deviceUUID) {
                Button(action: { showRuleEditor = true }) {
                    Text("Make new rule")
                        .font(.dmSans(size: 16, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                .padding()
                .frame(height: 50)
                .background(background)
                .cornerRadius(12)
            } else {
                Button(action: { print("todo") }) {
                    Text("Suggest new rule")
                        .font(.dmSans(size: 16, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                .padding()
                .frame(height: 50)
                .background(background)
                .cornerRadius(12)
            }
            
            Button(action: { print("todo") }) {
                Text("Discover golf formats")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
            
            Spacer(minLength: 0)
            
            Button(action: { appSession.endRound() }) {
                Text("End round")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemRed)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
        }
        .environmentObject(appSession)
        .padding(kPadding)
        .fullScreenCover(isPresented: $showRuleEditor) { RuleEditorView() }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(0..<100, id: \.self) { i in
                Text("Background")
            }
        }
        .sheet(isPresented: .true) {
            MenuView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}
