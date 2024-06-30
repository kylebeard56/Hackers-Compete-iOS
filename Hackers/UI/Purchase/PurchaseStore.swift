//
//  PurchaseStore.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import Foundation
//import RevenueCat
import StoreKit

// https://www.revenuecat.com/blog/engineering/ios-in-app-subscription-tutorial-with-storekit-2-and-swift/

enum HackersPro: String, CaseIterable {
    case yearly = "yearlypro"
    case monthly = "monthlypro"
    case lifetime = "lifetimepro"
    
    var name: String {
        switch self {
        case .yearly:       return "Yearly"
        case .monthly:      return "Monthly"
        case .lifetime:     return "Lifetime"
        }
    }
    
    var title: String {
        switch self {
        case .yearly:       return "/yr"
        case .monthly:      return "/mo"
        case .lifetime:     return "/once"
        }
    }
    
    var subtitle: String {
        switch self {
        case .monthly, .yearly:     return "and cancel anytime"
        case .lifetime:             return "and have it for a lifetime"
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

/// Refer to the following guide to get up-to-speed on testing in Xcode.
/// https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/testing_in-app_purchases_in_xcode

@MainActor class PurchaseStore: NSObject, Hackable {
//    private let kOfferCode: String = "https://apps.apple.com/redeem?ctx=offercodes&id=6443546555"//&code=\(code)
    
    /// Products available
    private let productIds: [String] = HackersPro.allCases.map({ $0.productID })
    @Published private(set) var products: [Product] = []
    @Published var isTrailAvailable: Bool = true
    
    //@Published var isEarlyBird: Bool = false
    
    /// Purchased products
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var currentProPlan: Transaction?
    @Published private(set) var purchasedProductIDs = Set<String>()
    
    var hasUnlockedPro: Bool {
        !self.purchasedProductIDs.isEmpty || deviceDefaults.isLifetimeUnlocked
    }
    
    /// External updates
    private var updates: Task<Void, Never>? = nil
    
    @Published var didCompletePurchase: Bool = false
    
    override init() {
        super.init()
        updates = observeTransactionUpdates()
        Task(operation: load)
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Load
    
    /// Load the available products to purchase.
    @Sendable private func load() async {
        print(#function)
        
        do {
            print("[PURCHASE STORE] attempt loading \(productIds)")
            self.products = try await Product.products(for: productIds)
            await updatePurchasedProducts()
            printPretty(products)
        } catch let error {
            print("load products for subscription error, \(error)")
        }
    }
    
    /// Load the purchased products (i.e. restore purchases?)
    @Sendable func updatePurchasedProducts() async {
        print(#function)
        
        self.transactions = []
        self.purchasedProductIDs.removeAll()
        
        print("[PURCHASE STORE] Transaction history:")
        for await transaction in Transaction.currentEntitlements {
            switch transaction {
            case .verified(let verifiedTransaction):
                print("Verified:")
                printPretty(verifiedTransaction)
                
                /// NOTE: This setup only allows for one Pro subscription/IAP right now so currentEntitlements will always be just 1.
                self.currentProPlan = verifiedTransaction
                self.transactions.append(verifiedTransaction)

                if let exp = verifiedTransaction.expirationDate?.timeIntervalSinceNow {
                    if exp > 0 {
                        /// Subscription has positive time interval, hence it's still in effect
                        self.purchasedProductIDs.insert(verifiedTransaction.productID)
                    } else {
                        /// Subscription has expired hence negative time interval
                        self.purchasedProductIDs.remove(verifiedTransaction.productID)
                    }
                } else if verifiedTransaction.revocationDate == nil {
                    /// Revocation date is Family Sharing revoke
                    self.purchasedProductIDs.insert(verifiedTransaction.productID)
                } else {
                    /// Verified transaction is no longer valid if it once were
                    self.purchasedProductIDs.remove(verifiedTransaction.productID)
                }
                
            case .unverified(let unverifiedTransaction, _):
                print("Unverified:")
                printPretty(unverifiedTransaction)
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
            print("[PURCHASE STORE] try await product.purchase()")
            printPretty(result)
            switch result {
            case let .success(.verified(transaction)):
                // Successful purhcase
                print("[PURCHASE STORE] purchase successful")
                await transaction.finish()
                await self.updatePurchasedProducts()
                self.didCompletePurchase = true
            case let .success(.unverified(_, _)):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                print("[PURCHASE STORE] purchase successful, but unverified")
                break
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                print("[PURCHASE STORE] purchase pending")
                break
            case .userCancelled:
                // ^^^
                print("[PURCHASE STORE] purchase cancelled")
                break
            @unknown default:
                print("[PURCHASE STORE] purchase status unknown")
                break
            }
        } catch let error {
            print("[PURCHASE STORE] error: product purchase failed, \(error)")
            if let e = error as? Product.PurchaseError {
                print("this is a Product.PurchaseError")
            }
            if let e = error as? StoreKitError {
                print("this is a StoreKitError")
            }
        }
    }
    
    // MARK: - Early Bird Offer
    
//    func presentPromoCode(for code: String = "") {
////        SKPaymentQueue.default().presentCodeRedemptionSheet()
//        let path = kOfferCode + (code.isEmpty ? "" : "&code=\(code)")
//        if let url = URL(string: path) {
//            UIApplication.shared.open(url)
//        }
//    }
    
    // MARK: - Background updates

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [unowned self] in
            for await _ in Transaction.updates {
                print(#function)
                await self.updatePurchasedProducts()
            }
        }
    }
    
    // MARK: - Restore purchases
    
    @Sendable func restorePurchases() async {
        print(#function)
        do {
            try await AppStore.sync()
        } catch let error {
            print("app store failed to sync, \(error)")
        }
    }
}

// MARK: - SKPaymentTransactionObserver

extension PurchaseStore: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        printPretty(transactions)
        print("")
    }

    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        printPretty(payment)
        printPretty(product)
        print("")
        return true
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        printPretty(transactions)
        print("")
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: any Error) {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        printPretty(error)
        print("")
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        print("")
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        print("[PURCHASE STORE] \(#function)")
        printPretty(queue)
        printPretty(productIdentifiers)
        print("")
    }
}

// MARK: - RevenueCat Integration (Future)

//extension PurchaseStore {
//
//    func getOfferings() async {
//        print(#function)
//        do {
//            let offerings = try await Purchases.shared.offerings()
//            printPretty(offerings)
//        } catch let error {
//            print("RevenueCatError: couldn't get offerings, \(error)")
//        }
//    }
//
//    func purchase(_ package: Package) async {
//        print(#function)
//        do {
//            let result = try await Purchases.shared.purchase(package: package)
//            if result.userCancelled {
//                print("user cancelled purchase")
//                return
//            }
//
//            printPretty(result.customerInfo)
//
//            if let entitlements = result.customerInfo.entitlements.all["hackerspro"] {
//                printPretty(entitlements)
//            }
//
//            if let transaction = result.transaction {
//                printPretty(transaction)
//            }
//
//        } catch let error {
//            print("RevenueCatError: couldn't purchase package, \(error)")
//        }
//    }
//
//    func restore() async {
//        print(#function)
//        do {
//            let customerInfo = try await Purchases.shared.restorePurchases()
//            printPretty(customerInfo)
//        } catch let error {
//            print("RevenueCatError: couldn't restore purchases, \(error)")
//        }
//    }
//}
