//
//  CourseSelectionConfirmation.swift
//  Hackers
//
//  Created by Kyle Beard on 8/9/25.
//

import SwiftUI

struct CourseSelectionConfirmation: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    
    @StateObject var viewModel: CourseSelectionViewModel
    
    private var course: GolfCourseAPIModel { viewModel.selectedCourse }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Apple Map with pin annotation of course
                NavButton(icon: "f00d", onTap: { dismiss() })
            }
            
            if course.isEmpty {
                Text("Unexpected error occurred")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
                    .alignCenter()
                    .alignMiddle()
            } else {
                content
            }
        }
    }
    
    
    // TODO: StickyScrollView?
    private var content: some View {
        VStack(spacing: 16) {
            Text(course.prettyClubName)
                .fontStyle(.poppins, size: 24, weight: .semibold)
                .foregroundStyle(Color.systemBlack)
                .alignLeading()
            
            Text("Step 1 of 4")
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.hackersGray)
                .alignLeading()
            
            // Course name
            // Course location | Distance (if location allowed)
            // Number of holes and par
            
            // Pick front, back, or 18
            
            // Pick default tee box for everyone from action sheet
            // Tee box w/ data
            
            // Continue CTA
        }
    }
}
