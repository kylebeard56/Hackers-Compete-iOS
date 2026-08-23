//
//  ViewModifier.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

/// Modifier for resigning first responder when view triggers a tap within the view.
struct ResignKeyboardOnTap: ViewModifier {
    var exceptWhen: Bool = false

    func body(content: Content) -> some View {
        content.onTapGesture {
            guard !exceptWhen else { return }
            UIApplication.shared.endEditing()
        }
    }
}

/// Modifier for resigning first responder when view triggers a drag gesture within the view.
struct ResignKeyboardOnDrag: ViewModifier {
    var gesture = DragGesture().onChanged({ _ in
        UIApplication.shared.endEditing()
    })
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

struct AlignLeading: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignCenter: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignTrailing: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content
        }
    }
}

struct AlignTop: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignMiddle: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignBottom: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content
        }
    }
}

struct LightModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.light)
            .previewDisplayName("15 Pro Light")
    }
}

struct DarkModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.dark)
            .previewDisplayName("15 Pro Dark")
    }
}

struct NotchDevicePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDisplayName("iPhone X")
            .preferredColorScheme(.light)
            .previewDevice("iPhone X")
    }
}

struct SmallDevicePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDisplayName("iPhone SE")
            .preferredColorScheme(.light)
            .previewDevice("iPhone SE (3rd generation)")
    }
}

struct HolisticPreview: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            content.lightModePreview()
            content.darkModePreview()
            content.notchDevicePreview()
            content.smallDevicePreview()
        }
    }
}
