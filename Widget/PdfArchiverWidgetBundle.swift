//
//  PdfArchiverWidgetBundle.swift
//  Widget
//
//  Created by Julian Kahnert on 29.05.25.
//

import SwiftUI
import WidgetKit

@main
struct PdfArchiverWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget1()
        StatsWidget2()
        UntaggedDocumentsWidget()
    }
}
