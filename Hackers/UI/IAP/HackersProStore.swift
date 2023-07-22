//
//  HackersProStore.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import Foundation
import StoreKit

// https://www.revenuecat.com/blog/engineering/ios-in-app-subscription-tutorial-with-storekit-2-and-swift/

enum HackersPro {
    case yearly
    case monthly
    case lifetime
    
    var title: String {
        switch self {
        case .yearly:       return "$9.99/yr"
        case .monthly:      return "$2.99/mo"
        case .lifetime:     return "$49.99/once"
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
        switch self {
        case .yearly:       return "com.tigermindlabs.yearlypro"
        case .monthly:      return "com.tigermindlabs.monthlypro"
        case .lifetime:     return "com.tigermindlabs.lifetimepro"
        }
    }
}

@MainActor class HackersProStore: NSObject, Hackable {
    @Published var proUnlocked: Bool = false

    // TODO: Store these in the firebase app in remote configuration for easy swap out without app release to change.
    /// Products available
    private let productIds = [HackersPro.lifetime.productID, HackersPro.yearly.productID, HackersPro.monthly.productID]
    @Published private(set) var products: [Product] = []
    
    /// Purchased products
    @Published private(set) var purchasedProductIDs = Set<String>()
    var hasUnlockedPro: Bool { !self.purchasedProductIDs.isEmpty }
    
    /// External updates
    private var updates: Task<Void, Never>? = nil
    
    override init() {
        super.init()
        Task(operation: load)
//        updates = observeTransactionUpdates()
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
//        updates?.cancel()
    }
    
    // MARK: - Load
    
    /// Load the available products to purchase.
    @Sendable private func load() async {
        do {
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
