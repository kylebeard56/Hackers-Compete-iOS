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

        func shouldBumpLength() async {
            if attemptsAtCurrentLength >= maxAttemptsPerLength {
                currentLength += 1
                attemptsAtCurrentLength = 0
                try? await FirebaseService.shared.bumpShareCodeLength(to: currentLength)
            }
        }

        while true {
            let shareCode = HackersID.shareCode(currentLength)
            attemptsAtCurrentLength += 1

            switch await FirebaseService.shared.getRoundByShareCode(shareCode) {
            case .success:
                await shouldBumpLength()
                continue
            case .failure(let error):
                guard let e = error as? HackersError, e == .documentNotFound else {
                    await shouldBumpLength()
                    continue
                }
            }

            switch await FirebaseService.shared.getSeriesByShareCode(shareCode) {
            case .success:
                await shouldBumpLength()
                continue
            case .failure(let error):
                guard let e = error as? HackersError, e == .documentNotFound else {
                    await shouldBumpLength()
                    continue
                }
            }

            return shareCode
        }
    }
}
