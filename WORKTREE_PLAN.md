# InkOS Parallel Development Worktree Plan

## Overview

This plan organizes the feature work into **8 parallel worktrees** that minimize file conflicts while maximizing developer parallelization. Each worktree is designed so a developer can work independently with minimal coordination.

---

## Dependency Graph

```
                    ┌─────────────────┐
                    │      main       │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ dashboard-    │   │ search-       │   │ ai-backend    │
│ polish        │   │ complete      │   │               │
│ (independent) │   │ (independent) │   │ (foundational)│
└───────────────┘   └───────┬───────┘   └───────┬───────┘
                            │                   │
                            │           ┌───────┴───────┐
                            │           │               │
                            ▼           ▼               ▼
                    ┌───────────────┐ ┌─────────┐ ┌─────────────┐
                    │ search-canvas │ │ ai-chat │ │ lessons     │
                    │ (needs search)│ │         │ │             │
                    └───────────────┘ └────┬────┘ └─────────────┘
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │ skills      │
                                    │ (needs chat)│
                                    └─────────────┘
```

---

## Worktree Structure

```
InkOS/
├── .git/                           # Main git directory
├── main/                           # Main integration branch (or work directly in root)
│
└── worktrees/
    ├── dashboard-polish/           # Branch: feature/dashboard-polish
    ├── search-complete/            # Branch: feature/search-complete
    ├── search-canvas/              # Branch: feature/search-canvas
    ├── ai-backend/                 # Branch: feature/ai-backend
    ├── ai-chat/                    # Branch: feature/ai-chat
    ├── lessons/                    # Branch: feature/lessons
    ├── skills/                     # Branch: feature/skills
    └── pdf-improvements/           # Branch: feature/pdf-improvements
```

---

## Worktree Details

### 1. `dashboard-polish` (Independent - No Dependencies)

**Developer Focus:** Dashboard UI/UX polish and bug fixes

**Files Touched:**
- `InkOS/Features/Dashboard/DashboardView.swift`
- `InkOS/Features/Dashboard/DashboardComponents.swift`
- `InkOS/Features/Dashboard/FolderCard.swift`
- `InkOS/Features/Dashboard/FolderOverlay.swift`
- `InkOS/Features/Dashboard/FolderDraggableCards.swift`
- `InkOS/Features/Dashboard/ContextMenuOverlay.swift`
- `InkOS/Features/Dashboard/DashboardAlerts.swift`
- `InkOS/Features/Dashboard/NotebookLibrary.swift`
- `InkOS/Features/Dashboard/UIKitDragWrapper.swift`
- `InkOS/App/AppRootView.swift` (loading animation)

**Tasks:**
- [ ] Fix previews in folder overlay after drag and drop
- [ ] Folder overlay shouldn't close when note opened from folder
- [ ] Exiting note in folder returns to folder overlay, not main dashboard
- [ ] No plus button animation on folder open
- [ ] Add animated blur around folder overlay
- [ ] Top cards/folders shouldn't look under top bar on long press
- [ ] Make rename, delete, and "no notes" UI cleaner
- [ ] Fluid "snapping notebooks" animation on add/delete/move
- [ ] Improve loading notes animation on startup
- [ ] Apply all card animations to folder context
- [ ] Make plus not pressable if context menu is up
- [ ] Make context menu buttons more tactile/satisfying
- [ ] Make context menu taller with more curved corners
- [ ] Only dim area OUTSIDE folder overlay, not behind
- [ ] Folder card size preservation on long press release
- [ ] Folder card size preservation on rename/delete context menu
- [ ] Notebook/folder card expand more on long press
- [ ] Prevent folder UI from stretching infinitely
- [ ] Scrolling works well in dashboard and folder UI
- [ ] Blank note has no icon in previews (just blank)
- [ ] Fix folder overlay tap glitch (repeated fast open/close)

**Estimated Effort:** 1 developer, medium complexity

---

### 2. `search-complete` (Independent - No Dependencies)

**Developer Focus:** Search service layer and Dashboard/Folder search UI

**Files Touched (NEW):**
- `InkOS/Features/Search/Service/SearchService.swift` (modify existing)
- `InkOS/Features/Search/Service/SearchResult.swift` (new)
- `InkOS/Features/Search/UI/Dashboard/DashboardSearchBar.swift` (new)
- `InkOS/Features/Search/UI/Dashboard/DashboardSearchResults.swift` (new)
- `InkOS/Features/Search/UI/Folder/FolderSearchOverlay.swift` (new)

