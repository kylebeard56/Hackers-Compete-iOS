//
//  .swift
//  Hackers
//
//  Created by Kyle Beard on 7/3/24.
//

import SwiftUI

protocol Tippable {
    var id: String { get }
    var icon: String { get }
    var title: String { get }
    var subtitle: String { get }
}

struct Tooltip: Equatable {
    var data: Tippable
    var priority: Int
    var canBeShown: Bool
    var position: Position
    var appearanceMargin: CGFloat
    
    init(
        data: Tippable,
        priority: Int,
        canBeShown: Bool,
        position: Position = Position(),
        appearanceMargin: CGFloat = 0.00
    ) {
        self.data = data
        self.priority = priority
        self.canBeShown = canBeShown
        self.position = position
        self.appearanceMargin = appearanceMargin
    }
    
    // Must be within 5% margins of screen width and height
    var isInFrame: Bool {
        let xMargin = 0.00
        let yMargin = appearanceMargin
        
        let minX = UIScreen.main.bounds.width * xMargin
        let maxX = UIScreen.main.bounds.width * (1 - xMargin)
        let minY = UIScreen.main.bounds.height * yMargin
        let maxY = UIScreen.main.bounds.height * (1 - yMargin)
        
        let bottomSafe = position.maxY <= maxY
        let topSafe = position.minY >= minY
        
        let leadingSafe = position.minX >= minX
        let trailingSafe = position.maxX <= maxX
        
        print("""
        
        Tip frame for \(data.id):
        Top........ \(topSafe)
        Bottom..... \(bottomSafe)
        Leading.... \(leadingSafe)
        Trailing... \(trailingSafe)
        IsInFrame.. \(bottomSafe && leadingSafe && trailingSafe)
        """)
        
        /// NOTE: I'm learning that topSafe is always going to be ok since it'll show onAppear()
        return bottomSafe && leadingSafe && trailingSafe //&& topSafe
    }
    
    var isReady: Bool {
        return canBeShown && isInFrame
    }
    
    static func == (lhs: Tooltip, rhs: Tooltip) -> Bool {
        lhs.data.id == rhs.data.id
        && lhs.priority == rhs.priority
        && lhs.canBeShown == rhs.canBeShown
        && lhs.position == rhs.position
    }
}

struct TipCard: View {
    @Environment(\.colorScheme) var colorScheme

    /// Information to present about this tooltip
    var tip: Tooltip
    
    /// Foreground style for the icon
    var iconColor: Color = Color.systemBlack
    
    /// Foreground style for the title
    var titleColor: Color = Color.systemBlack
    
    /// Foreground style for the subtitle
    var subtitleColor: Color = Color.systemGray
    
    /// Foreground style for the call to action button
    var nextColor: Color = Color.systemBlue
    
    /// Optional color to fill the card (is presented in ZStack behind the blur)
    var tint: Color?

    /// Toggle to show gaussian blur or not. Will also remove shadow.
    var blur: Bool = true

    /// Ignore any calculations for y-offsets
    var ignoreOffsets: Bool = false

    /// Optionally force where the caret is shown, regardless of tip position
    var forceCaret: CaretPosition?

    /// Show x in top-right corner
    var showClose: Bool = false

    /// Show next in bottom-right corner
    var showNext: Bool = false

    /// Callback when the user taps the close button
    var onClose: (() -> Void)?
    
    /// Callback when user taps the next button
    var onNext: (() -> Void)?

