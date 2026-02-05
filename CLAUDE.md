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

### NSSplitView Animation State Protection

When animating `NSSplitViewItem.isCollapsed` and trying to restore a saved size afterward, `splitViewDidResizeSubviews` fires multiple times during the animation. If you read/save state in that delegate, it can overwrite your saved value with intermediate (wrong) values before your completion handler runs.

**Solution:** Use a flag to block state updates during animation:

```swift
private var isAnimatingToggle = false

func togglePanel() {
    let wasCollapsed = item.isCollapsed
    isAnimatingToggle = true  // Block saves during animation

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        item.animator().isCollapsed.toggle()
    } completionHandler: { [weak self] in
        // Restore saved size if expanding
        if wasCollapsed, let height = self?.savedHeight {
            DispatchQueue.main.async {
                self?.splitView.setPosition(...)
                self?.isAnimatingToggle = false  // Re-enable saves
            }
        } else {
            self?.isAnimatingToggle = false
        }
    }
}

override func splitViewDidResizeSubviews(_ notification: Notification) {
    guard !isAnimatingToggle else { return }  // Skip during animation
    saveState()
}
```

See `RestSplitViewController.toggleBottomPanel()` for the full implementation.
