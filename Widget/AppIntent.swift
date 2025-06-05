//
//  AppIntent.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import AppIntents
import WidgetKit

#warning("TODO: remove this config")
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Statistics widget of your documents." }

    @Parameter(title: "First year in statistics", default: 2023)
    var firstYear: Int
}
