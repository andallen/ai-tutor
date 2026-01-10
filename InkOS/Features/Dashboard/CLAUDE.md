## Dashboard UI Consistency

When modifying note card UI or animations in the dashboard, apply the same changes to all note card contexts to maintain a unified experience:

1. **Dashboard grid** - `UIKit/DashboardViewController.swift` using cell classes in `UIKit/Cells/`
2. **Folder overlay** - `UIKit/Overlays/FolderOverlayViewController.swift` using `FolderOverlayCell`
3. **Card views** - `DashboardCardView.swift` contains base class and specialized card views (NotebookCardView, PDFCardView, FolderCardView, LessonCardView)

This includes changes to:
- Card dimensions, aspect ratios, corner radii
- Press/tap animations and feedback
- Shadow styling
- Context menu behavior
- Thumbnail rendering and placeholders

Similarly, folder card changes in `DashboardCardView.swift` (FolderCardView class) should be reflected in `FolderOverlayViewController.swift`'s thumbnail grid for seamless expand/collapse animations.