    @State private var card: Position = .zero
    private let tipWidth = UIScreen.main.bounds.width - 32

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if showNext {
                    triggerOnNext()
                }
                if showClose {
                    triggerOnClose()
                }
                Haptics.fire(.light)
            }) {
                HStack(spacing: 16) {
                    if !tip.data.icon.isEmpty {
                        Icon(name: tip.data.icon, size: 32, weight: .light)
                            .foregroundStyle(iconColor)
                    }
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text(tip.data.title)
                                .font(.dmSans, size: 15, weight: .bold)
                                .foregroundStyle(titleColor)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            if showClose {
                                Icon(name: "xmark", size: 12, weight: .bold)
                                    .foregroundColor(Color.systemGray2)
                            }
                        }

                        Text(tip.data.subtitle)
                            .font(.dmSans, size: 13, weight: .medium)
                            .foregroundStyle(subtitleColor)
                            .minimumScaleFactor(0.6)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .alignLeading()

                        if showNext {
                            Text("Next")
                                .font(.dmSans, size: 13, weight: .bold)
                                .foregroundStyle(nextColor)
                                .alignTrailing()
                        }
                    }
                }
            }
            .padding(padding)
            .background(background)
            .frame(width: tipWidth)
            .clipShape(TipShape(caretPosition: caretPosition, offset: offsetX))
            .offset(y: offsetY)
            .shadow(color: Color.systemBlack.opacity(shadowOpacity), radius: 8, x: 0, y: 0)
        }
        .observePosition(onChange: { c in card = c })
        .onAppear() {
            print("[TIP] \(tip), next: \(showNext), close: \(showClose)")
        }
    }
    
    private var shadowOpacity: CGFloat {
        blur
        ? colorScheme == .light
        ? 0.16 : 0.04
        : 0.0
    }

    private var background: some View {
        ZStack {
            if let tint { tint }
            if blur { Blur(style: colorScheme == .light ? .systemMaterial : .systemMaterialDark) }
        }
    }

    private var caretPosition: CaretPosition {
        if let forceCaret { return forceCaret }
        return UIScreen.main.bounds.height / 2 >= tip.position.midY ? .top : .bottom
    }

    private var padding: EdgeInsets {
        if caretPosition == .top {
            return EdgeInsets(top: 28, leading: 16, bottom: 12, trailing: 16)
        } else {
            return EdgeInsets(top: 12, leading: 16, bottom: 28, trailing: 16)
        }
    }

    private var offsetX: CGFloat {
        return tip.position.midX - 32
    }

    private var offsetY: CGFloat {
        printPretty(tip.position)
        if ignoreOffsets { return 0 }
        if caretPosition == .top {
            return tip.position.minY + tip.position.height + 16
        } else {
            return tip.position.minY - card.height - 16
        }
    }
}

extension TipCard {
    fileprivate func triggerOnClose() {
        if let action = onClose {
            action()
        }
    }

    func onClose(perform action: @escaping () -> Void) -> Self {
        var c = self
        c.onClose = action
        return c
    }

    fileprivate func triggerOnNext() {
        if let action = onNext {
            action()
        }
    }

    func onNext(perform action: @escaping () -> Void) -> Self {
        var c = self
        c.onNext = action
        return c
    }
}

enum CaretPosition {
    case top, bottom
}

struct TipShape: Shape {
    var caretPosition: CaretPosition = .top
    var offset: CGFloat = 0.0
    
    func path(in rect: CGRect) -> Path {
        let radius = 12.0
        let triRadius = 4.0
        
        let triHeight = 16.0
        let triMiddle = 16.0
        let triBase = triMiddle * 2

        let rightMost = rect.width - triBase
        
        // guard offset between 0 and rect.width
        var caretOffset = min(max(0, offset), rightMost)

        // Offset can't be closer to edge than radius, guard 0 == offset or > radius
        if caretOffset < radius + 1 {
            caretOffset = caretOffset < (radius / 2) ? 0 : radius + 1
        } else if caretOffset > (rightMost - radius - 1) {
            caretOffset = caretOffset > rightMost - (radius / 2) ? rightMost : rightMost - radius - 1
        }
        
        let triRightX = triBase + caretOffset
        let triMiddleX = triMiddle + caretOffset
        let triLeftX = caretOffset
        let triTipY = caretPosition == .top ? 0 : rect.height
        let triBaseY = caretPosition == .top ? triHeight : rect.height - triHeight
        
        let triLeftXY = CGPoint(x: triLeftX, y: triBaseY)
        let triRightXY = CGPoint(x: triRightX, y: triBaseY)
        let triPointXY = CGPoint(x: triMiddleX, y: triTipY)
        
        let TL =  CGPoint(x: 0, y: caretPosition == .top ? triHeight : 0)
        let BL =  CGPoint(x: 0, y: caretPosition == .top ? rect.height : rect.height - triHeight)
        let BR =  CGPoint(x: rect.width, y: caretPosition == .top ? rect.height : rect.height - triHeight)
        let TR =  CGPoint(x: rect.width, y: caretPosition == .top ? triHeight : 0)
        
        var path = Path()
        
        // Caret on top
        if caretPosition == .top {
            path.addArc(tangent1End: BL, tangent2End: BR, radius: radius)
            path.addArc(tangent1End: BR, tangent2End: TR, radius: radius)
            if triRightX != rect.width {
                path.addArc(tangent1End: TR, tangent2End: triRightXY, radius: radius)
            }
            
            path.addArc(tangent1End: triRightXY, tangent2End: triPointXY, radius: radius)
            path.addArc(tangent1End: triPointXY, tangent2End: triLeftXY, radius: triRadius)
            
            if triLeftX != 0 {
                path.addArc(tangent1End: triLeftXY, tangent2End: TL, radius: radius)
            }
            
            path.addArc(tangent1End: TL, tangent2End: BL, radius: radius)
        } else {
            if triLeftX != 0 {
                path.addArc(tangent1End: BL, tangent2End: triLeftXY, radius: radius)
            }
            path.addArc(tangent1End: triLeftXY, tangent2End: triPointXY, radius: radius)
            path.addArc(tangent1End: triPointXY, tangent2End: triRightXY, radius: triRadius)
            
            if triRightX != rect.width {
                path.addArc(tangent1End: triRightXY, tangent2End: BR, radius: radius)
            }
            
            path.addArc(tangent1End: BR, tangent2End: TR, radius: radius)
            path.addArc(tangent1End: TR, tangent2End: TL, radius: radius)
            path.addArc(tangent1End: TL, tangent2End: BL, radius: radius)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

@available(iOS 17, *) private struct ClickableTipPreview: View {
    private struct PreviewTip: Tippable {
        var id: String { "example_id" }
        var icon: String { "f0eb" }
        var title: String { "This is a title" }
        var subtitle: String { "This is a description that can span multiple lines for instructions." }
    }
    @State private var tip = Tooltip(
        data: PreviewTip(),
        priority: 1,
        canBeShown: true,
        position: Position(x: UIScreen.main.bounds.width - 36, y: 64, width: 20, height: 20)
    )

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.systemPurple, .systemBlue, .systemGreen],
                startPoint: .top,
                endPoint: .bottom
            )
            .onTapGesture { loc in
                withAnimation {
                    tip.position = CGRect(x: loc.x - 10, y: loc.y - 10, width: 20, height: 20)
                }
            }

            Icon(name: "star", weight: .semibold)
                .frame(width: tip.position.width, height: tip.position.height, alignment: .center)
                .position(x: tip.position.midX, y: tip.position.midY)

            TipCard(tip: tip)
        }
        .ignoresSafeArea(edges: .all)
    }
}

