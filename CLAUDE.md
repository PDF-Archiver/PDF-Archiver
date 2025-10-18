# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PDF Archiver is a cross-platform (iOS/macOS) document management app that helps users organize and tag PDF documents using a specific naming convention: `yyyy-mm-dd--description__tag1_tag2.pdf`. The app supports both local and iCloud storage, with features like document scanning, OCR, tagging, and search.

## Architecture

### Multi-Platform Structure
- **iOS/**: iOS-specific app entry point (`PDFArchiverIOSApp.swift`)
- **macOS/**: macOS-specific app entry point (`PDFArchiverMacApp.swift`)
- **Shared/**: Platform-agnostic views and app intents
- **ArchiverLib/**: Core business logic as a Swift Package (SPM)
- **Widget/**: Widget extension
- **ShareExtension/**: Share extension for importing documents
- **AppClip/**: App Clip for quick access
- **UITests iOS/**: UI tests

### ArchiverLib Package Structure (Swift Package Manager)

The core logic is organized into separate SPM targets in `ArchiverLib/`:

- **ArchiverFeatures**: Main UI features using TCA (Composable Architecture)
  - `AppFeature`: Root feature coordinating tabs and document lists
  - `ArchiveList`: Tagged documents list and search
  - `UntaggedDocumentList`: Inbox for untagged documents
  - `DocumentDetails`: Document viewer
  - `DocumentInformationForm`: Tag/date/description editor
  - `Settings`: App settings and premium management
  - `Statistics`: Usage statistics

- **ArchiverStore**: Document storage and folder management
  - `ArchiveStore`: Main actor-based document repository
  - `FolderProvider` protocol with implementations:
    - `ICloudFolderProvider`: iCloud Drive integration
    - `LocalFolderProvider`: Local filesystem
    - `DemoFolderProvider`: Demo mode (DEBUG only)
  - `DirectoryDeepWatcher`: File system observation

- **ArchiverModels**: Core data models
  - `Document`: Main document model with URL, date, specification, tags
  - `PremiumStatus`, `PDFQuality`, `StorageType`

- **ArchiverDocumentProcessing**: PDF processing and file naming logic

- **ContentExtractorStore**: Text extraction and OCR

- **ArchiverIntents**: App Intents for iOS 16+ (note: must be defined in main app due to SPM limitations, see `Shared/AppIntent.swift`)

- **Shared**: Shared utilities and extensions for TCA

### State Management

Uses **The Composable Architecture (TCA)** from Point-Free for unidirectional data flow and state management. Key patterns:
- `@Reducer` macro for feature reducers
- `@ObservableState` for observable state
- `@Shared` property wrapper for cross-feature state persistence
- Dependency injection via `@Dependency` macro

### Document Naming Convention

Files follow this strict pattern:
```
YYYY-MM-DD--description__tag1_tag2_tag3.pdf
```
- Date: ISO format (`yyyy-mm-dd`)
- Description: lowercase, spaces removed
- Tags: lowercase, underscore-separated, sorted alphabetically
- All special characters removed for filesystem compatibility

Documents are organized into year-based folders (e.g., `Archive/2024/...`).

### Concurrency

The codebase uses Swift 6 strict concurrency:
- `ArchiverStore` is an `actor` for thread-safe document management
- Experimental features enabled: `StrictConcurrency`, some targets use `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`
- All async operations use async/await
- Uses `AsyncExtensions` and `swift-async-algorithms` for stream handling

## Development Commands

### Building

**IMPORTANT**: Always prefer `xcodebuild` over `swift build` for the main app targets, as it uses the same build cache as Xcode and properly handles code signing, app bundles, and extensions.

```bash
# Build iOS app
xcodebuild -workspace PDFArchiver.xcworkspace \
           -scheme PDFArchiver \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           -configuration Debug \
           build

# Build macOS app
xcodebuild -workspace PDFArchiver.xcworkspace \
           -scheme PDFArchiver \
           -destination 'platform=macOS' \
           -configuration Debug \
           build

# Build just the ArchiverLib package (for testing/development)
# Note: This does NOT build the full app with extensions and code signing
cd ArchiverLib
swift build

# Build for specific architecture
swift build --triple arm64-apple-macosx      # Apple Silicon
swift build --triple x86_64-apple-macosx     # Intel
```

### Testing

```bash
# Run all tests via xcodebuild
xcodebuild test -workspace PDFArchiver.xcworkspace -scheme PDFArchiver -testPlan ArchiverLib.xctestplan

# Run ArchiverLib package tests directly
cd ArchiverLib
swift test

# Run specific test target
swift test --filter ArchiverFeaturesTests
swift test --filter ArchiverStoreTests
swift test --filter ArchiverDocumentProcessingTests
```

### Linting

```bash
# Run SwiftLint (configured via .swiftlint.yml)
swiftlint lint

# Auto-fix violations
swiftlint --fix
```

SwiftLint configuration excludes `.build` directories and `Shared` folder. Notable opt-in rules include `force_unwrapping`, `sorted_imports`, and `multiline_parameters`.

## Key Technical Decisions

### Why AppIntents are in Shared/ not ArchiverLib/
Swift Package Manager doesn't support App Intents directly, so they must be defined in the main app target. See `Shared/AppIntent.swift` and the comment referencing [this StackOverflow answer](https://stackoverflow.com/a/76976224).

### Storage Providers
The app automatically selects the appropriate `FolderProvider` based on the folder URL:
- iCloud containers use `ICloudFolderProvider`
- Local paths use `LocalFolderProvider`
- Demo mode uses `DemoFolderProvider` (when `UserDefaults` key `demoMode` is set)

### Document Loading Flow
1. `ArchiveStore.update()` initializes folder providers
2. Providers watch for file system changes via `DirectoryDeepWatcher`
3. Changes stream through `documentsStream` → `AppFeature` → UI updates
4. TCA's `@Shared(.documents)` propagates state to all features

### Platform-Specific Code
Use conditional compilation for platform differences:
```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

## Common Pitfalls

- **Don't** modify `Package.swift` to enable commented-out Swift features (MainActor default isolation, etc.) without checking the linked TCA/Dependencies GitHub issues
- **Always** use the naming convention helpers (`Document.createFilename()`) when saving documents
- **Remember** that `ArchiveStore` is an actor - all interactions must be `await`
- **Use** `@Shared` for state that needs to persist or be accessed across features
- **Test locale-dependent code** with German locale (`de_DE`) - this is the default test locale per `ArchiverLib.xctestplan`

## CI/CD

GitHub Actions workflow (`.github/workflows/pr.yml`):
- Runs SwiftLint on changed files only
- Uses `stanfordbdhg/action-swiftlint@v4`

## Dependencies

Main dependencies (from `ArchiverLib/Package.swift`):
- `swift-composable-architecture` (v1.22.3+): State management
- `swift-dependencies` (v1.10.0+): Dependency injection
- `swift-sharing` (v2.7.4+): Shared state persistence
- `AsyncExtensions` (v0.5.4+): Async utilities
- `swift-async-algorithms` (v1.0.4+): Async sequence algorithms

## Demo Mode

Enable demo mode for testing without real file system operations:
```swift
UserDefaults.standard.set(true, forKey: "demoMode")
```
This switches to `DemoFolderProvider` in DEBUG builds.
