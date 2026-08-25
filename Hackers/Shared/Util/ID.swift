//
//  HackersID.swift
//  Hackers
//
//  Created by Kyle Beard on 7/31/25.
//

struct HackersID {
    static func string(_ length: Int = 28) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        var id = ""

        for _ in 0..<length {
            if let randomChar = characters.randomElement() {
                id.append(randomChar)
            }
        }

        return id
    }
    
    static func shareCode(_ length: Int = 4) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code = ""
        
        for _ in 0..<length {
            if let randomChar = characters.randomElement() {
                code.append(randomChar)
            }
        }
        
        return code
    }
}