**Files Touched (Minimal Modifications):**
- `InkOS/Features/Dashboard/DashboardView.swift` (add search icon - ~5 lines)
- `InkOS/Features/Dashboard/FolderOverlay.swift` (add search icon - ~5 lines)

**Tasks (Phases 2-4):**
- [ ] Phase 2: Complete SearchService actor
  - [ ] `searchAll(query:)` - Dashboard search
  - [ ] `searchInFolder(query:folderID:)` - Folder-scoped search
  - [ ] Load manifests for folder paths in results
  - [ ] Generate snippets with 50 chars context
- [ ] Phase 3: Dashboard Search UI
  - [ ] Add search icon to toolbar
  - [ ] Create search overlay (glass effect)
  - [ ] TextField with 250ms debounce
  - [ ] Scrollable results list with result cards
  - [ ] Empty state and no results state
- [ ] Phase 4: Folder Search UI
  - [ ] Add search icon to folder header
  - [ ] Reuse DashboardSearchResults with folder scope

**Estimated Effort:** 1 developer, medium complexity

**Conflict Note:** Minimal overlap with `dashboard-polish` - just adding search icons. Coordinate on DashboardView.swift and FolderOverlay.swift additions.

---

### 3. `search-canvas` (Depends on: search-complete)

**Developer Focus:** In-note search with canvas highlight rendering

**Files Touched (NEW):**
- `InkOS/Features/Search/UI/Editor/InNoteSearchBar.swift` (new)
- `InkOS/Features/Search/UI/Editor/InNoteSearchViewModel.swift` (new)

**Files Touched (Modifications):**
- `InkOS/Features/Search/Service/SearchService.swift` (add searchInNote method)
- `InkOS/Editor/EditorViewController.swift` (add floating search bar)
- `InkOS/Frameworks/Ink/UIObjects/Canvas.swift` (highlight rendering)
- `InkOS/Frameworks/Ink/Rendering/DisplayViewModel.swift` (highlight state)

**Tasks (Phases 5-8):**
- [ ] Phase 5: In-Note Search Data Layer
  - [ ] Implement `searchInNote()` returning matches with bounding boxes
  - [ ] Parse JIIX for matching labels with JIIXElement.boundingBox
  - [ ] PDF: Use PDFKit PDFPage.selection for text bounds
  - [ ] Sort matches by page, Y position, X position
- [ ] Phase 6: In-Note Search UI
  - [ ] UIKit search bar (glass pill style)
  - [ ] TextField, match counter, prev/next buttons, close button
  - [ ] InNoteSearchViewModel for query/matches/currentIndex
  - [ ] Prev/next cycles with wrap
- [ ] Phase 7: Canvas Highlight Rendering
  - [ ] Add `searchHighlights: [CGRect]` to Canvas
  - [ ] Add `currentHighlightIndex` for current match styling
  - [ ] Implement `drawSearchHighlights()` after drawPDFBackground()
  - [ ] Coordinate transform: mm to screen coordinates
- [ ] Phase 8: Navigation and Polish
  - [ ] Scroll canvas to center match
  - [ ] Loading state for slow searches
  - [ ] Edge cases (empty notes, no matches, overlapping)

**Estimated Effort:** 1 developer, high complexity

**Merge Order:** Merge `search-complete` first, then continue this work.

---

### 4. `ai-backend` (Independent - Foundational)

**Developer Focus:** Complete RAG backend infrastructure (Firebase + iOS)

**Files Touched (Firebase - NEW/MODIFY):**
- `Firebase/functions/src/embeddings.ts` (exists - enhance)
- `Firebase/functions/src/chat.ts` (new - streaming chat)
- `Firebase/functions/src/index.ts` (modify)
- `Firebase/functions/package.json` (add dependencies)

**Files Touched (iOS - MODIFY existing):**
- `InkOS/Features/AIIndexing/VectorStore/EmbeddingService.swift`
- `InkOS/Features/AIIndexing/VectorStore/VectorStoreClient.swift`
- `InkOS/Features/AIIndexing/Indexing/IndexingCoordinator.swift`
- `InkOS/Storage/JIIXPersistenceService.swift` (add notification)

**Files Touched (iOS - NEW):**
- `InkOS/Features/AI/CloudKitChatStorage.swift` (new)
- `InkOS/Features/AI/ChatModels.swift` (new)
- `InkOS/Features/AI/AIService.swift` (new - calls Firebase functions)

