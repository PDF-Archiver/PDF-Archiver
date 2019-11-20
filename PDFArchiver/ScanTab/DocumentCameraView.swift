//
//  DocumentCameraViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable {

    private let completionHandler: ([UIImage]?) -> Void

    init(completionHandler: @escaping ([UIImage]?) -> Void) {
        self.completionHandler = completionHandler
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(completionHandler: completionHandler)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let completionHandler: ([UIImage]?) -> Void

        init(completionHandler: @escaping ([UIImage]?) -> Void) {
            self.completionHandler = completionHandler
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // The scanned pages seemed to be reversed!
            var images = [UIImage]()
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                images.append(image)
            }
            completionHandler(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completionHandler(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Log.send(.error, "Scan did fail with error.", extra: ["error": error.localizedDescription])
            completionHandler(nil)
        }
    }
}
