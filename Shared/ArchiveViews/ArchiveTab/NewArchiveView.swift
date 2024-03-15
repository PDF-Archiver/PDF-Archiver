//
//  NewArchiveView.swift
//
//
//  Created by Julian Kahnert on 14.03.24.
//

import SwiftUI
import SwiftData

struct NewArchiveView: View {
    @Query(sort: \DBDocument.date, order: .reverse) private var documents: [DBDocument]

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    NewArchiveView()
}
