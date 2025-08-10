//
//  DocumentCameraViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#if !os(macOS)
import Shared
import SwiftUI
@preconcurrency import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable, Log {

    private let controller = VNDocumentCameraViewController()
    private let isShown: Binding<Bool>
    private let imageHandler: @Sendable ([PlatformImage]) -> Void

    init(isShown: Binding<Bool>, imageHandler: @Sendable @escaping ([PlatformImage]) -> Void) {
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

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate, Sendable {

        private let isShown: Binding<Bool>
        private let imageHandler: @Sendable ([PlatformImage]) -> Void

        fileprivate init(isShown: Binding<Bool>, imageHandler: @Sendable @escaping ([PlatformImage]) -> Void) {
            self.isShown = isShown
            self.imageHandler = imageHandler
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            self.isShown.wrappedValue = false

            DispatchQueue.global(qos: .userInitiated).async {
                var images = [PlatformImage]()
                for index in 0..<scan.pageCount {
                    images.append(scan.imageOfPage(at: index))
                }
                self.imageHandler(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            self.isShown.wrappedValue = false
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            log.error("Scan did fail with error.", metadata: ["error": "\(error)"])
            self.isShown.wrappedValue = false
        }
    }
}
#endif
