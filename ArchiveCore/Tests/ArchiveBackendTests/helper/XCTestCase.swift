//
//  XCTestCase.swift
//  
//
//  Created by Julian Kahnert on 02.12.20.
//

import GraphicsRenderer
import PDFKit
import XCTest

extension XCTestCase {

    func assertEqualPDFDocuments(left: PDFDocument, right: PDFDocument) {
        guard left.pageCount == right.pageCount else {
            XCTFail("Documents have different page count")
            return
        }
       
        // Pages are rendered on dataRepresentation() only !?
        for i in 0..<left.pageCount {
            if let pageLeft = left.page(at: i),
               let pageRight = right.page(at: i) {
                XCTAssertEqual(pageLeft.rotation, pageRight.rotation, "Rotation of pdf page \(i) does not match.")
//                XCTAssertEqual(pageLeft.string, pageRight.string, "Content of pdf page \(i) does not match.")
                
                let dataLeft = pageLeft.thumbnail(of: .init(width: 1024, height: 1024), for: .mediaBox).png
                let dataRight = pageRight.thumbnail(of: .init(width: 1024, height: 1024), for: .mediaBox).png

                if (dataLeft != dataRight) {
                    if let diffImageData = diff(dataLeft, dataRight) {
                        add(XCTAttachment(uniformTypeIdentifier: "image/png", name: "diff image", payload: diffImageData, userInfo: nil))
                    }
                    
                    add(XCTAttachment(uniformTypeIdentifier: "image/png", name: "left image", payload: dataLeft, userInfo: nil))
                    add(XCTAttachment(uniformTypeIdentifier: "image/png", name: "right image", payload: dataRight, userInfo: nil))
                }
//                XCTAssertEqual(dataLeft, dataRight)
            } else {
                XCTFail("One page is missing or broken")
            }
        }
    }
}

fileprivate func diff(_ firstImageData: Data?, _ secondImageData: Data?) -> Data? {
    guard let firstImageData = firstImageData,
          let secondImageData = secondImageData,
          let first = CIImage(data: firstImageData),
          let second = CIImage(data: secondImageData) else { return nil }
    
    // https://github.com/Tylerflick/ImageDiff/blob/master/ImageDiff/CoreImageDiffer.swift#L48
    let kernelString = """
                        kernel vec4 naiveDiff(__sample first, __sample second) {
                            const vec4 same = vec4(255, 255, 255, 255);
                            const vec4 diff = vec4(0, 0, 0, 255);
                            return (first.r != second.r || first.g != second.g || first.b != second.b || first.a != second.a) ? diff : same;
                        }
                        """
    let kernel = CIColorKernel(source: kernelString)!

    guard let outputImage = kernel.apply(extent: first.extent, arguments: [first, second]) else { return nil }

    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
    #if os(macOS)
    return NSImage(cgImage: cgImage, size: outputImage.extent.size).png
    #else
    return UIImage(cgImage: cgImage).png
    #endif
}
