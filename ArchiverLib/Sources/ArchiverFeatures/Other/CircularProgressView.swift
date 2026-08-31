//
//  CircularProgressView.swift
//  
//
//  Created by Julian Kahnert on 08.11.25.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.paRedAsset, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
        .frame(width: 16, height: 16)
    }
}
