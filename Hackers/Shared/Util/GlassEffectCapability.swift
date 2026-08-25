//
//  GlassEffectCapability.swift
//  Hackers
//
//  Created for user testing feedback: iOS 26 Liquid Glass can render with green tint,
//  odd capsules, or other artifacts on older devices. Use material fallback for consistency.
//
//  Research: iOS 26 supported devices start at iPhone 11. Liquid Glass issues reported
//  on iPhone 13, 14 Pro, 15 Pro (gadgets360, Apple Discussions). We include iPhone 11–15
//  series for material fallback; iPhone 16+ and newer use native glass.
//

import Darwin
import UIKit

enum GlassEffectCapability {
    /// Whether the device should use `.glassEffect` (iOS 26+) or material fallback.
    /// Returns false for iOS < 26 or devices with known glass rendering issues.
    static var useGlassEffect: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return !hasKnownGlassRenderingIssues
    }

    /// Devices that exhibit green tint, odd capsule shapes, or other glass rendering
    /// artifacts (e.g. iPhone 13/14/15 on iOS 26 with non-default text scaling).
    private static var hasKnownGlassRenderingIssues: Bool {
        deviceModelIdentifier.map { knownProblematicIdentifiers.contains($0) } ?? false
    }

    /// Machine identifier (e.g. "iPhone14,2" for iPhone 13 Pro).
    private static var deviceModelIdentifier: String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
    }

    /// iPhone 11–15 series: Liquid Glass rendering issues reported on iOS 26.
    /// iPhone 16+ (iPhone17,x) use native glass.
    static let knownProblematicIdentifiers: Set<String> = [
        // iPhone 11
        "iPhone12,1", "iPhone12,3", "iPhone12,5",
        // iPhone 12
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",
        // iPhone 13
        "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5",
        // iPhone 14
        "iPhone14,6", "iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3",
        // iPhone 15
        "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2",
    ]
}
