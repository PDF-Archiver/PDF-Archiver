//
//  ProgressView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 30.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct ProgressView: View {

    let value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: Alignment.leading) {
                Rectangle()
                    .opacity(0.3)

                Rectangle()
                    .background(Color("DarkGray"))
                    .frame(minWidth: CGFloat(0),
                           idealWidth: self.getProgressBarWidth(geometry: geometry, value: self.value),
                           maxWidth: self.getProgressBarWidth(geometry: geometry, value: self.value))
                    .opacity(0.6)
                    .animation(.spring())
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
    }

    private func getProgressBarWidth(geometry: GeometryProxy, value: Float) -> CGFloat {
        let frame = geometry.frame(in: .global)
        return frame.size.width * CGFloat(value)
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView(value: 0.333)
            .padding()
    }
}
