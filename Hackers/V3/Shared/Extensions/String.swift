//
//  String.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

// MARK: - Version logic
extension String {
    static func versionSort(lhs: String, rhs: String) -> Bool {
        let lhsComponents = lhs.versionComponents()
        let rhsComponents = rhs.versionComponents()
        
        // Ensure we have valid version numbers with 3 components
        guard lhsComponents.count == 3, rhsComponents.count == 3 else {
            return false
        }
        
        // Compare major version
        if lhsComponents[0] != rhsComponents[0] {
            return lhsComponents[0] < rhsComponents[0]
        }
        
        // Compare minor version
        if lhsComponents[1] != rhsComponents[1] {
            return lhsComponents[1] < rhsComponents[1]
        }
        
        // Compare patch version
        return lhsComponents[2] < rhsComponents[2]
    }
    
    private func versionComponents() -> [Int] {
        self.split(separator: ".").compactMap { Int($0) }
    }
    
    /// https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
    func versionCompare(_ v: String) -> ComparisonResult {
        return self.compare(v, options: .numeric)
    }
    
    func isGreaterThanOrEqualTo(version: String) -> Bool {
        // compare() returns .orderedAscending if self < version
        // returns .orderedSame if self == version
        // returns .orderedDescending if self > version
        
        //"2.0.0".isVersionGreaterThanOrEqualTo("1.9.9")  // true
        //"1.9.9".isVersionGreaterThanOrEqualTo("2.0.0")  // false
        //"2.0.0".isVersionGreaterThanOrEqualTo("2.0.0")  // true
        //"2.0.1".isVersionGreaterThanOrEqualTo("2.0.0")  // true
        //"2.0.0".isVersionGreaterThanOrEqualTo("2.0.1")  // false
        let comparison = self.compare(version, options: .numeric)
        return comparison == .orderedDescending || comparison == .orderedSame
    }
}
