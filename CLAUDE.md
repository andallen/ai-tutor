# Alan Project Structure

## Project Overview

Alan is an iPad app built with SwiftUI and the MyScript iink SDK for handwriting recognition. It features a tutoring agent (Alan) that generates interactive notebook content through a subagent architecture.

## Module Organization

```
Alan/
├── InkOS/                                # App source root
│   ├── InkOSApp.swift                    # App entry point
│   ├── InkOS-Bridging-Header.h           # Exposes MyScript Obj-C headers to Swift
│   ├── Info.plist                        # App configuration
│   ├── theme.css                         # Styling for text rendering
│   │
│   ├── App/                              # High-level navigation
│   │   └── AppRootView.swift             # Root view
│   │
│   ├── Features/                         # Feature Modules
│   │   ├── Alan/                         # Alan tutoring agent system
│   │   │   ├── Core/                     # Core types and contracts
│   │   │   │   ├── AlanContract.swift           # Request/response types, VisualIntent, SubagentRequest
│   │   │   │   └── AlanError.swift              # Error types for Alan operations
│   │   │   │
│   │   │   ├── Networking/               # API communication
│   │   │   │   ├── AlanAPIClient.swift          # HTTP client for Alan and subagents
│   │   │   │   ├── AlanEndpoints.swift          # Firebase endpoint URLs
│   │   │   │   └── SSEParser.swift              # Server-sent events parser for streaming
│   │   │   │
│   │   │   └── Orchestration/            # Response processing
│   │   │       ├── OrchestrationActor.swift     # Coordinates Alan + subagent flow
│   │   │       ├── BlockFactory.swift           # Creates blocks from subagent responses
│   │   │       └── OutputParser.swift           # Parses Alan structured output
│   │   │
│   │   ├── Auth/                         # Authentication
│   │   │   └── AuthManager.swift                # Firebase authentication manager
│   │   │
│   │   ├── Block/                        # Block primitive system (content model)
│   │   │   ├── Core/                     # Core block types
│   │   │   │   ├── BlockContract.swift          # Block, BlockID, BlockType, BlockStatus
│   │   │   │   └── BlockContent.swift           # BlockContent enum (type-erased content)
│   │   │   │
│   │   │   ├── Content/                  # Content type definitions
│   │   │   │   ├── TextContent.swift            # Text block content
│   │   │   │   ├── ImageContent.swift           # Image block content
│   │   │   │   ├── GraphicsContent.swift        # Interactive graphics (Chart.js, p5.js, etc.)
│   │   │   │   ├── TableContent.swift           # Table block content
│   │   │   │   ├── EmbedContent.swift           # Embedded content (PhET, GeoGebra, etc.)
│   │   │   │   ├── InputContent.swift           # User input block content
│   │   │   │   └── CheckpointContent.swift      # Checkpoint block content
│   │   │   │
│   │   │   ├── Rendering/                # Block rendering utilities
│   │   │   │   └── HTMLRenderer.swift           # HTML rendering for graphics content
│   │   │   │
│   │   │   └── Views/                    # Standalone block views
│   │   │       └── GraphicsBlockView.swift      # Graphics block WebView rendering
│   │   │
│   │   ├── Memory/                       # Long-term memory system
│   │   │   ├── MemoryContract.swift             # Memory types and structures
│   │   │   ├── MemoryManager.swift              # Client-side memory operations
│   │   │   ├── MemoryAPIClient.swift            # Memory API communication
│   │   │   └── FirestoreMemoryStorage.swift     # Local memory caching
│   │   │
│   │   ├── Notebook/                     # Notebook UI and data models
│   │   │   ├── Core/                     # Core notebook contracts
│   │   │   │   └── NotebookContract.swift       # Notebook, Page, NotebookID
│   │   │   │
│   │   │   ├── Design/                   # Design system
│   │   │   │   └── NotebookDesignTokens.swift   # Colors, fonts, spacing tokens
│   │   │   │
│   │   │   ├── Preview/                  # SwiftUI previews
│   │   │   │   └── NotebookPreviews.swift       # Preview providers for notebook views
│   │   │   │
│   │   │   ├── ViewModels/               # View models
│   │   │   │   └── NotebookViewModel.swift      # Notebook state and orchestration
│   │   │   │
│   │   │   └── Views/                    # UI components
│   │   │       ├── NotebookCanvasView.swift     # Main notebook canvas
│   │   │       ├── BlockContainerView.swift     # Block layout container
│   │   │       ├── PendingBlockView.swift       # Loading state for blocks
│   │   │       │
│   │   │       ├── AlanPresence/         # Alan avatar animation
│   │   │       │   ├── AlanPresenceState.swift  # Presence state machine
│   │   │       │   ├── AlanPresenceView.swift   # Presence UI component
│   │   │       │   ├── MetaballMetalView.swift  # Metal rendering for metaballs
│   │   │       │   └── MetaballShader.metal     # Metal shader for animation
│   │   │       │
│   │   │       └── Blocks/               # Individual block views
│   │   │           ├── TextBlockView.swift      # Text rendering with markdown
│   │   │           ├── ImageBlockView.swift     # Image display
│   │   │           ├── TableBlockView.swift     # Table rendering
│   │   │           ├── GraphicsBlockView.swift  # Interactive graphics
│   │   │           ├── EmbedBlockView.swift     # Embedded content (iframes)
│   │   │           ├── InputBlockView.swift     # User input fields
│   │   │           ├── CheckpointBlockView.swift # Checkpoint markers
│   │   │           │
│   │   │           └── Text/             # Text rendering components
│   │   │               ├── PlainTextView.swift  # Plain text rendering
│   │   │               ├── CodeBlockView.swift  # Syntax-highlighted code
│   │   │               ├── LaTeXView.swift      # LaTeX math rendering
│   │   │               ├── KineticTextView.swift # Animated text effects
│   │   │               └── Animations/
│   │   │                   └── TypewriterAnimationView.swift
│   │   │
│   │   └── Shared/                       # Shared utilities
│   │       ├── UIComponents.swift               # Color extensions, UI modifiers
│   │       ├── FileLogger.swift                 # Debug logging utility
│   │       └── ContextMenuView.swift            # Reusable context menu
│   │
│   ├── Editor/                           # Editor canvas components
│   │   ├── EditorViewModel.swift                # Editor state management
│   │   ├── EditorUIComponents.swift             # Tool palette and editor UI
│   │   └── HomeButtonView.swift                 # Home navigation button
│   │
│   ├── Storage/                          # Persistence Layer
│   │   ├── BundleStorage.swift                  # Directory path helpers
│   │   ├── SDKProtocols.swift                   # SDK protocol definitions
│   │   └── JIIXPersistence/                     # JIIX format persistence
│   │       └── JIIXPersistenceService.swift     # Persistence service
│   │
│   ├── Frameworks/
│   │   └── Ink/                          # MyScript SDK Wrappers
│   │       ├── EngineProvider.swift             # MyScript engine singleton
│   │       │
│   │       ├── Input/                    # Touch/Pen input handling
│   │       │   ├── InputViewController.swift
│   │       │   └── InputViewModel.swift
│   │       │
│   │       ├── Rendering/                # Display & rendering logic
│   │       │   ├── DisplayViewController.swift
│   │       │   └── DisplayViewModel.swift
│   │       │
│   │       ├── UIObjects/                # Core UI rendering components
│   │       │   ├── Canvas.swift
│   │       │   ├── InputView.swift
│   │       │   ├── RenderView.swift
│   │       │   └── OffscreenRenderSurfaces.swift
│   │       │
│   │       ├── SmartGuide/               # Text conversion guide UI
│   │       │   ├── SmartGuideViewController.h
│   │       │   └── SmartGuideViewController.mm
│   │       │
│   │       └── Utils/                    # Utility helpers
│   │           ├── FontMetricsProvider.swift
│   │           ├── ImageLoader.swift
│   │           ├── ImagePainter.swift
│   │           ├── TextFormatHelper.swift
│   │           ├── IInkUIRefImplUtils.swift
│   │           ├── ContextualActionsHelper.swift
│   │           ├── Helper.swift
│   │           ├── Path.swift
│   │           ├── SynchronizedSwift.swift
│   │           ├── UIFont+Helper.swift
│   │           ├── NSFileManager+Additions.swift
│   │           ├── NSAttributedString+Helper.swift
│   │           └── CTRun+Metrics.swift
│   │
│   └── Assets.xcassets                   # App assets
│
├── InkOSTests/                           # Unit test suite
│   ├── Features/
│   │   ├── Alan/                         # Alan agent tests
│   │   │   ├── AlanContractTests.swift          # Contract type tests
│   │   │   └── SSEParserTests.swift             # SSE parsing tests
│   │   ├── Block/                        # Block tests
│   │   │   ├── BlockTests.swift                 # Core block tests
│   │   │   └── TextContentTests.swift           # Text content tests
│   │   ├── Memory/                       # Memory system tests
│   │   │   └── MemoryContractTests.swift        # Memory contract tests
│   │   └── Notebook/                     # Notebook tests
│   │       └── NotebookDocumentTests.swift      # Notebook document tests
│   │
│   └── Rendering/
│       ├── DisplayViewModelTests.swift
│       └── OffscreenRenderSurfacesTests.swift
│
├── InkOSUITests/                         # UI test suite
│   └── InkOSUITests.swift
│
├── Firebase/                             # Firebase backend services
│   ├── firebase.json                     # Firebase configuration
│   ├── firestore.indexes.json            # Firestore index definitions
│   └── functions/                        # Cloud Functions
│       ├── src/                          # TypeScript source files
│       │   ├── index.ts                         # Function exports
│       │   ├── config.ts                        # Configuration
│       │   ├── embeddings.ts                    # Embedding utilities
│       │   ├── files.ts                         # File operations
│       │   │
│       │   ├── __tests__/                # Jest test suites
│       │   │   ├── alan/                 # Alan agent tests
│       │   │   │   ├── alanAgent.test.ts
│       │   │   │   ├── outputSchema.test.ts
│       │   │   │   └── sessionModelIntegration.test.ts
│       │   │   └── memory/               # Memory system tests
│       │   │       ├── llmProcessor.test.ts
│       │   │       ├── memorySchema.test.ts
│       │   │       ├── memorySubagent.test.ts
│       │   │       └── rules.test.ts
│       │   │
│       │   ├── alan/                     # Alan agent endpoint
│       │   │   ├── alanAgent.ts                 # Main Alan agent with Gemini
│       │   │   ├── alanPrompts.ts               # System prompts for Alan
│       │   │   └── outputSchema.ts              # Structured output schema
│       │   │
│       │   ├── memory/                   # Long-term memory system
│       │   │   ├── memorySchema.ts              # Memory types and structures
│       │   │   ├── memorySubagent.ts            # Memory operations endpoint
│       │   │   ├── llmProcessor.ts              # LLM-based memory extraction
│       │   │   └── rules.ts                     # Memory importance scoring
│       │   │
│       │   └── subagents/                # Subagent system
│       │       ├── types.ts                     # Shared types (VisualIntent, SubagentRequest, etc.)
│       │       ├── subagentRouter.ts            # Main router endpoint
│       │       ├── visualRouter.ts              # Routes visual requests to subagents
│       │       ├── tableSubagent.ts             # Table generation subagent
│       │       ├── imageSubagent.ts             # Image search/generation subagent
│       │       ├── graphicsSubagent.ts          # Interactive graphics subagent
│       │       ├── embedSubagent.ts             # Embed provider subagent
│       │       │
│       │       └── apis/                 # External image library APIs
│       │           ├── index.ts                 # API aggregator
│       │           ├── types.ts                 # Shared API types
│       │           ├── artInstituteChicago.ts   # Art Institute of Chicago API
│       │           ├── libraryOfCongress.ts     # Library of Congress API
│       │           ├── metMuseum.ts             # Metropolitan Museum API
│       │           ├── nasa.ts                  # NASA Image Library API
│       │           ├── pubchem.ts               # PubChem chemical structures API
│       │           ├── smithsonian.ts           # Smithsonian Open Access API
│       │           └── wikimedia.ts             # Wikimedia Commons API
│       │
│       ├── jest.config.js                # Jest test configuration
│       ├── package.json                  # Node.js dependencies
│       └── tsconfig.json                 # TypeScript configuration
│
├── MyScriptCertificate/                  # License Key
│   ├── MyCertificate.h
│   └── me.andy.allen.Trivial.c
│
├── Scripts/                              # Build & Utility Scripts
│   ├── buildapp                          # Build executable
│   ├── testapp                           # Test executable
│   ├── test-ui                           # UI test runner
│   ├── run-ui-tests                      # Extended UI test runner
│   ├── html-preview                      # HTML preview script
│   └── retrieve_recognition-assets.sh    # Download recognition assets
│
├── Docs/                                 # Reference documentation
│   ├── myscript_docs.md
│   ├── myscript_headers.txt
│   ├── myscript-reference.txt
│   └── NotebookDesignSystem.md           # Notebook UI design specifications
│
├── apple-hig/                            # Apple Human Interface Guidelines reference
│
├── recognition-assets/                   # MyScript recognition data (binary)
│   └── resources/
│       ├── en_US/                        # English language resources
│       ├── math/                         # Math recognition
│       └── shape/                        # Shape recognition
│
├── Podfile                               # CocoaPods dependency specification
├── Podfile.lock                          # Locked dependency versions
└── Pods/                                 # CocoaPods dependencies (generated)
```

