//
//  PurchaseStore.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import Foundation
import RevenueCat
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
        case .monthly, .yearly:       return "and cancel anytime"
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

@MainActor class PurchaseStore: NSObject, Hackable {
    /// Products available
    private let productIds: [String] = HackersPro.allCases.map({ $0.productID })
    @Published private(set) var products: [Product] = []
    @Published var isTrailAvailable: Bool = true
    
    // TODO: On our initial launch, we will check if the user's deviceCount > 1 and if so, show early bird promo code.
    /// Add logic for didCheckForEarlyBard and isEarlyBirdUser
    @Published var isEarlyBird: Bool = false
    
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
        await refreshTransactions()
        
        do {
            print("attempt loading \(productIds)")
            self.products = try await Product.products(for: productIds)
            printPretty(products)
        } catch let error {
            print("load products for subscription error, \(error)")
        }
    }
    
    private func refreshTransactions() async {
        print(#function)
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            print("Transaction: ")
            printPretty(transaction)
            if transaction.productID == HackersPro.yearly.productID {
                print("yearly subscription detected -> trial unavailable")
                self.isTrailAvailable = false
            }
            print("")
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
    
    // MARK: - Early Bird Offer
    
    func presentEarlyBird() {
        SKPaymentQueue.default().presentCodeRedemptionSheet()
    }
    
    // MARK: - Background updates
    
    @Sendable func checkTransactionUpdates() async {
        print(#function)
        for await _ in Transaction.updates {
            print("IAP transaction updated detected")
            await self.updatePurchasedProducts()
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

extension PurchaseStore: SKPaymentTransactionObserver {
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

// MARK: - RevenueCat Integration (Future)

extension PurchaseStore {
    
    func getOfferings() async {
        print(#function)
        do {
            let offerings = try await Purchases.shared.offerings()
            printPretty(offerings)
        } catch let error {
            print("RevenueCatError: couldn't get offerings, \(error)")
        }
    }
    
    func purchase(_ package: Package) async {
        print(#function)
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                print("user cancelled purchase")
                return
            }
            
            printPretty(result.customerInfo)
            
            if let entitlements = result.customerInfo.entitlements.all["hackerspro"] {
                printPretty(entitlements)
            }
            
            if let transaction = result.transaction {
                printPretty(transaction)
            }

        } catch let error {
            print("RevenueCatError: couldn't purchase package, \(error)")
        }
    }
    
    func restore() async {
        print(#function)
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            printPretty(customerInfo)
        } catch let error {
            print("RevenueCatError: couldn't restore purchases, \(error)")
        }
    }
}
