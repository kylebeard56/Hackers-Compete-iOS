//
//  View.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
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

    /// Resign keyboard on tap, except when the given condition is true (e.g. when a handicap field is focused).
    func resignKeyboardOnTapGesture(exceptWhen condition: Bool) -> some View {
        return modifier(ResignKeyboardOnTap(exceptWhen: condition))
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
    
    /// Applies a light mode preferred color scheme for an iPhone 14 Pro will appropriate preview name.
    func lightModePreview() -> some View {
        return modifier(LightModePreview())
    }
    
    /// Applies a dark mode preferred color scheme for an iPhone 14 Pro will appropriate preview name.
    func darkModePreview() -> some View {
        return modifier(DarkModePreview())
    }
    
    /// Applies iPhone 14
    func notchDevicePreview() -> some View {
        return modifier(NotchDevicePreview())
    }
    
    /// Applies iPhone SE
    func smallDevicePreview() -> some View {
        return modifier(SmallDevicePreview())
    }
    
    /// Applies all four preview styles
    func holisticPreview() -> some View {
        return modifier(HolisticPreview())
    }
}

extension View {
    /// A task modifier that waits for the specified delay before running the async action.
    func task(
        delay seconds: TimeInterval,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        self.task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await action()
        }
    }
}
