import SwiftUI

// MARK: - Models

// Available AI models for the chat.
enum AIModel: String, CaseIterable, Identifiable {
  case gemini25Flash = "Gemini 2.5 Flash"

  var id: String { rawValue }
}

// Context scope options when user is in the dashboard or a folder.
enum DashboardContextScope: String, CaseIterable, Identifiable {
  case auto = "Auto"
  case chatOnly = "Chat-only"
  case specificNote = "Specific note"
  case specificFolder = "Specific folder"
  case allNotes = "All notes"

  var id: String { rawValue }
}

// Context scope options when user is in a note.
enum NoteContextScope: String, CaseIterable, Identifiable {
  case auto = "Auto"
  case chatOnly = "Chat-only"
  case selection = "Selection"
  case thisPage = "This page"
  case thisNote = "This note"
  case otherNote = "Other note"
  case specificFolder = "Specific folder"
  case allNotes = "All notes"

  var id: String { rawValue }
}

// Represents where the user currently is in the app.
enum AIOverlayLocation {
  case dashboard
  case folder
  case note
}

// MARK: - Main Content View

// Reusable content view for the AI chat overlay.
// Contains the hamburger menu button, model/context selectors, chat history sidebar, and chat input bar.
// Can be embedded in both SwiftUI and UIKit contexts.
struct AIChatOverlayContent: View {
  // Text entered in the chat input bar.
  @Binding var text: String
  // External focus control binding for keyboard.
  var isFocused: FocusState<Bool>.Binding?
  // Called when the send button is tapped.
  var onSend: () -> Void
  // The current location in the app (determines context options).
  var location: AIOverlayLocation

  // Controls visibility of the chat history sidebar.
  @State private var isChatHistoryVisible = false

  // Controls visibility of the lightbulb button (fades when context menu tapped).
  @State private var isLightbulbVisible = true

  // Currently selected AI model.
  @State private var selectedModel: AIModel = .gemini25Flash
  // Currently selected context scope for dashboard/folder.
  @State private var selectedDashboardContext: DashboardContextScope = .allNotes
  // Currently selected context scope for notes.
  @State private var selectedNoteContext: NoteContextScope = .thisPage

  // Placeholder chat history items for UI development.
  @State private var chatHistoryItems: [AIChatItem] = [
    AIChatItem(title: "UI vs Backend Prioritization"),
    AIChatItem(title: "MVP Features for Notetaking"),
    AIChatItem(title: "iOS App Auth Strategy"),
    AIChatItem(title: "UI Change Workflow Optimization"),
    AIChatItem(title: "Prompt Improvement Request"),
    AIChatItem(title: "Speech to Text MacOS"),
    AIChatItem(title: "App Review and Security"),
    AIChatItem(title: "Chat Bar Expansion Design")
  ]

  // Corner radius for clipping the sidebar.
  private let cornerRadius: CGFloat = 24

  // The display value for the context dropdown based on location.
  private var contextDisplayValue: String {
    switch location {
    case .dashboard:
      return selectedDashboardContext.rawValue
    case .folder:
      // Show "This folder" as the default display when in a folder.
      if selectedDashboardContext == .specificFolder {
        return "This folder"
      }
      return selectedDashboardContext.rawValue
    case .note:
      return selectedNoteContext.rawValue
    }
  }

