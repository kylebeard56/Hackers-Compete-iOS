//
//  Binding.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

extension Binding where Value == Bool {
    static prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { !value.wrappedValue },
            set: { value.wrappedValue = !$0 }
        )
    }

    static func && (_ lhs: Binding<Bool>, _ rhs: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs.wrappedValue && rhs.wrappedValue },
            set: { _ in }
        )
    }

    static func && (_ lhs: Bool, _ rhs: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs && rhs.wrappedValue },
            set: { _ in }
        )
    }

    static func && (_ lhs: Binding<Bool>, _ rhs: Bool) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs.wrappedValue && rhs },
            set: { _ in }
        )
    }

    static func || (_ lhs: Binding<Bool>, _ rhs: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs.wrappedValue || rhs.wrappedValue },
            set: { _ in }
        )
    }

    static func || (_ lhs: Bool, _ rhs: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs || rhs.wrappedValue },
            set: { _ in }
        )
    }

    static func || (_ lhs: Binding<Bool>, _ rhs: Bool) -> Binding<Bool> {
        Binding<Bool>(
            get: { lhs.wrappedValue || rhs },
            set: { _ in }
        )
    }

    static var `true`: Binding<Bool> {
        return .constant(true)
    }

    static var `false`: Binding<Bool> {
        return .constant(false)
    }
}

extension Binding where Value == String {
    static var blank: Binding<String> {
        return .constant("")
    }
}

extension Binding where Value == Int {
    static var zero: Binding<Int> {
        return .constant(0)
    }
}

extension Binding where Value == Date {
    static var today: Binding<Date> {
        return .constant(Date())
    }
}

extension Binding where Value == Double {
    static var zero: Binding<Double> {
        return .constant(0.0)
    }
}

extension Binding where Value == CGFloat {
    static var zero: Binding<CGFloat> {
        return .constant(0.0)
    }
}

extension Binding where Value == Rule {
    static var rule: Binding<Rule> {
        return .constant(Rule())
    }
}

