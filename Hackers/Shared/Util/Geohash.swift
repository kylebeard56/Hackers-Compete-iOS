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
}
