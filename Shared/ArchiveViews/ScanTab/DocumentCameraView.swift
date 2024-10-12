//
//  DocumentCameraViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#if !os(macOS)
import SwiftUI
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable, Log {

    private let controller = VNDocumentCameraViewController()
    private let isShown: Binding<Bool>
    private let imageHandler: ([CIImage]) -> Void

    init(isShown: Binding<Bool>, imageHandler: @escaping ([CIImage]) -> Void) {
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
        private let imageHandler: ([CIImage]) -> Void

        fileprivate init(isShown: Binding<Bool>, imageHandler: @escaping ([CIImage]) -> Void) {
            self.isShown = isShown
            self.imageHandler = imageHandler
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            self.isShown.wrappedValue = false

            // TODO: test if this should be done in the background?
//            DispatchQueue.global(qos: .userInitiated).async {
                var images = [CIImage]()
                for index in 0..<scan.pageCount {
                    guard let image = CIImage(imageWithOrientation: scan.imageOfPage(at: index)) else {
                        preconditionFailure("Failed to convert scanned image.")
                    }
                    images.append(image)
                }
                imageHandler(images)
//            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            self.isShown.wrappedValue = false
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            log.error("Scan did fail with error.", metadata: ["error": "\(error)"])
            self.isShown.wrappedValue = false
        }
    }
}

extension VNDocumentCameraScan: @unchecked @retroactive Sendable {}
#endif
