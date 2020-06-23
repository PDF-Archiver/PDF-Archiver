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

    private let controller = VNDocumentCameraViewController()
    private let isShown: Binding<Bool>
    private let imageHandler: ([UIImage]) -> Void

    init(isShown: Binding<Bool>, imageHandler: @escaping ([UIImage]) -> Void) {
        self.isShown = isShown
        self.imageHandler = imageHandler
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(isShown: isShown, imageHandler: imageHandler)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        
        private let isShown: Binding<Bool>
        private let imageHandler: ([UIImage]) -> Void

        init(isShown: Binding<Bool>, imageHandler: @escaping ([UIImage]) -> Void) {
            self.isShown = isShown
            self.imageHandler = imageHandler
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            self.isShown.wrappedValue = false
            
            DispatchQueue.global(qos: .utility).async {
                var images = [UIImage]()
                for index in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: index)
                    images.append(image)
                }
                self.imageHandler(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            self.isShown.wrappedValue = false
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Log.send(.error, "Scan did fail with error.", extra: ["error": error.localizedDescription])
            self.isShown.wrappedValue = false
        }
    }
}