  var body: some View {
    ZStack {
      // Main content with hamburger menu at top and chat bar at bottom.
      VStack(spacing: 0) {
        // Header with hamburger menu button and dropdown selectors.
        headerView

        // Lightbulb button row aligned to the right.
        HStack {
          Spacer()
          lightbulbButton
        }
        .padding(.trailing, 16)
        .padding(.top, 4)

        Spacer()

        // Chat input bar with focus binding for keyboard control.
        AIChatInputBar(text: $text, isFocused: isFocused) {
          onSend()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
      }

      // Chat history sidebar (slides in from left).
      AIChatHistorySidebar(
        isVisible: $isChatHistoryVisible,
        chatItems: chatHistoryItems,
        onNewChat: {
          // Clear current chat to start new one.
          text = ""
        },
        onSelectChat: { _ in
          // Load selected chat (placeholder for now).
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    .onAppear {
      // Set default context based on location.
      switch location {
      case .dashboard:
        selectedDashboardContext = .allNotes
      case .folder:
        selectedDashboardContext = .specificFolder
      case .note:
        selectedNoteContext = .thisPage
      }
    }
  }

  // Header containing hamburger menu and dropdown selectors.
  private var headerView: some View {
    HStack(alignment: .center, spacing: 0) {
      // Hamburger menu button (two horizontal lines, top longer than bottom).
      Button(action: {
        withAnimation(.easeOut(duration: 0.15)) {
          isChatHistoryVisible = true
        }
      }) {
        VStack(alignment: .leading, spacing: 4) {
          RoundedRectangle(cornerRadius: 1)
            .fill(Color.black)
            .frame(width: 18, height: 2)
          RoundedRectangle(cornerRadius: 1)
            .fill(Color.black)
            .frame(width: 12, height: 2)
        }
        .frame(width: 44, height: 44)
      }

      Spacer()

      // Native Apple Menu dropdowns side by side.
      HStack(spacing: 8) {
        // Model selector menu.
        modelMenu

        // Context selector menu.
        contextMenu
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 12)
    .padding(.top, 8)
  }

  // Native Apple Menu for model selection with liquid glass styling.
  private var modelMenu: some View {
    Menu {
      ForEach(AIModel.allCases) { model in
        Button(action: {
          selectedModel = model
        }) {
          HStack {
            Text(model.rawValue)
            if selectedModel == model {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text("Model:")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.black)

        Text(selectedModel.rawValue)
          .font(.system(size: 14))
          .foregroundColor(Color(white: 0.5))

        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(Color(white: 0.5))
      }
      .fixedSize()
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
  }

  // Native Apple Menu for context selection with liquid glass styling.
  private var contextMenu: some View {
    Menu {
      contextMenuOptions
    } label: {
      HStack(spacing: 4) {
        Text("Context:")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.black)

        Text(contextDisplayValue)
          .font(.system(size: 14))
          .foregroundColor(Color(white: 0.5))

        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(Color(white: 0.5))
      }
      .fixedSize()
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
    .simultaneousGesture(
      TapGesture()
        .onEnded { _ in
          // Fade out the lightbulb button when context menu is tapped.
          withAnimation(.easeOut(duration: 0.15)) {
            isLightbulbVisible = false
          }
          // Fade back in after a delay.
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.2)) {
              isLightbulbVisible = true
            }
          }
        }
    )
  }

  // Circular lightbulb button with glass styling.
  private var lightbulbButton: some View {
    Button(action: {
      // Placeholder action - does nothing for now.
    }) {
      Image(systemName: "lightbulb")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(.black)
        .frame(width: 40, height: 40)
        .background(.ultraThinMaterial, in: Circle())
    }
    .opacity(isLightbulbVisible ? 1 : 0)
  }

  // Context menu options based on current location.
  @ViewBuilder
  private var contextMenuOptions: some View {
    switch location {
    case .dashboard, .folder:
      ForEach(DashboardContextScope.allCases) { scope in
        let displayTitle = (location == .folder && scope == .specificFolder)
          ? "This folder"
          : scope.rawValue

        Button(action: {
          selectedDashboardContext = scope
        }) {
          HStack {
            Text(displayTitle)
            if selectedDashboardContext == scope {
              Image(systemName: "checkmark")
            }
          }
        }
      }

    case .note:
      ForEach(NoteContextScope.allCases) { scope in
        Button(action: {
          selectedNoteContext = scope
        }) {
          HStack {
            Text(scope.rawValue)
            if selectedNoteContext == scope {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    }
  }

  // Initializer with optional focus binding and location for context options.
  init(
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding? = nil,
    location: AIOverlayLocation = .note,
    onSend: @escaping () -> Void
  ) {
    self._text = text
    self.isFocused = isFocused
    self.location = location
    self.onSend = onSend
  }
}

#if DEBUG
struct AIChatOverlayContent_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 20) {
      // Note context preview.
      ZStack {
        Color.gray.opacity(0.3)
          .ignoresSafeArea()

        AIChatOverlayContent(
          text: .constant(""),
          location: .note,
          onSend: {}
        )
        .frame(width: 400, height: 560)
        .background(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
        )
      }

      // Dashboard context preview.
      ZStack {
        Color.gray.opacity(0.3)
          .ignoresSafeArea()

        AIChatOverlayContent(
          text: .constant(""),
          location: .dashboard,
          onSend: {}
        )
        .frame(width: 400, height: 560)
        .background(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
        )
      }
    }
  }
}
#endif
