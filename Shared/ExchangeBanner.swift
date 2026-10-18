//
//  ExchangeBanner.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.10.26.
//

import ArchiverFeatures
import KickstartExchange
import Shared
import SwiftUI

extension View {
    /// Provides the Kickstart Exchange banner that `ArchiverFeatures` shows to users without premium.
    func withExchangeBanner() -> some View {
        environment(\.exchangeBanner, AnyView(
            ExchangeBannerAdView(apiKey: "ks_live_GC3pswAXrj5cS2aOy-I6S8pbTYmCFwrJF4xgW-ibaP0")
                .exchangeAdCornerStyle(.rounded)
                .exchangeAdActionTextColor(.paRedAsset)
        ))
    }
}
