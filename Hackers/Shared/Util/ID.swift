//
//  ID.swift
//  Hackers
//
//  Created by Kyle Beard on 7/31/25.
//

struct ID {
    static func string(_ length: Int = 20) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        var id = ""

        for _ in 0..<length {
            if let randomChar = characters.randomElement() {
                id.append(randomChar)
            }
        }

        return id
    }
}
