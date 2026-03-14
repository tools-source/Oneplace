import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let removeAdsProductID = "com.one_place.app.removeads"
    private static let adsRemovedDefaultsKey = "purchase.removeAds.isUnlocked"

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var isAdsRemoved: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoringPurchases = false
    @Published var purchaseErrorMessage: String?

    init() {
        isAdsRemoved = UserDefaults.standard.bool(forKey: Self.adsRemovedDefaultsKey)
    }

    var removeAdsPriceText: String {
        removeAdsProduct?.displayPrice ?? "One-time purchase"
    }

    func prepare() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        guard removeAdsProduct == nil, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first(where: { $0.id == Self.removeAdsProductID })
        } catch {
            removeAdsProduct = nil
        }
    }

    func refreshEntitlements() async {
        var hasRemoveAdsAccess = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.removeAdsProductID else { continue }
            if transaction.revocationDate == nil {
                hasRemoveAdsAccess = true
                break
            }
        }

        updateAdsRemovedState(hasRemoveAdsAccess)
    }

    func purchaseRemoveAds() async {
        guard !isPurchasing else { return }

        if removeAdsProduct == nil {
            await loadProducts()
        }

        guard let removeAdsProduct else {
            purchaseErrorMessage = "The Remove Ads purchase is not available yet. Confirm the product ID in App Store Connect and try again."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await removeAdsProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                if transaction.productID == Self.removeAdsProductID,
                   transaction.revocationDate == nil {
                    updateAdsRemovedState(true)
                }
                await transaction.finish()
            case .pending:
                purchaseErrorMessage = "This purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                purchaseErrorMessage = "The App Store returned an unexpected purchase state."
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func clearPurchaseError() {
        purchaseErrorMessage = nil
    }

    private func updateAdsRemovedState(_ isRemoved: Bool) {
        isAdsRemoved = isRemoved
        UserDefaults.standard.set(isRemoved, forKey: Self.adsRemovedDefaultsKey)
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
