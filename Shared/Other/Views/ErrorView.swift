//
//  ErrorView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.03.24.
//

import SwiftUI

struct ErrorView: View {
    let error: any Error
    var body: some View {
        ContentUnavailableView("An error occurred 😳", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
    }
}

#Preview {
    ErrorView(error: NSError(domain: "Testing", code: 42))
}
