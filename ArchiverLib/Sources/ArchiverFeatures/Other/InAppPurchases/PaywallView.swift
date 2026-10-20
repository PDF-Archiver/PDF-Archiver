//
//  PaywallView.swift
//  ArchiverLib
//

import ArchiverModels
import Logging
import Shared
import StoreKit
import SwiftUI

/// The paywall: all plans as radio cards and one purchase button.
///
/// The Mac shows it as a fixed-size sheet without scrolling; iOS scrolls the plans and pins the purchase button.
struct PaywallView: View {
    let onCancel: () -> Void
    let onPurchaseCompleted: () -> Void

    @Environment(\.purchase) private var purchase
    #if !os(macOS)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #endif

    @State private var products: [PaywallPlan: Product] = [:]
    @State private var freeTrials: [PaywallPlan: FreeTrial] = [:]
    @State private var loadFailed = false
    @State private var selectedPlan = PaywallPlan.lifetime
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var legalDocument: LegalDocument?

    var body: some View {
        content
            .task { await loadProducts() }
            .sheet(item: $legalDocument) { document in
                PageSheet(onDone: { legalDocument = nil }, content: {
                    MarkdownView(markdown: document.markdown)
                })
            }
    }

    #if os(macOS)
    private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                hero
                features
                plans
                callToAction
            }
            .padding([.horizontal, .top], 28)
            .padding(.bottom, 20)

            Divider()

            footer
        }
        .frame(width: 520)
        .background(Color.paBackgroundAsset)
    }
    #else
    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                features
                plans
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(Color.paBackgroundAsset)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel", bundle: #bundle)
                }
            }
        }
    }
    #endif

    // MARK: - Sections

    private var hero: some View {
        HStack(spacing: 14) {
            appIcon
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unlock PDF Archiver Premium", bundle: #bundle)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("No subscription or lifetime purchase found on this Apple Account.", bundle: #bundle)
                    #if !os(macOS)
                    .font(.subheadline)
                    #endif
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appIcon: some View {
        Image(.logoAsset)
            .resizable()
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)
    }

    private var features: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
            GridRow {
                feature(String(localized: "Scan documents", bundle: #bundle))
                feature(String(localized: "Search inside PDFs", bundle: #bundle))
            }
            GridRow {
                feature(String(localized: "Tag & rename PDFs", bundle: #bundle))
                feature(String(localized: "No ads", bundle: #bundle))
            }
            GridRow {
                feature(String(localized: "iCloud sync, open source", bundle: #bundle))
                feature(String(localized: "Supports a one-person team", bundle: #bundle))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(macOS)
        .background(Color.paDarkGrayAsset.opacity(0.08), in: .rect(cornerRadius: 8))
        #else
        .font(.subheadline)
        .background(Color.paDarkGrayAsset.opacity(0.08), in: .rect(cornerRadius: 12))
        #endif
    }

    private func feature(_ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
                .foregroundStyle(Color.paRedAsset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    #if os(macOS)
    private var plans: some View {
        HStack(spacing: 10) {
            ForEach(PaywallPlan.allCases) { plan in
                planCard(plan)
            }
        }
        .padding(.top, 9)
    }
    #else
    private var plans: some View {
        // Two cards side by side leave too little width per word at accessibility text sizes.
        let subscriptionLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(spacing: 10) {
            lifetimeCard
            subscriptionLayout {
                planCard(.yearly)
                planCard(.monthly)
            }
        }
    }

    private var lifetimeCard: some View {
        planButton(.lifetime) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(name(of: .lifetime))
                        .font(.title3.weight(.semibold))
                    recommendedBadge
                }
                Text(note(for: .lifetime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                price(of: .lifetime, font: .title.weight(.semibold))
                    .padding(.top, 6)
            }
            .padding(16)
        }
    }
    #endif

    private func planCard(_ plan: PaywallPlan) -> some View {
        planButton(plan) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name(of: plan))
                    .fontWeight(.semibold)
                Text(note(for: plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                price(of: plan, font: .title3.weight(.semibold))
                    .padding(.top, 6)
            }
            .padding(.top, 14)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func planButton<CardContent: View>(_ plan: PaywallPlan, @ViewBuilder label: () -> CardContent) -> some View {
        let isSelected = plan == selectedPlan
        return Button {
            selectedPlan = plan
        } label: {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.paRedAsset.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.paRedAsset : Color.secondary.opacity(0.3), lineWidth: 1.5)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .strokeBorder(isSelected ? Color.paRedAsset : Color.secondary.opacity(0.3), lineWidth: isSelected ? 4 : 1.5)
                        .frame(width: 14, height: 14)
                        .padding(12)
                }
                #if os(macOS)
                .overlay(alignment: .topLeading) {
                    if plan == .lifetime {
                        recommendedBadge
                            .offset(x: 12, y: -9)
                    }
                }
                #endif
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        // The selected card already shows its state; a focus ring would draw a second frame.
        .focusable(false)
        #endif
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var recommendedBadge: some View {
        Text("Recommended", bundle: #bundle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.paWhiteAsset)
            .padding(.vertical, 2)
            .padding(.horizontal, 7)
            .background(Color.paRedAsset, in: .capsule)
    }

    @ViewBuilder
    private func price(of plan: PaywallPlan, font: Font) -> some View {
        if let product = products[plan] {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(font)
                    .monospacedDigit()
                Text(priceSuffix(for: plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .opacity(loadFailed ? 0 : 1)
        }
    }

    private var callToAction: some View {
        VStack(spacing: 8) {
            Button {
                Task { await buySelectedPlan() }
            } label: {
                Text(callToActionTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.paRedAsset)
            .keyboardShortcut(.defaultAction)
            .disabled(products[selectedPlan] == nil || isPurchasing)

            Group {
                if loadFailed {
                    HStack(spacing: 6) {
                        Text("The App Store offers could not be loaded.", bundle: #bundle)
                        Button {
                            Task { await loadProducts() }
                        } label: {
                            Text("Try Again", bundle: #bundle)
                        }
                        #if os(macOS)
                        .buttonStyle(.link)
                        #endif
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                } else {
                    Text(finePrint)
                        // Fine print is one or two lines per plan; a fixed height keeps the buy button still.
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        Button {
            Task { await restorePurchases() }
        } label: {
            HStack(spacing: 6) {
                Text("Restore Purchases", bundle: #bundle)
                // Keeps its space so the links next to it don't shift while the sync runs.
                ProgressView()
                    .controlSize(.mini)
                    .opacity(isRestoring ? 1 : 0)
            }
        }
        #if os(macOS)
        .focusable(false)
        #endif
        .disabled(isRestoring)
        Button {
            legalDocument = .termsOfUse
        } label: {
            Text("Terms", bundle: #bundle)
        }
        #if os(macOS)
        .focusable(false)
        #endif
        Button {
            legalDocument = .privacy
        } label: {
            Text("Privacy", bundle: #bundle)
        }
        #if os(macOS)
        .focusable(false)
        #endif
    }

    #if os(macOS)
    private var footer: some View {
        HStack(spacing: 14) {
            legalLinks

            Spacer()

            Button {
                onCancel()
            } label: {
                Text("Cancel", bundle: #bundle)
            }
            .buttonStyle(.bordered)
            .tint(nil)
            .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.link)
        .tint(Color.paRedAsset)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
    #else
    private var bottomBar: some View {
        // At accessibility text sizes the three links no longer fit on one line.
        let linkLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 18))
        return VStack(spacing: 10) {
            callToAction
            linkLayout {
                legalLinks
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
        .tint(Color.paRedAsset)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.paBackgroundAsset)
        .overlay(alignment: .top) {
            Divider()
        }
    }
    #endif
}

extension PaywallView {
    // MARK: - Copy

    private func name(of plan: PaywallPlan) -> String {
        switch plan {
        case .lifetime: return String(localized: "Lifetime", bundle: #bundle)
        case .yearly: return String(localized: "Yearly", bundle: #bundle)
        case .monthly: return String(localized: "Monthly", bundle: #bundle)
        }
    }

    private func note(for plan: PaywallPlan) -> String {
        guard plan != .lifetime else { return String(localized: "Pay once", bundle: #bundle) }
        guard let freeTrial = freeTrials[plan] else { return "" }
        return String(localized: "\(freeTrial.formattedDuration) free", bundle: #bundle)
    }

    private func priceSuffix(for plan: PaywallPlan) -> String {
        switch plan {
        case .lifetime: return ""
        case .yearly: return String(localized: "/ year", bundle: #bundle)
        case .monthly: return String(localized: "/ month", bundle: #bundle)
        }
    }

    private var callToActionTitle: String {
        guard let product = products[selectedPlan] else { return name(of: selectedPlan) }
        switch selectedPlan.callToAction(displayPrice: product.displayPrice, freeTrial: freeTrials[selectedPlan]) {
        case .buyLifetime(let price):
            return String(localized: "Buy Lifetime for \(price)", bundle: #bundle)

        case .subscribe(let price):
            return String(localized: "Subscribe for \(price)", bundle: #bundle)

        case .startFreeTrial(let freeTrial):
            return freeTrial.callToActionTitle
        }
    }

    private var finePrint: String {
        guard let product = products[selectedPlan] else { return " " }
        let price = product.displayPrice
        switch (selectedPlan, freeTrials[selectedPlan]) {
        case (.lifetime, _):
            return String(localized: "One-time purchase. Yours forever, on all your devices.", bundle: #bundle)

        case (.yearly, .some(let freeTrial)):
            return String(localized: "Free for \(freeTrial.formattedDuration), then \(price) per year. Cancel anytime in Settings.", bundle: #bundle)

        case (.monthly, .some(let freeTrial)):
            return String(localized: "Free for \(freeTrial.formattedDuration), then \(price) per month. Cancel anytime in Settings.", bundle: #bundle)

        case (.yearly, .none):
            return String(localized: "\(price) per year. Cancel anytime in Settings.", bundle: #bundle)

        case (.monthly, .none):
            return String(localized: "\(price) per month. Cancel anytime in Settings.", bundle: #bundle)
        }
    }

    // MARK: - StoreKit

    private func loadProducts() async {
        loadFailed = false
        do {
            let loaded = try await Product.products(for: PaywallPlan.allCases.map(\.productID))
            var products: [PaywallPlan: Product] = [:]
            var freeTrials: [PaywallPlan: FreeTrial] = [:]
            for plan in PaywallPlan.allCases {
                guard let product = loaded.first(where: { $0.id == plan.productID }) else { continue }
                products[plan] = product
                if let subscription = product.subscription, let offer = subscription.introductoryOffer {
                    freeTrials[plan] = FreeTrial(paymentMode: offer.paymentMode,
                                                 value: offer.period.value,
                                                 unit: offer.period.unit,
                                                 isEligible: await subscription.isEligibleForIntroOffer)
                }
            }
            self.products = products
            self.freeTrials = freeTrials
            loadFailed = products.count != PaywallPlan.allCases.count
            if loadFailed {
                Logger.inAppPurchase.error("Paywall products missing", metadata: [
                    "loadedProductIds": "\(loaded.map(\.id))"
                ])
            }
        } catch {
            Logger.inAppPurchase.error("Loading paywall products failed", metadata: [
                "error": "\(LogRedact.describe(error))"
            ])
            loadFailed = true
        }
    }

    private func buySelectedPlan() async {
        guard let product = products[selectedPlan] else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                onPurchaseCompleted()

            case .success(.unverified(let transaction, let error)):
                Logger.inAppPurchase.error("Transaction is unverified", metadata: [
                    "transactionId": "\(transaction.id)",
                    "productId": "\(transaction.productID)",
                    "error": "\(LogRedact.describe(error))"
                ])

            case .userCancelled, .pending:
                break

            @unknown default:
                break
            }
        } catch {
            Logger.inAppPurchase.error("Purchase failed", metadata: [
                "productId": "\(product.id)",
                "error": "\(LogRedact.describe(error))"
            ])
            errorMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        errorMessage = nil
        do {
            try await AppStore.sync()
            onPurchaseCompleted()
        } catch {
            Logger.inAppPurchase.error("Restoring purchases failed", metadata: [
                "error": "\(LogRedact.describe(error))"
            ])
            errorMessage = error.localizedDescription
        }
    }
}

private enum LegalDocument: Identifiable {
    case termsOfUse
    case privacy

    var id: Self { self }

    var markdown: String {
        switch self {
        case .termsOfUse: return String(localized: "TERMS_OF_USE", bundle: #bundle)
        case .privacy: return String(localized: "PRIVACY", bundle: #bundle)
        }
    }
}

private extension FreeTrial {
    /// "2 weeks", pluralized and localized by Foundation.
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        var components = DateComponents()
        switch unit {
        case .day: components.day = value
        case .week: components.weekOfMonth = value
        case .month: components.month = value
        case .year: components.year = value
        @unknown default: components.day = value
        }
        return formatter.string(from: components) ?? ""
    }

    var callToActionTitle: String {
        switch unit {
        case .day: return String(localized: "Start \(value)-Day Free Trial", bundle: #bundle)
        case .week: return String(localized: "Start \(value)-Week Free Trial", bundle: #bundle)
        case .month: return String(localized: "Start \(value)-Month Free Trial", bundle: #bundle)
        case .year: return String(localized: "Start \(value)-Year Free Trial", bundle: #bundle)
        @unknown default: return String(localized: "Start Free Trial", bundle: #bundle)
        }
    }
}

#if DEBUG
#if os(macOS)
#Preview("Paywall") {
    PaywallView(onCancel: {}, onPurchaseCompleted: {})
}
#else
#Preview("Paywall light") {
    NavigationStack {
        PaywallView(onCancel: {}, onPurchaseCompleted: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Paywall dark") {
    NavigationStack {
        PaywallView(onCancel: {}, onPurchaseCompleted: {})
    }
    .preferredColorScheme(.dark)
}
#endif
#endif
