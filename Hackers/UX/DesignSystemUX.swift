//
//  DesignSystemUX.swift
//  Hackers
//
//  Created by Kyle Beard on 10/2/25.
//

import Flow
import SwiftUI

/**
 COLOR NOTES
 
 Button against white BG is gray6 / gray4
 Button against superlight gray is card
 */

struct DesignSystemUX: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        StickyScrollView(
            header: { headerContent },
            content: { scrollableContent },
            footer: { footerContent },
            background: .boxFoxBackground,
            onScroll: { _ in }
        )
//        .background(Color.boxFoxBackground)
    }

    // MARK: - Subviews
    
    private var headerContent: some View {
        HStack(spacing: 16) {
            HStack(spacing: 16) {
                NavButton()
                
                Text("Home")
                    .fontStyle(.poppins, size: 28, weight: .bold)
                    .foregroundStyle(Color.boxFoxForeground)
            }
            Spacer(minLength: 0)
            NavButton(icon: "f004", weight: .regular)
            NavButton(icon: "f2bd", weight: .regular)
            NavButton(icon: "f0c9", weight: .regular)
        }
        .padding(.horizontal, 16)
    }
    
    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 0)
                // Scroll view with tiles
                // ingrain info with lists
                ZStack {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Card title".uppercased())
                                .fontStyle(.poppins, size: 15, weight: .semibold)
                                .foregroundStyle(Color.boxFoxGray)
                            
                            Spacer(minLength: 0)
                            
                            Text("Info or button")
                                .fontStyle(.poppins, size: 15, weight: .medium)
                                .foregroundStyle(Color.boxFoxGray2)
                        }
                        
                        Line(color: colorScheme.set(.gray6, .gray5))
                        
                        VStack(spacing: 4) {
                            Text("Heading")
                                .fontStyle(.poppins, size: 28, weight: .semibold)
                                .foregroundStyle(Color.boxFoxForeground)
                                .alignLeading()
                            
                            Text("Subheading")
                                .fontStyle(.poppins, size: 22, weight: .semibold)
                                .foregroundStyle(Color.boxFoxCharcoal)
                                .alignLeading()
                            
                            Text("Body of text")
                                .fontStyle(.poppins)
                                .foregroundStyle(Color.boxFoxGray)
                                .alignLeading()
                            
                            Text("Subtext")
                                    .fontStyle(.poppins, size: 15)
                                .foregroundStyle(Color.boxFoxGray2)
                                .alignLeading()
                            
                            Text("Footnote")
                                    .fontStyle(.poppins, size: 13)
                                .foregroundStyle(Color.boxFoxGray3)
                                .alignLeading()
                            
                            /// GRAY 4 OR LOWER ARE TOO LIGHT FOR TEXT AND SHOULD BE BUTTON BACKGROUNDS
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .background(Color.boxFoxCard)
                .cornerRadius(12)
                
                HackersCard(
                    title: "Loading",
                    callToAction: { EmptyView() },
                    content: { EmptyView() },
                    isLoading: .true
                )
                
                HackersCard(
                    icon: "e1d8",
                    title: "Notes or instructions",
                    callToAction: { EmptyView() },
                    content: {
                        HFlow(spacing: 8) {
                            Chip(text: "Today")
                            Chip(text: "Tomorrow", style: .outline)
                            Chip(text: "Thursday", style: .outline)
                            Chip(text: "Friday", style: .outline)
                            Chip(text: "Saturday", style: .outline)
                            Chip(text: "See more dates", icon: "2b", style: .outline)
                        }
                        .alignLeading()
                        
                        SecondaryButton(text: "See more", isDisabled: .false, isLoading: .false)
                            .padding(.top, 16)
                    }
                )
                
                HackersCard(
                    title: "Your week",
                    callToAction: { Chip(text: "Oct 20-26", weight: .semibold, size: .xSmall, style: .fill) },
                    content: {
                        ForEach(0...3, id: \.self) { i in
                            HStack(spacing: 16) {
                                if i == 0 {
                                    Icon(name: "f058", size: 20, maxSize: 20, weight: .solid)
                                        .foregroundStyle(Color.boxFoxForeground)
                                } else {
                                    Circle()
                                        .stroke(Color.boxFoxGray4, lineWidth: 1)
                                        .frame(width: 20, height: 20)
                                }
                                
                                Text("Some checklist text")
                                    .fontStyle()
                                    .foregroundColor(Color.boxFoxForeground)
                                    .alignLeading()
                            }
                            
                            Line()
                                .padding(.leading, 36)
                        }
                        
                        SecondaryButton(text: "See your calendar", isDisabled: .false, isLoading: .false, onTap: {})
                            .padding(.top, 16)
                    }
                )
                
                HackersCard(
                    icon: "e1d8",
                    title: "Notes",
                    headerStyle: .primary,
                    callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
                    content: { EmptyView() }
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var footerContent: some View {
        VStack(spacing: 16) {
            Line()
            
            PrimaryButton(
                appearance: .fill,
                title: "Call to action",
                labelColor: .boxFoxBackground,
                buttonColor: .boxFoxForeground,
                isDisabled: .false,
                isLoading: .false,
                onTap: {}
            )
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    DesignSystemUX()
}
