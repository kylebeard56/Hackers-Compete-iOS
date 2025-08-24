//
//  Geohash.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import Foundation

struct Geohash {
    /**
     Encodes a latitude/longitude into a geohash string.

     Approximate cell *diameter* by precision:
     ┌───────────┬────────────────────────┐
     │ Precision │ Diameter (approx.)     │
     ├───────────┼────────────────────────┤
     │ 1         │ ~5,000 km               │
     │ 2         │ ~1,250 km               │
     │ 3         │ ~156 km                 │
     │ 4         │ ~39 km                  │
     │ 5         │ ~4.9 km                 │
     │ 6         │ ~1.2 km                 │
     │ 7         │ ~152 m                  │
     │ 8         │ ~38 m                   │
     │ 9         │ ~4.8 m                  │
     │ 10        │ ~1.2 m                  │
     │ 11        │ ~15 cm                  │
     │ 12        │ ~3.7 cm                 │
     └───────────┴────────────────────────┘

     - Parameters:
       - latitude:  in degrees [-90, 90]
       - longitude: in degrees [-180, 180]
       - precision: number of characters (1...12 typical)
     - Returns: Geohash string of the requested precision.
     */
    static func encode(latitude lat: Double, longitude lon: Double, precision: Int = 5) -> String {
        precondition(precision > 0 && precision <= 20, "Precision should be between 1 and ~20")

        let clampedLat = min(90.0, max(-90.0, lat))
        var normalizedLon = lon.truncatingRemainder(dividingBy: 360.0)
        if normalizedLon < -180.0 { normalizedLon += 360.0 }
        if normalizedLon >= 180.0 { normalizedLon -= 360.0 }

        let base32: [Character] = Array("0123456789bcdefghjkmnpqrstuvwxyz")

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)

        var hash = String()
        hash.reserveCapacity(precision)

        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2.0
                if normalizedLon >= mid {
                    ch = (ch << 1) | 1
                    lonRange.0 = mid
                } else {
                    ch <<= 1
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2.0
                if clampedLat >= mid {
                    ch = (ch << 1) | 1
                    latRange.0 = mid
                } else {
                    ch <<= 1
                    latRange.1 = mid
                }
            }

            isEven.toggle()
            bit += 1

            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }

        return hash
    }
    
    static func neighbors(for geohash: String) -> [String] {
        // Base32 character set used in geohash
        let base32: [Character] = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        let base32Dict = Dictionary(uniqueKeysWithValues: base32.enumerated().map { ($1, $0) })
        
        // Neighbor lookup tables for base32 characters
        let neighbors = [
            "right": [
                "even": "bc01fg45238967deuvhjyznpkmstqrwx",
                "odd": "p0r21436x8zb9dcf5h7kjnmqesgutwvy"
            ],
            "left": [
                "even": "238967debc01fg45kmstqrwxuvhjyznp",
                "odd": "14365h7k9dcfesgujnmqp0r2twvyx8zb"
            ],
            "top": [
                "even": "p0r21436x8zb9dcf5h7kjnmqesgutwvy",
                "odd": "bc01fg45238967deuvhjyznpkmstqrwx"
            ],
            "bottom": [
                "even": "14365h7k9dcfesgujnmqp0r2twvyx8zb",
                "odd": "238967debc01fg45kmstqrwxuvhjyznp"
            ]
        ]
        
        // Border lookup tables - characters that cause overflow when moved
        let borders = [
            "right": [
                "even": "bcfguvyz",
                "odd": "prxz"
            ],
            "left": [
                "even": "0145hjnp",
                "odd": "028b"
            ],
            "top": [
                "even": "prxz",
                "odd": "bcfguvyz"
            ],
            "bottom": [
                "even": "028b",
                "odd": "0145hjnp"
            ]
        ]
        
        func calculateNeighbor(_ hash: String, direction: String) -> String {
            guard !hash.isEmpty else { return hash }
            
            let lastChar = hash.last!
            let parent = String(hash.dropLast())
            let type = hash.count % 2 == 0 ? "even" : "odd"
            
            // Check if we're at a border that causes overflow
            if let borderChars = borders[direction]?[type],
               borderChars.contains(lastChar) {
                // Recursively calculate neighbor of parent and change last character
                let parentNeighbor = calculateNeighbor(parent, direction: direction)
                if let neighborMap = neighbors[direction]?[type],
                   let charIndex = base32Dict[lastChar] {
                    let neighborMapIndex = neighborMap.index(neighborMap.startIndex, offsetBy: charIndex)
                    let newChar = neighborMap[neighborMapIndex]
                    return parentNeighbor + String(newChar)
                }
            } else {
                // Simple case: just change the last character
                if let neighborMap = neighbors[direction]?[type],
                   let charIndex = base32Dict[lastChar] {
                    let neighborMapIndex = neighborMap.index(neighborMap.startIndex, offsetBy: charIndex)
                    let newChar = neighborMap[neighborMapIndex]
                    return parent + String(newChar)
                }
            }
            
            return hash
        }
        
        // Calculate all 8 neighbors
        let right = calculateNeighbor(geohash, direction: "right")
        let left = calculateNeighbor(geohash, direction: "left")
        let top = calculateNeighbor(geohash, direction: "top")
        let bottom = calculateNeighbor(geohash, direction: "bottom")
        
        let topRight = calculateNeighbor(right, direction: "top")
        let topLeft = calculateNeighbor(left, direction: "top")
        let bottomRight = calculateNeighbor(right, direction: "bottom")
        let bottomLeft = calculateNeighbor(left, direction: "bottom")
        
        // Return all 9 geohashes (center + 8 neighbors)
        // Arranged in a 3x3 grid pattern: top row, middle row, bottom row
        return [
            topLeft, top, topRight,
            left, geohash, right,
            bottomLeft, bottom, bottomRight
        ]
    }
}
