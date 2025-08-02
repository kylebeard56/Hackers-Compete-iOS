//
//  CourseSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import SwiftUI

struct CourseSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText: String = ""
    
    var body: some View {
        VStack {
            Text("Navigation title")
            Text("Search bar")
            Text("Favorites, recent, nearby chips")
            
            Spacer(minLength: 0)
        }
        .background(Color.hackersBackground)
        .task {
            let courses = try? await GolfCourseAPI.shared.searchCourses(with: "cliffs mountain park")
            printPretty(courses)
            
            let ozarks = try? await GolfCourseAPI.shared.getCourse(by: 26780)
            printPretty(ozarks)
        }
    }
}

#Preview {
    CourseSelectionView()
}
