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

/// How the cross-promotion banner is framed where it is placed.
public enum ExchangeBannerStyle: Sendable {
    /// A free-standing card with its own rounded corners and stroke.
    case card
    /// Square and without stroke, so a list section's clip gives it exactly the section's corners.
    case listRow
}

public extension EnvironmentValues {
    /// The cross-promotion banner, injected by the app targets: the SDK behind it must not be
    /// linked into `ArchiverLib`, which the widget extension links as well.
    @Entry var exchangeBanner: AnyView?

    /// Read by the injected `exchangeBanner` to frame itself for its placement.
    @Entry var exchangeBannerStyle = ExchangeBannerStyle.card
}

/// Shows the injected `exchangeBanner` to users without premium only.
struct ExchangeBannerSlot: View {
    var style = ExchangeBannerStyle.card

    @Environment(\.exchangeBanner) private var exchangeBanner
    @SharedReader(.premiumStatus) private var premiumStatus: PremiumStatus = .loading

    var body: some View {
        // Not while `.loading` either, or premium users would see the banner at every launch.
        if premiumStatus == .inactive, let exchangeBanner {
            exchangeBanner
                .environment(\.exchangeBannerStyle, style)
        }
    }
}

#if DEBUG
#Preview {
    ExchangeBannerSlot()
        .environment(\.exchangeBanner, AnyView(Text(verbatim: "Banner")))
}
#endif
