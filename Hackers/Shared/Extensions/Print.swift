//
//  Print.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftPrettyPrint

public func print(_ object: Any...) {
#if SANDBOX || PRODUCTION
    for item in object {
        Swift.print(item)
    }
#endif
}

public func print(_ object: Any) {
#if SANDBOX || PRODUCTION
    Swift.print(object)
#endif
}

public func printPretty(_ a: Any) {
#if SANDBOX || PRODUCTION
    Pretty.prettyPrint(a)
#endif
}
//
//public func printPretty(_ a: Any, omit: [String] = []) {
//#if SANDBOX
//    Pretty.prettyPrint(a, omitting: omit)
//#endif
//}
//
//extension Pretty {
//
//    /// Pretty-prints an Encodable as JSON, omitting specific dot-path fields (supports `*` wildcards).
//    ///
//    /// Examples:
//    /// - "round.configuration.holes"
//    /// - "round.segment.course"
//    /// - "participants.*.strokes"
//    /// - "teams.*.players.*.history"
//    ///
//    /// Notes:
//    /// - `*` matches any dictionary key or any array element
//    /// - Also supports numeric indices for arrays: "participants.0.name"
//    static func printPretty<T: Encodable>(
//        _ value: T,
//        label: String? = nil,
//        omitting: [String] = [],
//        separator: String = " ",
//        option: Pretty.Option = Pretty.sharedOption,
//        encoder: JSONEncoder = .prettySortedISO8601
//    ) {
//        do {
//            let data = try encoder.encode(value)
//            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
//
//            let pruned = prune(json, omitting: omitting)
//
//            // Feed the pruned JSON object into SwiftPrettyPrint
//            Pretty.prettyPrint(label: label, pruned, separator: separator, option: option)
//        } catch {
//            Pretty.prettyPrint(label: label, ["error": "\(error)"], separator: separator, option: option)
//        }
//    }
//}
//
//// MARK: - Pruning with wildcard dot-paths
//
//private func prune(_ root: Any, omitting paths: [String]) -> Any {
//    let tokenized: [[String]] = paths
//        .map { $0.split(separator: ".").map(String.init) }
//        .filter { !$0.isEmpty }
//
//    guard !tokenized.isEmpty else { return root }
//
//    var node = root
//    for tokens in tokenized {
//        node = remove(path: tokens, in: node)
//    }
//    return node
//}
//
//private func remove(path: [String], in node: Any) -> Any {
//    guard let head = path.first else { return node }
//    let tail = Array(path.dropFirst())
//
//    // Dictionary node
//    if var dict = node as? [String: Any] {
//        if head == "*" {
//            // Apply to every key
//            for key in dict.keys {
//                if tail.isEmpty {
//                    dict.removeValue(forKey: key)
//                } else if let value = dict[key] {
//                    dict[key] = remove(path: tail, in: value)
//                }
//            }
//            return dict
//        } else {
//            // Exact key
//            guard dict.keys.contains(head) else { return dict }
//            if tail.isEmpty {
//                dict.removeValue(forKey: head)
//            } else if let value = dict[head] {
//                dict[head] = remove(path: tail, in: value)
//            }
//            return dict
//        }
//    }
//
//    // Array node
//    if var arr = node as? [Any] {
//        if head == "*" {
//            // Apply to every element
//            if tail.isEmpty { return [] }
//            for i in arr.indices {
//                arr[i] = remove(path: tail, in: arr[i])
//            }
//            return arr
//        }
//
//        // Optional: support numeric indices
//        if let idx = Int(head), arr.indices.contains(idx) {
//            if tail.isEmpty {
//                arr.remove(at: idx)
//            } else {
//                arr[idx] = remove(path: tail, in: arr[idx])
//            }
//            return arr
//        }
//
//        return arr
//    }
//
//    // Leaf/scalar
//    return node
//}
//
//// MARK: - JSONEncoder convenience
//
//extension JSONEncoder {
//    static var prettySortedISO8601: JSONEncoder {
//        let e = JSONEncoder()
//        e.outputFormatting = [.prettyPrinted, .sortedKeys]
//        e.dateEncodingStrategy = .iso8601
//        return e
//    }
//}
