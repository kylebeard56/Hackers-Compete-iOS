//
//  Firebase+Share.swift
//  Hackers
//
//  Created by Kyle Beard on 8/22/25.
//

extension FirebaseService {
    func getUniqueShareCode(_ retries: Int = 2) async -> String {
        var currentLength = await self.fetchShareCodeLength()
        var attemptsAtCurrentLength = 0
        let maxAttemptsPerLength = retries
        
        while true {
            let shareCode = HackersID.shareCode(currentLength)
            attemptsAtCurrentLength += 1
            
            switch await FirebaseService.shared.getRoundByShareCode(shareCode) {
            case .success(_):
                // Share code already exists, need to retry
                if attemptsAtCurrentLength >= maxAttemptsPerLength {
                    // Bump length and reset attempts
                    currentLength += 1
                    attemptsAtCurrentLength = 0
                    try? await FirebaseService.shared.bumpShareCodeLength(to: currentLength)
                }
                continue
                
            case .failure(let error):
                guard let e = error as? HackersError, e == .documentNotFound else {
                    // Non-documentNotFound error occurred, need to retry
                    if attemptsAtCurrentLength >= maxAttemptsPerLength {
                        // Bump length and reset attempts
                        currentLength += 1
                        attemptsAtCurrentLength = 0
                        try? await FirebaseService.shared.bumpShareCodeLength(to: currentLength)
                    }
                    continue
                }
                
                // Document not found means this share code is unique!
                return shareCode
            }
        }
    }
}
