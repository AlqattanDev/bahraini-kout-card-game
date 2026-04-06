## 2025-01-20 - Adding Accessibility to Interactive Elements
**Learning:** In Flutter, `GestureDetector` components representing actionable items lack built-in accessibility. Screen readers and tooltips require explicit implementation.
**Action:** Always wrap custom interactive components (like `GestureDetector`) with `Semantics` and `Tooltip` to ensure they are accessible. For `IconButton` widgets, always provide a `tooltip` property.
