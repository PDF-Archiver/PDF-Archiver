//
//  ExchangeBannerSlot.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 18.10.26.
//

import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

public extension EnvironmentValues {
    /// The cross-promotion banner, injected by the app targets: the SDK behind it must not be
    /// linked into `ArchiverLib`, which the widget extension links as well.
    @Entry var exchangeBanner: AnyView?
}

/// Shows the injected `exchangeBanner` to users without premium only.
struct ExchangeBannerSlot: View {
    @Environment(\.exchangeBanner) private var exchangeBanner
    @SharedReader(.premiumStatus) private var premiumStatus: PremiumStatus = .loading

    var body: some View {
        // Not while `.loading` either, or premium users would see the banner at every launch.
        if premiumStatus == .inactive, let exchangeBanner {
            exchangeBanner
        }
    }
}

#if DEBUG
#Preview {
    ExchangeBannerSlot()
        .environment(\.exchangeBanner, AnyView(Text(verbatim: "Banner")))
}
#endif
