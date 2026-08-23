////
////  PackToggle.swift
////  Hackers
////
////  Created by Kyle Beard on 1/28/23.
////
//
//import SwiftUI
//
//struct PackSegmentControl: View {
//    @EnvironmentObject var appSession: AppSessionV2
//
//    @State private var labels: [String] = []=
//
//    var body: some View {
//        ZStack {
//            Rectangle()
//                .fill(Color.systemViewBackground)
//                .cornerRadius(12)
//            HStack(spacing: 0) {
//                ForEach(labels.indices, id: \.self) { i in
//                    let isSelected = appSession.gameTab == i
//                    Rectangle()
//                        .fill(Color.systemGray5)
//                        .cornerRadius(8)
//                        //.border(Color.systemGray5, width: 1, cornerRadius: 8)
//                        .clipped()
//                        .padding(6)
//                        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0), radius: 12, x: 0, y: 4)
//                        .opacity(isSelected ? 1 : 0.01)
//                        .onTapGesture {
//                            Haptics.fire(.light)
//                            withAnimation(.linear(duration: 0.125)) {
//                                appSession.gameTab = i
//                            }
//                        }
//                        .overlay(
//                            Text(labels[i])
//                                .font(.system(size: 15, weight: isSelected ? .medium : .medium))
//                                .foregroundColor(isSelected ? Color.systemBlack : Color.systemGray4)
//                        )
//                }
//            }
//        }
//        .environmentObject(appSession)
//        .frame(height: 40)
//        .onAppear() {
//            labels = ["Gameplay", "Drinking"]
////            packs = [appSession.gameplayPack, appSession.drinkingPack]
//        }
//    }
//}
//
//struct PackSegmentControl_Previews: PreviewProvider {
//    static let appSession = AppSessionV2()
//    static var previews: some View {
//        Group {
//            PackSegmentControl()
//                .padding(16)
//                .lightModePreview()
//                .environmentObject(appSession)
//            PackSegmentControl()
//                .padding(16)
//                .darkModePreview()
//                .environmentObject(appSession)
//        }
//    }
//}
