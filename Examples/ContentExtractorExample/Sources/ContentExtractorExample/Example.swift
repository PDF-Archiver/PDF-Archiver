//
//  Example.swift
//  ContentExtractorExample
//
//  Minimal example showing how to use ExampleContentExtractorStore with mock documents
//

import FoundationModels
import Playgrounds

extension Transcript.Entry {
    var toolCallCount: Int {
        switch self {
        case .toolCalls(let calls):
            print(calls)
            return calls.count
        default:
            return 0
        }
    }
}

#Playground {
    // Create store and prewarm
    let store = ExampleContentExtractorStore()
    await store.prewarm()

    // Process mock documents
    let text = MockDocuments.invoice
//    let text = MockDocuments.contract
//    let text = MockDocuments.medicalReport
//    let text = MockDocuments.insurance
    
    let result = try await store.extract(from: text)
    guard let result else { return }
    
    for entry in result.transcriptEntries {
        switch entry {
        case .toolCalls(let calls):
            for call in calls {
                print("ToolCall: \(call)")
            }
        default:
            break
        }
    }
    
    let toolCalls = result.transcriptEntries.map(\.toolCallCount).reduce(0, +)
    
    print("Tool calls: \(toolCalls)")
    print(result.content)
}
