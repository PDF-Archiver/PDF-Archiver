//
//  ShareSheet.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.08.25.
//

import SwiftUI

#if os(iOS)
import UIKit

public struct ShareSheet: UIViewControllerRepresentable {
    let title: String
    let url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [title, url], applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}
#endif
