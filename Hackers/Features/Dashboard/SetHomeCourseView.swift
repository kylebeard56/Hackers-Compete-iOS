//
//  SetHomeCourseView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/28/26.
//

import SwiftUI

struct SetHomeCourseView: View {
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var onSaved: () -> Void
    
    @StateObject private var viewModel: CourseSelectionViewModel = {
        let vm = CourseSelectionViewModel()
        vm.isSetHomeCourseMode = true
        return vm
    }()
    
    var body: some View {
        CourseSelectionView(
            viewModel: viewModel,
            onCreation: nil,
            onModification: nil
        )
        .environmentObject(appSession)
        .environmentObject(roundSession)
        .task {
            viewModel.onSetHomeCourse = { apiID, name, teeID, _ in
                Task {
                    await Defaults.shared.setHomeCourseApiID(apiID)
                    await Defaults.shared.setHomeCourseName(name)
                    await Defaults.shared.setHomeCourseTeeID(teeID)
                    await MainActor.run { onSaved() }
                }
            }
        }
    }
}

#Preview {
    SetHomeCourseView(onSaved: {})
        .environmentObject(AppSession())
        .environmentObject(RoundSession())
}
