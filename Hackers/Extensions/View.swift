//
//  View.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

extension View {
    /// This modifier will add a border around an object as a RoundedRectangle overlay
    func border(_ color: Color, width: CGFloat, cornerRadius: CGFloat) -> some View {
        overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(color, lineWidth: width))
    }

    /// This modifier will resign any first responder keyboard when the view detects a tap gesture.
    func resignKeyboardOnTapGesture() -> some View {
        return modifier(ResignKeyboardOnTap())
    }

    /// This modifier will resign any first responder keyboard when the view detects a swipe/drag gesture.
    /// Note: If experiencing lack of gesture control or scrolling Capabilities, this modifier's placement
    ///       in the view stack could be the cause of your trouble.
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDrag())
    }

    /// Align a view component to the leading edge
    func alignLeading() -> some View {
        return modifier(AlignLeading())
    }

    /// Align a view component to the center and expand full width
    func alignCenter() -> some View {
        return modifier(AlignCenter())
    }

    /// Align a view component to the trailing edge
    func alignTrailing() -> some View {
        return modifier(AlignTrailing())
    }

    /// Align a view component to the top
    func alignTop() -> some View {
        return modifier(AlignTop())
    }

    /// Align a view component to the middle
    func alignMiddle() -> some View {
        return modifier(AlignMiddle())
    }

    /// Align a view component to the bottom
    func alignBottom() -> some View {
        return modifier(AlignBottom())
    }
    
    /// Add a shadow to a card
    func applyStandardShadow() -> some View {
        return modifier(Shadow())
    }
}
