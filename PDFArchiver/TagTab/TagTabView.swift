//
//  TagTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct TagTabView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> DocumentHandleViewController {
        let storyboard = UIStoryboard(name: "TagTab", bundle: nil)
        return storyboard.instantiateViewController(identifier: "DocumentHandleViewController")
    }

    func updateUIViewController(_ uiViewController: DocumentHandleViewController, context: Context) {

    }
}
