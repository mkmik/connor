# Connor Make Claude

## Instructions for Claude

When making important architectural decisions during development, update this file to document them. This helps maintain context across sessions and ensures consistency.

### What to document:
- Key architectural patterns chosen and why
- Important technology/library choices
- Non-obvious design decisions with rationale
- Conventions established for the codebase

## Architectural Decisions

### Preferences Backward Compatibility

When adding new fields to the `Preferences` struct in `Models/Preferences.swift`:

1. **Use `decodeIfPresent` in the custom decoder** - New fields must have fallback defaults so old saved preferences load correctly
2. **Update both initializers** - The memberwise `init()` and `init(from decoder:)` must include the new field
3. **Test with old preferences** - Verify that existing user preferences aren't reset when upgrading

Example pattern for new fields:
```swift
// In init(from decoder:)
newField = try container.decodeIfPresent(Type.self, forKey: .newField) ?? defaultValue
```

This prevents the JSON decoder from failing when loading preferences saved before the new field existed.
