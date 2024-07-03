//
//  Position.swift
//  Hackers
//
//  Created by Kyle Beard on 7/3/24.
//

import Foundation
import SwiftUI

public typealias Position = CGRect

struct PositionKey: PreferenceKey {
    static var defaultValue: Position = .zero
    static func reduce(value: inout Position, nextValue: () -> Position) {
        value = nextValue()
    }
}

struct PositionObservation: ViewModifier {
    var onChange: ((Position) -> Void)
    
    @State private var position: Position = Position()
    
    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear() { update(with: geo.frame(in: .global)) }
                        .preference(key: PositionKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(PositionKey.self, perform: { update(with: $0) })
    }
    
    private func update(with frame: CGRect) {
        print("""
        
        Position update:
        minX: \(frame.minX)
        midX: \(frame.midX)
        maxX: \(frame.maxX)
        minY: \(frame.minY)
        midY: \(frame.midY)
        maxY: \(frame.maxY)
        width: \(frame.width)
        height: \(frame.height)
        
        """)
        
        onChange(frame)
    }
}

extension View {
    func observePosition(onChange: @escaping (Position) -> Void) -> some View {
        return modifier(PositionObservation(onChange: onChange))
    }
}