**Tasks:**
- [ ] Firebase Functions
  - [ ] Complete embeddings function with batch processing
  - [ ] Create `sendMessage` HTTP endpoint
  - [ ] Create `streamMessage` HTTP endpoint with SSE
  - [ ] Deploy functions
- [ ] iOS - Complete AIIndexing
  - [ ] Finish EmbeddingService (call Firebase function)
  - [ ] Finish VectorStoreClient (Firestore CRUD)
  - [ ] Add save notification to JIIXPersistenceService
  - [ ] Test full indexing pipeline
- [ ] iOS - CloudKit Chat Storage
  - [ ] Define Chat and Message record types
  - [ ] Implement CloudKitChatStorage actor
  - [ ] CRUD operations for chats and messages
- [ ] iOS - AI Service Layer
  - [ ] AIService actor to call Firebase functions
  - [ ] Streaming response handling
  - [ ] Context embedding into messages

**Estimated Effort:** 1-2 developers, high complexity

**Priority:** HIGH - Many features depend on this

---

### 5. `ai-chat` (Depends on: ai-backend)

**Developer Focus:** Chat overlay UI accessible from dashboard and editor

**Files Touched (NEW):**
- `InkOS/Features/AI/Views/AIChatOverlay.swift`
- `InkOS/Features/AI/Views/ChatListSidebar.swift`
- `InkOS/Features/AI/Views/ChatMessageView.swift`
- `InkOS/Features/AI/Views/ScopeSelector.swift`
- `InkOS/Features/AI/ViewModels/ChatViewModel.swift`
- `InkOS/Features/AI/ViewModels/ChatListViewModel.swift`

**Files Touched (Modifications):**
- `InkOS/Editor/AIButtonView.swift` (modify existing)
- `InkOS/Editor/AIOverlayView.swift` (may replace or enhance)
- `InkOS/Editor/AIChatInputBar.swift` (modify existing)
- `InkOS/Features/Dashboard/DashboardView.swift` (add AI button)
- `InkOS/App/AppRootView.swift` (overlay presentation)

**Tasks:**
- [ ] Chat Overlay Architecture
  - [ ] Single overlay accessible from dashboard and editor
  - [ ] Chat list sidebar on left
  - [ ] Message thread on right
  - [ ] Floating presentation over current view
- [ ] Scope Selector
  - [ ] Dashboard/Folder scopes: Auto, Chat-only, Specific note, Specific folder, All notes
  - [ ] Editor scopes: Auto, Chat-only, Selection, This page, This note, Other note, Specific folder, All notes
  - [ ] Per-message scope selection
  - [ ] Default scope based on context
- [ ] Chat Interactions
  - [ ] Send message with selected scope
  - [ ] Stream AI response display
  - [ ] Stop generation button
  - [ ] Edit/resend message
  - [ ] Edit previous messages (restart from there)
- [ ] Chat Management
  - [ ] List of chats
  - [ ] New chat creation
  - [ ] Chat title (auto-generated or manual)
  - [ ] Delete chat

**Estimated Effort:** 1 developer, high complexity

**Merge Order:** Merge `ai-backend` first.

---

### 6. `lessons` (Depends on: ai-backend)

**Developer Focus:** Interactive lessons feature end-to-end

**Files Touched (NEW - Storage):**
- `InkOS/Storage/LessonBundle.swift`
- `InkOS/Storage/LessonManifest.swift`

**Files Touched (NEW - Models):**
- `InkOS/Features/Lesson/Models/LessonModel.swift`
- `InkOS/Features/Lesson/Models/LessonSection.swift`
- `InkOS/Features/Lesson/Models/LessonProgress.swift`

**Files Touched (NEW - Views):**
- `InkOS/Features/Lesson/Views/LessonView.swift`
- `InkOS/Features/Lesson/Views/LessonSectionView.swift`
- `InkOS/Features/Lesson/Views/ContentSectionView.swift`
- `InkOS/Features/Lesson/Views/VisualSectionView.swift`
- `InkOS/Features/Lesson/Views/QuestionSectionView.swift`
- `InkOS/Features/Lesson/Views/SummarySectionView.swift`
- `InkOS/Features/Lesson/Views/SectionBlurOverlay.swift`
- `InkOS/Features/Lesson/Views/AnswerComparisonView.swift`

**Files Touched (NEW - ViewModels):**
- `InkOS/Features/Lesson/ViewModels/LessonViewModel.swift`
- `InkOS/Features/Lesson/ViewModels/QuestionViewModel.swift`

