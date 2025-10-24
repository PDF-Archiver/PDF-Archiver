//
//  AppIntent.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Widget Configuration" }
    static var description: IntentDescription { "Statistics widget of your documents." }

    // Default shows statistics from 2020 onwards (approximately last 5 years)
    @Parameter(title: "First year in statistics", default: 2020)
    var firstYear: Int
}
