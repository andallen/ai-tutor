## Dashboard UI Consistency

When modifying note card UI or animations in the dashboard, apply the same changes to all note card contexts to maintain a unified experience:

1. **Dashboard grid** - `DashboardView.swift` via `NotebookCardButton`
2. **Folder overlay** - `FolderOverlay.swift` (uses the same `NotebookCardButton`)
3. **PDF note cards** - If present, ensure PDF-specific card views match the same styling

This includes changes to:
- Card dimensions, aspect ratios, corner radii
- Press/tap animations and feedback
- Shadow styling
- Context menu behavior
- Drag-and-drop visual states
- Thumbnail rendering and placeholders

Similarly, folder card changes in `FolderCard.swift` should be reflected in `FolderOverlay.swift`'s collapsed state thumbnail grid, which replicates the folder card's appearance for seamless expand/collapse animations.
