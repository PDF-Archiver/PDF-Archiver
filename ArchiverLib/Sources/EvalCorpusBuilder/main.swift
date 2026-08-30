//
//  main.swift
//  EvalCorpusBuilder
//
//  Builds the evaluation corpus from a folder of already-filed PDFs.
//

import EvaluationCorpus
import Foundation

// stdout is this tool's interface, not diagnostics - hence `print`, not a Logger.

let usage = "usage: EvalCorpusBuilder <pdf-folder> [-o <corpus.json>]"
let arguments = Array(CommandLine.arguments.dropFirst())

guard let folderPath = arguments.first, !folderPath.hasPrefix("-") else {
    print(usage)
    exit(2)
}

var outputPath = "corpus.json"
if let flagIndex = arguments.firstIndex(of: "-o") {
    guard arguments.count > flagIndex + 1 else {
        print(usage)
        exit(2)
    }
    outputPath = arguments[flagIndex + 1]
}

let output = URL(filePath: outputPath).standardizedFileURL
let outcome = try await CorpusBuilder.build(fromFolderAt: URL(filePath: folderPath).standardizedFileURL)

try CorpusDocument.data(from: outcome.documents).write(to: output)

print("\(outcome.documents.count) documents written to \(output.path(percentEncoded: false))")

let skipsByReason = Dictionary(grouping: outcome.skipped, by: \.reason)
for reason in skipsByReason.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
    let skipped = skipsByReason[reason] ?? []
    print("  skipped \(skipped.count) - \(reason.rawValue)")
    for entry in skipped.prefix(5) {
        print("    \(entry.filename)")
    }
    if skipped.count > 5 {
        print("    ... and \(skipped.count - 5) more")
    }
}

let dataset = EvaluationDataset(corpus: outcome.documents)
print("""
split: \(dataset.samples.count) evaluation samples, \
\(dataset.contextDocuments.count) context documents, \
\(dataset.tagVocabulary.count) tags in vocabulary, \
typical description length \(dataset.typicalSpecificationWords.lowerBound)-\
\(dataset.typicalSpecificationWords.upperBound) words
""")