**Files Touched (NEW - Generation):**
- `InkOS/Features/Lesson/Generation/LessonGenerator.swift`
- `InkOS/Features/Lesson/Generation/LessonPromptBuilder.swift`
- `InkOS/Features/Lesson/Generation/VisualGenerator.swift`

**Files Touched (NEW - Dashboard):**
- `InkOS/Features/Dashboard/LessonCard.swift`

**Files Touched (Modifications):**
- `InkOS/Features/Dashboard/DashboardItem.swift` (add .lesson case)
- `InkOS/Storage/BundleManager.swift` (add lesson operations)

**Tasks:**
- [ ] Phase 1: Foundation
  - [ ] LessonModel, LessonSection Codable structs
  - [ ] LessonBundle storage in BundleManager
  - [ ] Add .lesson to DashboardItem
  - [ ] LessonCard for dashboard
- [ ] Phase 2: Static Lesson View
  - [ ] LessonView scroll container
  - [ ] ContentSectionView (Markdown)
  - [ ] SummarySectionView
  - [ ] QuestionSectionView (multiple choice - no AI)
  - [ ] Section blur overlay with toggle
- [ ] Phase 3: Question Interactivity
  - [ ] Handwriting input (reuse MyScript)
  - [ ] Keyboard toggle
  - [ ] Math input (MyScript math mode)
  - [ ] AnswerComparisonService for AI feedback
  - [ ] AnswerComparisonView
- [ ] Phase 4: Visual Sections
  - [ ] ImageGenerationService
  - [ ] VisualSectionView for static images
  - [ ] WKWebView for interactive visuals
- [ ] Phase 5: Lesson Generation
  - [ ] LessonPromptBuilder
  - [ ] LessonGenerator with streaming
  - [ ] PDF extraction for hybrid lessons
  - [ ] Generation UI
- [ ] Phase 6: Polish
  - [ ] Section regeneration
  - [ ] Progress persistence
  - [ ] Dashboard card states
  - [ ] Folder integration

**Estimated Effort:** 1-2 developers, very high complexity

**Note:** Can start Phase 1-2 in parallel with ai-backend (no AI calls needed). Phases 3-5 need ai-backend.

---

### 7. `skills` (Depends on: ai-chat)

**Developer Focus:** AI-powered skills (MVP features)

**Files Touched (NEW):**
- `InkOS/Features/Skills/SkillsManager.swift`
- `InkOS/Features/Skills/SkillModels.swift`
- `InkOS/Features/Skills/AutoOrganizer/AutoOrganizerSkill.swift`
- `InkOS/Features/Skills/PseudocodeRunner/PseudocodeRunnerSkill.swift`
- `InkOS/Features/Skills/VoiceToHandwriting/VoiceToHandwritingSkill.swift`
- `InkOS/Features/Skills/VisualGenerator/VisualGeneratorSkill.swift`
- `InkOS/Features/Skills/AROverlay/AROverlaySkill.swift`
- `InkOS/Features/Skills/AppGenerator/AppGeneratorSkill.swift`
- `InkOS/Features/Skills/AppGenerator/MyAppsView.swift`

**Files Touched (Modifications):**
- `InkOS/Features/AI/Views/AIChatOverlay.swift` (skill invocation UI)
- `InkOS/Editor/EditorViewController.swift` (skill result rendering)

**Tasks:**
- [ ] Skills Infrastructure
  - [ ] SkillsManager to register and invoke skills
  - [ ] SkillModels for common types
  - [ ] Skill invocation from chat
- [ ] Individual Skills
  - [ ] Auto note organizer (rearrange strokes on canvas)
  - [ ] Pseudocode runner (execute code, return output)
  - [ ] Voice to handwriting (speech recognition → ink)
  - [ ] Visual generator (image gen API → drag to note)
  - [ ] AR note overlay (camera + overlay rendering)
  - [ ] App generator (generate mini-apps, "My Apps" tab)
- [ ] AI Settings
  - [ ] Allow user to disable all AI features

**Estimated Effort:** 2-3 developers (skills can be parallelized internally), very high complexity

**Note:** Each skill can be a sub-branch if needed for more parallelization.

---

### 8. `pdf-improvements` (Independent)

**Developer Focus:** PDF import, display, and integration improvements

**Files Touched:**
- `InkOS/Features/PDFImport/PDFImport.swift`
- `InkOS/Features/PDFImport/PDFDataModel.swift`
- `InkOS/Features/PDFDisplay/PDFEditorHostView.swift`
- `InkOS/Features/PDFDisplay/PDFEditorViewController.swift`
- `InkOS/Features/Dashboard/DashboardComponents.swift` (PDF card appearance)

