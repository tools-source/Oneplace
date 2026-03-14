import GoogleMobileAds
import SwiftUI
import UIKit

struct BannerAdView: UIViewRepresentable {
    static let bannerAdUnitID = "ca-app-pub-6438658696793120/2763405144"

    func makeCoordinator() -> BannerAdCoordinator {
        BannerAdCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let bannerView = BannerView(adSize: largeAnchoredAdaptiveBanner(width: adWidth))
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.adUnitID = Self.bannerAdUnitID
        bannerView.rootViewController = UIApplication.shared.topPresentedViewController
        bannerView.delegate = context.coordinator
        bannerView.load(Request())

        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        context.coordinator.bannerView = bannerView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let bannerView = context.coordinator.bannerView else { return }

        let nextSize = largeAnchoredAdaptiveBanner(width: adWidth)
        if !isAdSizeEqualToSize(size1: bannerView.adSize, size2: nextSize) {
            bannerView.adSize = nextSize
            bannerView.load(Request())
        }

        if bannerView.rootViewController == nil {
            bannerView.rootViewController = UIApplication.shared.topPresentedViewController
        }
    }

    private var adWidth: CGFloat {
        max(UIScreen.main.bounds.width - 24, 320)
    }
}

final class BannerAdCoordinator: NSObject, BannerViewDelegate {
    weak var bannerView: BannerView?
}

private extension UIApplication {
    var topPresentedViewController: UIViewController? {
        guard
            let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let rootViewController = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            return nil
        }

        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}
