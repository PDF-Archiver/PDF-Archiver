//
//  DocumentCameraViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#if !os(macOS)
import ArchiverModels
import Logging
import Shared
import SwiftUI
@preconcurrency import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable, Log {

    private let isShown: Binding<Bool>
    private let imageHandler: @Sendable ([PlatformImage]) -> Void

    init(isShown: Binding<Bool>, imageHandler: @Sendable @escaping ([PlatformImage]) -> Void) {
        self.isShown = isShown
        self.imageHandler = imageHandler
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        // Created here, not as a stored property: SwiftUI rebuilds this struct on every update of
        // the sheet, and only the first controller is ever shown.
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(isShown: isShown, imageHandler: imageHandler)
    }

    /// VisionKit calls its delegate on the main thread, and `isShown` is a SwiftUI binding.
    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        private let isShown: Binding<Bool>
        private let imageHandler: @Sendable ([PlatformImage]) -> Void

        fileprivate init(isShown: Binding<Bool>, imageHandler: @Sendable @escaping ([PlatformImage]) -> Void) {
            self.isShown = isShown
            self.imageHandler = imageHandler
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            self.isShown.wrappedValue = false

            let imageHandler = self.imageHandler
            Task(priority: .userInitiated) {
                await Self.handlePages(of: scan, with: imageHandler)
            }
        }

        /// Renders every page off the main actor. VisionKit does not mark `VNDocumentCameraScan`
        /// `Sendable` (hence the `@preconcurrency import`), but the scan is a finished result that
        /// nothing mutates once the delegate received it.
        @concurrent
        private static func handlePages(of scan: VNDocumentCameraScan,
                                        with imageHandler: @Sendable ([PlatformImage]) -> Void) async {
            var images = [PlatformImage]()
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            imageHandler(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            self.isShown.wrappedValue = false
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            log.error("Scan did fail with error.", metadata: ["error": "\(LogRedact.describe(error))"])
            self.isShown.wrappedValue = false
        }
    }
}
#endif
