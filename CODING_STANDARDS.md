# Coding standards

What code and commits in this repo have to look like. Read it before writing code; a reviewer checks a diff against it.

## Shared standards

The shared standards are generated from the Obsidian vault into `docs/coding-standards/` and never edited in the repo. See [docs/coding-standards/readme.md](docs/coding-standards/readme.md).

<!-- BEGIN shared file list: written by sync-coding-standards.py -->
<!-- END shared file list -->

## This repo

### Pull requests and issues

- Keep PR descriptions **concise and bullet-pointed**
- Use simple lists without elaborate explanations
- Focus on what changed, not why (code should be self-explanatory)
- No emoji (🤖 footer is acceptable)
- Example format:
  ```
  ## Changes
  - Removed background view from Share Extension
  - Updated storyboard constraints
  - Removed corner radius setup
  ```

### Commit messages

- Use conventional commits format: `feat:`, `fix:`, `refactor:`, etc.
- Keep first line under 72 characters
- Add brief bullet points in body if needed

### Branch naming

- **Always** use `feature/` prefix for all branches
- This applies to both new features and bug fixes
- Example: `feature/fix-share-extension-crash`, `feature/add-dark-mode`, `feature/update-dependencies`

### Code comments

- **ALL code comments MUST be in English**
- No exceptions for any programming language files
- Explain **why**, not what — the code already states what it does
- **Max 2 lines**; go longer only when the reason genuinely requires it, e.g. a
  non-obvious failure mode or a deliberately rejected alternative
- Delete comments that only restate the line below them

### Localization before every commit

- **CRITICAL**: Always check and update localizations before committing any code changes.

Before every commit:
1. Build the project with xcodebuild
2. Check localization files for stale/untranslated strings
3. Fix any localization issues
4. Then commit

### Platform-specific code

Use conditional compilation for platform differences:
```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

### Pitfalls

- **Don't** modify `Package.swift` to enable commented-out Swift features (MainActor default isolation, etc.) without checking the linked TCA/Dependencies GitHub issues
- **Always** use the naming convention helpers (`Document.createFilename()`) when saving documents
- **Remember** that `ArchiveStore` is an actor - all interactions must be `await`
- **Use** `@Shared` for state that needs to persist or be accessed across features
- **Test locale-dependent code** with German locale (`de_DE`) - this is the default test locale per `ArchiverLib.xctestplan`