## Architecture Overview

### Alan Agent System

Alan is the main tutoring agent that generates notebook content. It uses a subagent architecture:

1. **Alan Agent** (`alan/alanAgent.ts`) - Main tutoring agent powered by Gemini. Outputs Text/Input blocks directly and delegates Table/Visual blocks to specialized subagents. Supports session model tracking and memory context.

2. **Subagent Router** (`subagents/subagentRouter.ts`) - Dispatches requests to appropriate subagents based on `target_type`.

3. **Visual Router** (`subagents/visualRouter.ts`) - Routes visual requests to image, graphics, or embed subagents based on intent.

4. **Subagents**:
   - **Table** - Generates table content
   - **Image** - Searches educational image libraries (NASA, Wikimedia, museums, PubChem, etc.)
   - **Graphics** - Creates interactive visualizations (Chart.js, p5.js, Three.js, JSXGraph)
   - **Embed** - Matches to embed providers (PhET, GeoGebra, Desmos, YouTube)

5. **Memory System** (`memory/`) - Manages long-term user context:
   - **memorySchema** - Defines memory types (facts, preferences, concepts)
   - **memorySubagent** - Endpoint for memory operations
   - **llmProcessor** - Extracts memorable information from conversations
   - **rules** - Scores memory importance for retention

### iOS Orchestration