**Tasks:**
- [ ] PDF shows in folder preview correctly
- [ ] PDF notes have same animations as normal notes (dashboard + folders)
- [ ] PDF preview shows last-viewed page like normal note cards
- [ ] Improve loading UI when PDF imports (not grey popup)
- [ ] Improve PDF card appearance when no preview available
- [ ] Support PDF import from other apps (file provider)
- [ ] Support drag and drop PDF from Files app
- [ ] PDF can be imported directly into a folder

**Estimated Effort:** 1 developer, medium complexity

---

## Setup Commands

```bash
# Navigate to project root
cd /Users/andrewallen/Desktop/swift_projects/InkOS

# Create worktrees directory
mkdir -p worktrees

# Create all worktrees
git worktree add worktrees/dashboard-polish -b feature/dashboard-polish
git worktree add worktrees/search-complete -b feature/search-complete
git worktree add worktrees/search-canvas -b feature/search-canvas
git worktree add worktrees/ai-backend -b feature/ai-backend
git worktree add worktrees/ai-chat -b feature/ai-chat
git worktree add worktrees/lessons -b feature/lessons
git worktree add worktrees/skills -b feature/skills
git worktree add worktrees/pdf-improvements -b feature/pdf-improvements
```

---

## Merge Strategy

### Wave 1 (Parallel - No Dependencies)
These can all be developed and merged independently:
1. `dashboard-polish`
2. `search-complete`
3. `ai-backend`
4. `pdf-improvements`

### Wave 2 (After Wave 1 Dependencies)
These need Wave 1 branches merged first:
5. `search-canvas` ← needs `search-complete`
6. `ai-chat` ← needs `ai-backend`
7. `lessons` (Phase 1-2 can start in Wave 1) ← needs `ai-backend` for Phases 3+

### Wave 3 (After Wave 2 Dependencies)
8. `skills` ← needs `ai-chat`

---

## Conflict Zones (Coordinate Carefully)

| File | Branches That Touch It |
|------|------------------------|
| `DashboardView.swift` | dashboard-polish, search-complete, ai-chat |
| `FolderOverlay.swift` | dashboard-polish, search-complete |
| `DashboardItem.swift` | lessons |
| `EditorViewController.swift` | search-canvas, ai-chat, skills |
| `Canvas.swift` | search-canvas |
| `BundleManager.swift` | lessons |
| `AppRootView.swift` | dashboard-polish, ai-chat |

**Recommendation:** Have one person be the "integration lead" for each conflicting file. They review PRs touching that file and resolve conflicts.

---

## Developer Assignment Suggestion

| Developer | Worktree(s) | Skills Needed |
|-----------|-------------|---------------|
| Dev 1 | `dashboard-polish` | SwiftUI animations, UIKit |
| Dev 2 | `search-complete` + `search-canvas` | SQLite, SwiftUI, Canvas rendering |
| Dev 3 | `ai-backend` | Firebase, TypeScript, CloudKit |
| Dev 4 | `ai-chat` | SwiftUI, streaming, state management |
| Dev 5 | `lessons` | SwiftUI, MyScript, WKWebView |
| Dev 6 | `skills` | Various (can split skills among multiple devs) |
| Dev 7 | `pdf-improvements` | PDFKit, SwiftUI, file providers |

**Minimum viable team:** 4 developers
- Dev A: dashboard-polish + pdf-improvements
- Dev B: search-complete + search-canvas
- Dev C: ai-backend + ai-chat
- Dev D: lessons + skills

---

## Timeline View (Waves)

```
Week 1-2:  ████████ dashboard-polish
           ████████ search-complete
           ████████ ai-backend
           ████████ pdf-improvements
           ████░░░░ lessons (Phase 1-2 only)

Week 3-4:  ░░░░████ search-canvas (after search-complete)
           ░░░░████ ai-chat (after ai-backend)
           ░░░░████ lessons (Phase 3-6)

Week 5-6:  ░░░░░░░░████ skills (after ai-chat)
```

---

## Quick Reference: What Can Run in Parallel RIGHT NOW

These 5 worktrees can start immediately with zero coordination:

1. **dashboard-polish** - Pure UI work, no shared dependencies
2. **search-complete** - Service + UI, minimal DashboardView touch
3. **ai-backend** - Firebase + iOS backend, isolated
4. **pdf-improvements** - PDF-specific work, isolated
5. **lessons** (Phase 1-2) - Models and static views, can start without AI
