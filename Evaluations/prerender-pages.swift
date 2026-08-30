//
//  prerender-pages.swift
//  Evaluations
//
//  Renders the first page of a sample of corpus documents, for the runs that
//  attach the page image.
//

import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

// stdout is this tool's interface, not diagnostics - hence `print`, not a Logger.

let usage = "usage: prerender-pages.swift <archive-root> <corpus.json> <output-folder>"
let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count == 3 else {
    print(usage)
    exit(2)
}

// The archive root, not a flat folder: documents sit in their year subfolder.
let archive = URL(filePath: arguments[0]).standardizedFileURL
let corpus = URL(filePath: arguments[1]).standardizedFileURL
let out = URL(filePath: arguments[2]).standardizedFileURL
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

struct Doc: Decodable { let filename: String }
let docs = try JSONDecoder().decode([Doc].self, from: Data(contentsOf: corpus))
    .sorted { $0.filename < $1.filename }
let step = max(2, docs.count / 25)
let samples = docs.enumerated().filter { $0.offset % step == 0 }.map(\.element)

var rendered = 0
var failed = 0
for doc in samples {
    let src = archive.appending(path: String(doc.filename.prefix(4))).appending(path: doc.filename)
    guard let page = PDFDocument(url: src)?.page(at: 0) else { failed += 1; print("  missing: \(doc.filename)"); continue }
    let bounds = page.bounds(for: .mediaBox)
    let scale = 1000 / max(bounds.width, bounds.height)
    let width = Int(bounds.width * scale)
    let height = Int(bounds.height * scale)
    guard let context = CGContext(data: nil,
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        failed += 1
        continue
    }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -bounds.minX, y: -bounds.minY)
    page.draw(with: .mediaBox, to: context)
    guard let image = context.makeImage() else { failed += 1; continue }
    let dst = out.appending(path: doc.filename).deletingPathExtension().appendingPathExtension("png")
    guard let sink = CGImageDestinationCreateWithURL(dst as CFURL, UTType.png.identifier as CFString, 1, nil) else { failed += 1; continue }
    CGImageDestinationAddImage(sink, image, nil)
    if CGImageDestinationFinalize(sink) { rendered += 1 } else { failed += 1 }
}
print("rendered: \(rendered), failed: \(failed)")
