# ContentExtractorExample

A minimal Swift Package example for using `ContentExtractorStore` with Apple Intelligence (FoundationModels).

## Requirements

- **iOS 26.0+** or **macOS 26.0+**
- Swift 6.2+
- Apple Intelligence available on device

## Overview

This example demonstrates:
- Using `LanguageModelSession` from FoundationModels
- Implementing custom tools for Apple Intelligence
- Extracting document information (description and tags) from text
- Mock implementation without external dependencies (except SDK)

## Structure

```
ContentExtractorExample/
├── Sources/
│   └── ContentExtractorExample/
│       ├── AppleIntelligenceAvailability.swift  # Availability status
│       ├── MockTagCountTool.swift                # Mock tool with fixed data
│       ├── ExampleContentExtractorStore.swift    # Main extractor
│       └── Example.swift                         # Example runner
└── Tests/
    └── ContentExtractorExampleTests/
        └── ExampleTests.swift                    # Unit tests
```

## Features

### MockTagCountTool

A tool that returns predefined tag frequencies instead of analyzing real documents:

```swift
let mockTags = [
    "rechnung": 45,
    "vertrag": 32,
    "versicherung": 28,
    // ...
]
```

### ExampleContentExtractorStore

An actor that:
- Initializes LanguageModelSession with MockTagCountTool
- Analyzes document texts
- Extracts descriptions and tags
- Works with German/current locale

### Mock Documents

The example includes four mock documents:
1. **MediaMarkt Invoice** - Electronics invoice
2. **Rental Contract** - Apartment rental agreement
3. **Medical Report** - Medical report
4. **Car Insurance** - Insurance policy

## Usage

### As a Library

```swift
import ContentExtractorExample

if #available(iOS 26, macOS 26, *) {
    // Check availability
    let availability = ExampleContentExtractorStore.getAvailability()
    guard availability.isUsable else { return }

    // Create store and prewarm
    let store = ExampleContentExtractorStore()
    await store.prewarm()

    // Process document
    let text = "Your invoice for..."
    if let result = try await store.extract(from: text) {
        print("Description: \(result.specification)")
        print("Tags: \(result.tags)")
    }
}
```

### Running the Example

```swift
if #available(iOS 26, macOS 26, *) {
    await Example.run()
}
```

## Build & Test

```bash
# Build
cd Examples/ContentExtractorExample
swift build

# Run tests
swift test

# For specific platform
swift build --triple arm64-apple-macosx      # Apple Silicon
swift build --triple x86_64-apple-macosx     # Intel
```

## Notes

- This package has **no external dependencies** (only Foundation/FoundationModels)
- All data is mock data - no real documents are used
- The package only runs on iOS 26+ / macOS 26+ (FoundationModels availability)
- Apple Intelligence must be available on the device

## Architecture

### Concurrency

- `ExampleContentExtractorStore` is an `actor` for thread-safe access
- All async/await operations use Swift 6 strict concurrency
- `@available` guards ensure platform compatibility

### Tool System

The tool system is based on the `Tool` protocol from FoundationModels:
- `@Generable` for automatic encoding/decoding
- `@Guide` for AI hints on tool usage
- Async `call()` method for execution

## Limitations

- Maximum prompt length: 3500 characters
- Maximum response tokens: 512
- Maximum tags per document: 10
- No parallel requests (only one `extract()` operation at a time)

## License

See main repository