The iOS app coordinates with the backend through:

1. **OrchestrationActor** - Sends messages to Alan, processes streaming responses, dispatches subagent requests in parallel. Manages session model and memory context.
2. **AlanAPIClient** - HTTP client for Alan and subagent endpoints
3. **SSEParser** - Parses server-sent events for streaming responses
4. **BlockFactory** - Creates Block instances from subagent responses
5. **MemoryManager** - Client-side memory operations and caching
6. **AuthManager** - Firebase authentication management

### Notebook UI System

The notebook UI is built with SwiftUI and Metal:

1. **NotebookViewModel** - Coordinates notebook state, block management, and Alan orchestration
2. **NotebookCanvasView** - Main scrollable canvas displaying blocks
3. **BlockContainerView** - Handles layout and animations for individual blocks
4. **Block Views** - Specialized views for each content type (Text, Image, Table, Graphics, Embed, Input, Checkpoint)
5. **AlanPresence** - Animated avatar using Metal shaders for metaball effects

## Project Rules

### 1. Comments
- Comment frequently with simple and direct language
- Concisely spell out what every part of the code is doing, making the logic easy to follow
- Use clear grammar and avoid special headers, decorative markers, or section labels
- Be impersonal; no first/second/third person

### 2. Quality Assurance
- Make errors explicit. Do not use force unwraps (`!`), `try!`, or `fatalError` for expected runtime issues
- Use `throws` and pass error messages back to the UI so the user can be notified

### 3. Security & Configuration
- Do not commit private keys or license material beyond the checked-in certificate files
- Treat `recognition-assets/` as large binary dependencies; avoid editing by hand

## Build Commands

- **Build iOS**: `Scripts/buildapp`
- **Test iOS**: `Scripts/testapp`
- **UI Test iOS**: `Scripts/test-ui`
- **Build Firebase**: `cd Firebase/functions && npm run build`
- **Test Firebase**: `cd Firebase/functions && npm test`
- **Deploy Firebase**: `cd Firebase && firebase deploy --only functions`
