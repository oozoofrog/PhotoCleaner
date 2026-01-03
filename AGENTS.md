# AGENTS.md - PhotoCleaner

Guidelines for AI agents working in this iOS/SwiftUI codebase.

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build (Release)
xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -configuration Release build

# Run all tests
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17'

# Run single test file
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PhotoCleanerTests/PhotoIssueTests

# Run single test method
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PhotoCleanerTests/PhotoIssueTests/issueTypeDisplayNameNotEmpty
```

## Project Structure

```
PhotoCleaner/
├── Sources/
│   ├── DesignSystem/     # Design tokens (colors, spacing, typography)
│   ├── Models/           # Data models (PhotoIssue, IssueType, etc.)
│   ├── Services/         # Business logic (PhotoScanService, PhotoPermissionService)
│   ├── ViewModels/       # @Observable state management
│   └── Views/            # SwiftUI views organized by feature
│       ├── Components/   # Reusable UI components
│       ├── Dashboard/    # Main dashboard screen
│       └── IssueList/    # Issue list screen
├── PhotoCleanerApp.swift # App entry point
PhotoCleanerTests/
├── TestSupport/          # Test helpers (TestDataGenerator)
└── *Tests.swift          # Test files using Swift Testing framework
```

## Code Style Guidelines

### Imports
- Group imports: Foundation/standard library first, then frameworks (SwiftUI, Photos, Vision), then local modules
- Use `@testable import PhotoCleaner` in test files
- Avoid unused imports

### Naming Conventions
- Types: `PascalCase` (e.g., `PhotoIssue`, `DashboardViewModel`)
- Variables/functions: `camelCase` (e.g., `scanProgress`, `detectIssues()`)
- Constants: `camelCase` (e.g., `largeFileThreshold`)
- Enums: `PascalCase` type, `camelCase` cases (e.g., `IssueType.downloadFailed`)

### Swift Concurrency
- Use `actor` for thread-safe services (e.g., `PhotoScanService`)
- Use `@MainActor` for UI-related classes and view models
- Use `@Observable` macro for state management (iOS 17+)
- Mark async closures with `@Sendable` when crossing actor boundaries
- Prefer `async/await` over completion handlers

```swift
// Good: Actor for thread safety
actor PhotoScanService {
    private var cachedResult: ScanResult?
    
    func scanAll(progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void) async throws -> ScanResult
}

// Good: @Observable ViewModel
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var appState: AppState = .needsPermission
}
```

### SwiftUI Patterns
- Use `@Bindable` for `@Observable` objects in views
- Prefer computed properties for derived state
- Use `@ViewBuilder` for conditional view construction
- Extract complex views into private computed properties or separate structs

### Design Tokens
Always use design tokens from `DesignTokens.swift`:

```swift
// Colors
AppColor.primary, AppColor.textPrimary, AppColor.backgroundSecondary

// Spacing (8pt grid)
Spacing.xs (4pt), Spacing.sm (8pt), Spacing.md (16pt), Spacing.lg (24pt)

// Typography
Typography.headline, Typography.body, Typography.caption

// Corner Radius
CornerRadius.sm (8pt), CornerRadius.md (12pt)

// Button Styles
.buttonStyle(.primary), .buttonStyle(.secondary), .buttonStyle(.destructive)
```

### Error Handling
- Use Swift's native error handling (`throws`, `try`, `catch`)
- Provide meaningful error messages for user-facing errors
- Never use empty catch blocks
- Avoid force unwrapping (`!`) except in tests or when guaranteed safe

### File Headers
```swift
//
//  FileName.swift
//  PhotoCleaner
//
//  Brief description of the file's purpose (optional)
//
```

### MARK Comments
Use MARK comments for code organization:
```swift
// MARK: - Properties
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Helper Methods
```

## Testing Guidelines

### Framework
Use Swift Testing framework (not XCTest):

```swift
import Testing
@testable import PhotoCleaner

@Suite("FeatureName Tests")
struct FeatureNameTests {
    
    @Test("descriptive test name in Korean or English")
    func testMethodName() async throws {
        // Arrange
        let sut = ...
        
        // Act
        let result = ...
        
        // Assert
        #expect(result == expected)
    }
}
```

### Test Patterns
- Use `@Suite` for grouping related tests
- Use `@Test` with descriptive string for each test
- Use `@MainActor` when testing UI-related code
- Use `TestDataGenerator` for random test data
- Parameterized tests: `@Test("description", arguments: 1...100)`

### Assertions
```swift
#expect(value == expected)
#expect(value != unexpected)
#expect(collection.isEmpty)
#expect(!string.isEmpty)
#expect(throws: SomeError.self) { try riskyOperation() }
```

## Architecture

- **MVVM**: Views → ViewModels → Services
- **Data Flow**: PhotoKit → PhotoScanService (Actor) → DashboardViewModel (@MainActor) → SwiftUI View
- **Dependency Injection**: Pass services via initializers

## Key Types

| Type | Purpose |
|------|---------|
| `PhotoIssue` | Represents a photo with an issue |
| `IssueType` | Enum: downloadFailed, corrupted, screenshot, largeFile, duplicate |
| `IssueSeverity` | Enum: info, warning, critical |
| `ScanResult` | Contains scan results with issues and summaries |
| `DuplicateGroup` | Groups of duplicate photos |
| `LargeFileSizeOption` | Threshold options for large file detection |

## Common Patterns

### Async Image Loading
```swift
.task {
    await loadThumbnail()
}
```

### Progress Reporting
```swift
func scan(progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void) async throws
```

### PHAsset Extension
```swift
PHAsset.asset(withIdentifier: identifier)  // Fetch by local identifier
```

## Don'ts

- Don't use `as any`, `@ts-ignore` equivalents - fix type issues properly
- Don't suppress concurrency warnings with `@unchecked Sendable`
- Don't commit code with build errors
- Don't use hardcoded colors/spacing - use design tokens
- Don't create new UI without following existing patterns
- Don't use completion handlers when async/await is available