@available(iOS 17, *) private struct FlowTipPreview: View {
    var animated: Bool

    private enum PreviewTip: Tippable {
        case favorite, menu, button, plus
        var id: String {
            switch self {
            case .favorite:     return "favorite"
            case .menu:         return "menu"
            case .button:       return "inline"
            case .plus:         return "plus"
            }
        }
        
        var icon: String {
            switch self {
            case .favorite:     return "f005"
            case .menu:         return "f013"
            case .button:       return "f0a6"
            case .plus:         return "f044"
            }
        }
        
        var title: String {
            switch self {
            case .favorite:     return "Save to favorites"
            case .menu:         return "Manage your profile"
            case .button:       return "Tap this button"
            case .plus:         return "Write something new"
            }
        }

        var subtitle: String {
            switch self {
            case .favorite:     return "Store this view for future discovery"
            case .menu:         return "Manage your information and notification preferences"
            case .button:       return "Tap this button to do something really cool or make something happen."
            case .plus:         return "Tap this button to open a new draft"
            }
        }
    }

    @State private var favorite = Tooltip(
        data: PreviewTip.favorite,
        priority: 1,
        canBeShown: true,
        position: Position()
    )

    @State private var menu = Tooltip(
        data: PreviewTip.menu,
        priority: 2,
        canBeShown: true,
        position: Position()
    )

    @State private var button = Tooltip(
        data: PreviewTip.button,
        priority: 3,
        canBeShown: true,
        position: Position()
    )

    @State private var plus = Tooltip(
        data: PreviewTip.plus,
        priority: 4,
        canBeShown: true,
        position: Position(),
        appearanceMargin: 0.2
    )

