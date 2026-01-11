//
//  GameLobby+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

extension GameLobby {
    
    @ViewBuilder
    var courseSection: some View {
        if let courseSegment = snapshot.courseSegment {
            Text(courseSegment.courseInfo.name.uppercased())
                .fontStyle(.poppins, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .alignCenter()
            
            HStack(spacing: 32) {
                Spacer(minLength: 0)
                
                StackedSubtitle(value: numberOfHolesLabel(for: courseSegment), label: "holes")
                
                if let defaultTee = snapshot.defaultTee {
                    StackedSubtitle(value: "\(courseSegment.par(for: defaultTee))", label: "par")
                    StackedSubtitle(value: "\(defaultTee.name)", label: "tee")
                    StackedSubtitle(value: "\(defaultTee.yardage(for: snapshot.holeSegment))", label: "yards")
                } else {
                    StackedSubtitle(value: "???", label: "par")
                    StackedSubtitle(value: "???", label: "tee")
                    StackedSubtitle(value: "???", label: "yards")
                }
                
                Spacer(minLength: 0)
            }
            
            PrimaryButton(
                appearance: .fill,
                title: "Modify course".uppercased(),
                icon: "f303",
                iconWeight: .regular,
                buttonColor: .neutral6,
                theme: palette.theme,
                height: 40,
                fillWidth: false,
                iconSize: 15,
                fontSize: 15,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showCourseModificationView = true }
            )
            .matchedTransitionSource(id: "course", in: courseTransition)
        } else {
            // TODO: What do we put here if the course isn't set (highly unlikely) ??
        }
    }
    
    private func numberOfHolesLabel(for courseSegment: CourseSegment) -> String {
        let holes = courseSegment.courseInfo.totalHoles
        switch (holes, snapshot.holeSegment) {
        case (9, .front9):  return "Front 9"
        case (9, .back9):   return "Back 9"
        default:            return "\(holes)"
        }
    }
    
    private var teeAlertLabel: String {
        guard let defaultTee = snapshot.defaultTee else { return "" }
        var str = "\(defaultTee.yardage(for: snapshot.holeSegment)) yards\n"
        
        if let slope = defaultTee.slope(for: snapshot.holeSegment) {
            str += "\(slope) slope rating\n"
        }
        
        if let course = defaultTee.prettyRating(for: snapshot.holeSegment) {
            str += "\(course) course rating\n"
        }
        
        str += "\(defaultTee.difficultyScore(for: snapshot.holeSegment)) difficulty (out of 100)"
        
        return str
    }
}

extension GameLobby {
    func setCourseSegment(to segment: CourseSegment) {
        addBreadcrumb()
        printPretty(segment)
        Task {
            await roundService.setCourseSegment(to: segment)
            showCourseModificationView = false
        }
    }
}
