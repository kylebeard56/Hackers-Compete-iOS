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
            VStack(spacing: 12) {
                VStack(spacing: 14) {
                    Text("Course".uppercased())
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                    
                    VStack(spacing: 4) {
                        Text(courseSegment.courseInfo.name.uppercased())
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                        
                        if let street = courseSegment.courseInfo.location?.streetName {
                            // TODO: Open GPS for directions in Apple/Google Maps
                            Text(street)
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
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
                    
                    Button {
                        Haptics.fire(.light)
                        showCourseModificationView = true
                    } label: {
                        Text("Modify course")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignCenter()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    }
                    .padding(.top, 16)
                }
                .padding(16)
                .glassCardEffect(forceMaterial: true)
//                .background(.ultraThinMaterial)
//                .cornerRadius(radius: 16)
                
//                GlassButton(
//                    title: "Modify course",
////                    icon: "f303",
////                    iconWeight: .regular,
//                    height: 40,
//                    fillWidth: false,
//                    iconSize: 15,
//                    fontSize: 15,
//                    isDisabled: .false,
//                    isLoading: .false,
//                    onTap: { showCourseModificationView = true }
//                )
//                .matchedTransitionSource(id: "course", in: courseTransition)
            }
        } else {
            VStack(spacing: 12) {
                VStack(spacing: 14) {
                    Text("Course".uppercased())
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()

                    Text("No course selected")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()

                    Button {
                        Haptics.fire(.light)
                        showCourseModificationView = true
                    } label: {
                        Text("Add course")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignCenter()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .glassCardEffect(forceMaterial: true)
            }
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
            await roundSession.setCourseSegment(to: segment)
            showCourseModificationView = false
        }
    }
}