    var body: some View {
        ZStack(alignment: .top) {
            Color.systemViewBackground.ignoresSafeArea(edges: .all)

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Icon(name: "star", weight: .semibold)
                            .foregroundStyle(Color.systemBlack)
                            .observePosition(onChange: { p in
                                if animated {
                                    withAnimation { favorite.position = p }
                                    return
                                }
                                favorite.position = p
                            })

                        Spacer()

                        Text("Embedded tips")
                            .font(.dmSans, size: 17, weight: .bold)

                        Spacer()

                        // Bars
                        Icon(name: "f0c9")
                            .foregroundStyle(Color.systemBlack)
                            .observePosition(onChange: { p in
                                if animated {
                                    withAnimation { menu.position = p }
                                    return
                                }
                                menu.position = p
                            })
                    }

                    if favorite.isReady {
                        TipCard(
                            tip: favorite,
                            tint: Color.systemGray6,
                            blur: false,
                            ignoreOffsets: true,
                            forceCaret: .top,
                            showClose: true
                        )
                        .onClose {
                            Haptics.fire(.light)
                            withAnimation { favorite.canBeShown = false }
                        }
                    } else if menu.isReady {
                        TipCard(
                            tip: menu,
                            tint: Color.systemGray6,
                            blur: false,
                            ignoreOffsets: true,
                            forceCaret: .top,
                            showClose: true
                        )
                        .onClose {
                            Haptics.fire(.light)
                            withAnimation { menu.canBeShown = false }
                        }
                    }

                    Text("Welcome")
                        .font(.dmSans, size: 34)
                        .bold()
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()

                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                        .font(.dmSans, size: 12)
                        .foregroundStyle(Color.systemGray)
                        .alignLeading()

                    SmallButton(
                        title: "I'm a button",
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .observePosition(onChange: { p in
                        if animated {
                            withAnimation { button.position = p }
                            return
                        }
                        button.position = p
                    })

                    if button.isReady {
                        TipCard(
                            tip: button,
                            tint: Color.systemGray6,
                            blur: false,
                            ignoreOffsets: true,
                            forceCaret: .top,
                            showClose: true
                        )
                        .onClose {
                            print("close inline")
                            Haptics.fire(.light)
                            withAnimation {
                                button.canBeShown = false
                            }
                        }
                    }

                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Sed tempus urna et pharetra pharetra massa massa ultricies. Arcu bibendum at varius vel. Cursus euismod quis viverra nibh cras pulvinar mattis nunc sed. Et malesuada fames ac turpis egestas sed tempus. Egestas integer eget aliquet nibh praesent tristique. Velit egestas dui id ornare arcu odio. Tellus in metus vulputate eu scelerisque felis imperdiet proin. Amet volutpat consequat mauris nunc congue. Rhoncus mattis rhoncus urna neque. Viverra nam libero justo laoreet sit amet cursus sit. Adipiscing elit duis tristique sollicitudin nibh sit amet. Scelerisque eu ultrices vitae auctor eu augue ut. Convallis aenean et tortor at risus viverra adipiscing. Scelerisque varius morbi enim nunc faucibus a pellentesque.")
                        .font(.inter, size: 12)
                        .foregroundStyle(Color.systemGray)
                        .alignLeading()

                    Divider()
                        .padding(.vertical, 16)

                    HStack {
                        Text("Write something new")
                            .font(.dmSans, size: 17, weight: .bold)
                            .foregroundStyle(Color.systemBlack)

                        Spacer()

                        Icon(name: "plus", weight: .semibold)
                            .observePosition(onChange: { p in
                                if animated {
                                    withAnimation { plus.position = p }
                                    return
                                }
                                plus.position = p
                            })
                    }

                    if plus.isReady {
                        TipCard(
                            tip: plus,
                            tint: Color.systemGray6,
                            blur: false,
                            ignoreOffsets: true,
                            forceCaret: .top,
                            showClose: true
                        )
                        .onClose {
                            Haptics.fire(.light)
                            withAnimation {
                                plus.canBeShown = false
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(0..<19, id: \.self) { _ in
                            VStack(spacing: 2) {
                                Text("Loren ipsum")
                                    .font(.dmSans, size: 12)
                                    .bold()
                                    .foregroundStyle(Color.systemBlack)
                                    .alignLeading()
                                Text("Arcu bibendum at varius vel. Cursus euismod quis viverra nibh cras pulvinar mattis nunc sed.")
                                    .font(.dmSans, size: 11)
                                    .foregroundStyle(Color.systemGray)
                                    .alignLeading()
                            }
                            Divider()
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

@available(iOS 17, *) private struct OverlayTipPreview: View {
    private enum PreviewTip: Tippable {
        case favorite, menu, button, plus
        var id: String {
            switch self {
            case .favorite:     return "favorite"
            case .menu:         return "menu"
            case .button:       return "inline"
            case .plus:         return "plus"
            }
        }

        var icon: String {
            switch self {
            case .favorite:     return "f005"
            case .menu:         return "f013"
            case .button:       return "f0a6"
            case .plus:         return "f044"
            }
        }

        var title: String {
            switch self {
            case .favorite:     return "Save to favorites"
            case .menu:         return "Manage your profile"
            case .button:       return "Tap this button"
            case .plus:         return "Write something new"
            }
        }

        var subtitle: String {
            switch self {
            case .favorite:     return "Store this view for future discovery"
            case .menu:         return "Manage your information and notification preferences"
            case .button:       return "Tap this button to do something really cool or make something happen."
            case .plus:         return "Tap this button to open a new draft"
            }
        }
    }

    @State private var tips: [Tooltip] = [
        Tooltip(
            data: PreviewTip.favorite,
            priority: 1,
            canBeShown: true,
            position: Position()
        ),
        Tooltip(
            data: PreviewTip.menu,
            priority: 2,
            canBeShown: true,
            position: Position()
        ),
        Tooltip(
            data: PreviewTip.button,
            priority: 3,
            canBeShown: true,
            position: Position()
        ),
        Tooltip(
            data: PreviewTip.plus,
            priority: 4,
            canBeShown: true,
            position: Position(),
            appearanceMargin: 0.05
        )
    ]

    @State private var activeTip: Tooltip?
    @State private var activates: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.systemViewBackground.ignoresSafeArea(edges: .all)

            ScrollViewReader { proxy in
                content
            }

            if let activeTip, activates {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.05)

                    TipCard(
                        tip: activeTip,
                        showClose: tips.last?.data.id == activeTip.data.id,
                        showNext: tips.last?.data.id != activeTip.data.id,
                        onClose: onClose,
                        onNext: onNext
                    )
                }
                .ignoresSafeArea(edges: .all)
            }
        }
        .onChange(of: tips) { _ in
            if activates && activeTip == nil {
                withAnimation {
                    getNextTip()
                }
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Icon(name: "star", weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .observePosition(onChange: { p in tips[0].position = p })

                    Spacer()

                    Text("Embedded tips")
                        .font(.dmSans, size: 17, weight: .bold)

                    Spacer()

                    // Bars
                    Icon(name: "f0c9")
                        .foregroundStyle(Color.systemBlack)
                        .observePosition(onChange: { p in tips[1].position = p })
                }

                Text("Welcome")
                    .font(.dmSans, size: 34)
                    .bold()
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()

                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                    .font(.dmSans, size: 12)
                    .foregroundStyle(Color.systemGray)
                    .alignLeading()

                SmallButton(
                    title: "Tap me to see tips",
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    withAnimation {
                        activates = true
                        getNextTip()
                    }
                }
                .observePosition(onChange: { p in tips[2].position = p })

                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Sed tempus urna et pharetra pharetra massa massa ultricies. Arcu bibendum at varius vel. Cursus euismod quis viverra nibh cras pulvinar mattis nunc sed. Et malesuada fames ac turpis egestas sed tempus. Egestas integer eget aliquet nibh praesent tristique.")
                    .font(.dmSans, size: 12)
                    .foregroundStyle(Color.systemGray)
                    .alignLeading()

                Divider()
                    .padding(.vertical, 16)

                Text("Your stories")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()

                VStack(spacing: 8) {
                    ForEach(0..<9, id: \.self) { _ in
                        VStack(spacing: 2) {
                            Text("Loren ipsum")
                                .font(.dmSans, size: 12)
                                .bold()
                                .foregroundStyle(Color.systemBlack)
                                .alignLeading()
                            Text("Arcu bibendum at varius vel. Cursus euismod quis viverra nibh cras pulvinar mattis nunc sed.")
                                .font(.dmSans, size: 11)
                                .foregroundStyle(Color.systemGray)
                                .alignLeading()
                        }
                        Divider()
                    }
                }

                HStack {
                    Text("Write something new...")
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundStyle(Color.systemBlue)

                    Spacer()

                    Icon(name: "plus", weight: .semibold)
                        .foregroundStyle(Color.systemBlue)
                        .observePosition(onChange: { p in tips[3].position = p })
                }
            }
            .padding(16)
        }
    }

    private func onClose() {
        print(#function)
        withAnimation {
            if let i = tips.firstIndex(where: { $0.data.id == activeTip?.data.id }) {
                tips[i].canBeShown = false
                self.activeTip = nil
                activates = false
            } else {
                print("cannot go to next tip")
            }
        }
    }

    private func onNext() {
        withAnimation {
            if let i = tips.firstIndex(where: { $0.data.id == activeTip?.data.id }) {
                tips[i].canBeShown = false
                getNextTip()
            } else {
                print("cannot go to next tip")
            }
        }
    }

    private func getNextTip() {
        activeTip = tips.sorted(by: { $0.priority < $1.priority }).first(where: \.isReady)
    }
}

#Preview("Clickable") {
    if #available(iOS 17, *) {
        ClickableTipPreview()
    } else {
        EmptyView()
    }
}

#Preview("Flow") {
    if #available(iOS 17, *) {
        FlowTipPreview(animated: true)
    } else {
        EmptyView()
    }
}

#Preview("Overlay") {
    if #available(iOS 17, *) {
        OverlayTipPreview()
    } else {
        EmptyView()
    }
}

