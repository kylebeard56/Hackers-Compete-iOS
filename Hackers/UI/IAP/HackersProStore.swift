//
//  HackersProStore.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import Foundation
import StoreKit

// https://www.revenuecat.com/blog/engineering/ios-in-app-subscription-tutorial-with-storekit-2-and-swift/

enum HackersPro: String, CaseIterable {
    case yearly = "yearlypro"
    case monthly = "monthlypro"
    case lifetime = "lifetimepro"
    
    var title: String {
        switch self {
        case .yearly:       return "/yr"
        case .monthly:      return "/mo"
        case .lifetime:     return "/once"
        }
    }
    
    var subtitle: String {
        switch self {
        case .yearly:       return "after a 14 day trial"
        case .monthly:      return "and cancel anytime"
        case .lifetime:     return "and have it for a lifetime"
        }
    }
    
    var icon: String {
        switch self {
        case .yearly:       return "f133"
        case .monthly:      return "f073"
        case .lifetime:     return "f534"
        }
    }
    
    var productID: String {
        "com.tigermindlabs.hackers.\(self.rawValue)"
    }
}

@MainActor class HackersProStore: NSObject, Hackable {
    /// Products available
    private let productIds: [String] = HackersPro.allCases.map({ $0.productID })
    @Published private(set) var products: [Product] = []
    
    /// Purchased products
    @Published private(set) var purchasedProductIDs = Set<String>()
    var hasUnlockedPro: Bool { !self.purchasedProductIDs.isEmpty }
    
    /// External updates
    private var updates: Task<Void, Never>? = nil
    
    @Published var didCompletePurchase: Bool = false
    
    override init() {
        super.init()
        Task(operation: load)
        SKPaymentQueue.default().add(self)
    }
    
    deinit { }
    
    // MARK: - Load
    
    /// Load the available products to purchase.
    @Sendable private func load() async {
        print(#function)
        do {
            print("attempt loading \(productIds)")
            self.products = try await Product.products(for: productIds)
            printPretty(products)
        } catch let error {
            print("load products for subscription error, \(error)")
        }
    }
    
    /// Load the purchased products (i.e. restore purchases?)
    func updatePurchasedProducts() async {
        print(#function)
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            printPretty(result)
            if transaction.revocationDate == nil {
                self.purchasedProductIDs.insert(transaction.productID)
            } else {
                self.purchasedProductIDs.remove(transaction.productID)
            }
        }
    }
    
    // MARK: - Purchase
    
    /// Present model to purchase subscription or IAP
    func purchase(_ plan: HackersPro) async {
        print(#function)
        guard let product = self.products.first(where: { $0.id == plan.productID }) else {
            print("error: product not found")
            return
        }
        
        do {
            let result = try await product.purchase()
            printPretty(result)
            switch result {
            case let .success(.verified(transaction)):
                // Successful purhcase
                await transaction.finish()
                await self.updatePurchasedProducts()
                self.didCompletePurchase = true
            case let .success(.unverified(_, error)):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                break
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                break
            case .userCancelled:
                // ^^^
                break
            @unknown default:
                break
            }
        } catch let error {
            print("error: product purchase failed, \(error)")
            if let e = error as? Product.PurchaseError {
                print("this is a Product.PurchaseError")
            }
            if let e = error as? StoreKitError {
                print("this is a StoreKitError")
            }
        }
    }
    
    // MARK: - Background updates
    
    @Sendable func checkTransactionUpdates() async {
        print(#function)
        for await _ in Transaction.updates {
            print("IAP transaction updated detected")
            await self.updatePurchasedProducts()
        }
    }
    
    /// Observe any external changes to subscription (cancel in settings, etc..)
//    private func observeTransactionUpdates() -> Task<Void, Never> {
//        print(#function)
//        Task(priority: .background) { [unowned self] in
//            for await verificationResult in Transaction.updates {
//                // Using verificationResult directly would be better
//                // but this way works for this tutorial
//                print("IAP transaction updated detected")
//                await self.updatePurchasedProducts()
//            }
//        }
//    }
    
    // MARK: - Restore purchases
    
    func restorePurchases() async {
        print(#function)
        do {
            try await AppStore.sync()
        } catch let error {
            print("app store failed to sync, \(error)")
        }
    }
}

extension HackersProStore: SKPaymentTransactionObserver {
    func paymentQueue(
        _ queue: SKPaymentQueue,
        updatedTransactions transactions: [SKPaymentTransaction]
    ) {
        print(#function)
    }

    func paymentQueue(
        _ queue: SKPaymentQueue,
        shouldAddStorePayment payment: SKPayment,
        for product: SKProduct
    ) -> Bool {
        print(#function)
        return true
    }
}
