// swiftlint:disable file_length
// This file contains the complete AI chat overlay UI including models, helper views, and main content.
// The file length exceeds 400 lines due to the inherent complexity of the chat interface,
// but is well-organized with clear MARK sections for maintainability.
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

// MARK: - Liquid Glass Modifier

// Applies liquid glass effect on iOS 26+, falls back to ultraThinMaterial on earlier versions.
private struct LiquidGlassModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
        .glassEffect(
          .regular.interactive(false), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    } else {
      content
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }
}

// MARK: - Skill Item View

// Displays a single skill row in the skills box.
private struct SkillItemView: View {
  let skill: SkillMetadata
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // Skill icon in a circular background.
        Image(systemName: skill.iconName)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.black)
          .frame(width: 32, height: 32)
          .background(Color.black.opacity(0.08), in: Circle())

        // Skill name and description.
        VStack(alignment: .leading, spacing: 2) {
          Text(skill.displayName)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.black)

          Text(skill.description)
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.5))
            .lineLimit(1)
        }

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Header Components

// Hamburger menu button for opening chat history.
private struct HamburgerMenuButton: View {
  let action: () -> Void

  var body: some View {
    Button(
      action: action,
      label: {
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
    )
  }
}

// Model selection menu.
private struct ModelMenuView: View {
  @Binding var selectedModel: AIModel

  var body: some View {
    Menu(
      content: {
        ForEach(AIModel.allCases) { model in
          Button(
            action: {
              selectedModel = model
            },
            label: {
              HStack {
                Text(model.rawValue)
                if selectedModel == model {
                  Image(systemName: "checkmark")
                }
              }
            }
          )
        }
      },
      label: {
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
    )
  }
}

// Context selection menu with lightbulb fade animation.
private struct ContextMenuView: View {
  @Binding var selectedDashboardContext: DashboardContextScope
  @Binding var selectedNoteContext: NoteContextScope
  @Binding var isLightbulbVisible: Bool
  let contextDisplayValue: String
  let location: AIOverlayLocation
  let contextMenuOptions: AnyView

  var body: some View {
    Menu(
      content: {
        contextMenuOptions
      },
      label: {
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
    )
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
}

// Lightbulb button for opening skills box.
private struct LightbulbButton: View {
  @Binding var isSkillsBoxVisible: Bool
  @Binding var isLightbulbVisible: Bool

  var body: some View {
    Button(
      action: {
        withAnimation(.easeOut(duration: 0.15)) {
          isSkillsBoxVisible.toggle()
        }
      },
      label: {
        Image(systemName: "lightbulb")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.black)
          .frame(width: 40, height: 40)
          .background(.ultraThinMaterial, in: Circle())
      }
    )
    .opacity(isLightbulbVisible ? 1 : 0)
    .offset(x: isSkillsBoxVisible ? 60 : 0)
    .animation(.easeOut(duration: 0.15), value: isSkillsBoxVisible)
  }
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

  // Controls visibility of the skills box.
  @State private var isSkillsBoxVisible = false

  // Available skills loaded from SkillRegistry.
  @State private var availableSkills: [SkillMetadata] = []

  // Internal focus state to detect when input bar gains focus.
  @FocusState private var internalInputFocused: Bool

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
          LightbulbButton(
            isSkillsBoxVisible: $isSkillsBoxVisible,
            isLightbulbVisible: $isLightbulbVisible
          )
        }
        .padding(.trailing, 16)
        .padding(.top, 4)

        Spacer()

        // Chat input bar with focus binding for keyboard control.
        AIChatInputBar(text: $text, isFocused: $internalInputFocused) {
          onSend()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
      }
      .onChange(of: internalInputFocused) { _, focused in
        // Close skills box when input bar gains focus.
        if focused && isSkillsBoxVisible {
          withAnimation(.easeOut(duration: 0.15)) {
            isSkillsBoxVisible = false
          }
        }
      }
      // Skills box overlay - positioned relative to the main content, clipped to bounds.
      .overlay(alignment: .top) {
        // Invisible tap-catching layer to dismiss skills box when tapping outside it.
        // Excludes bottom 80pt (chat input bar area) so input bar taps pass through.
        if isSkillsBoxVisible {
          GeometryReader { geometry in
            Color.clear
              .contentShape(Rectangle())
              .frame(height: geometry.size.height - 80)
              .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                  isSkillsBoxVisible = false
                }
              }
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        skillsBox
      }
      .clipped()

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
    .task {
      // Load available skills from SkillRegistry.
      await loadSkills()
    }
  }

  // Header containing hamburger menu and dropdown selectors.
  private var headerView: some View {
    HStack(alignment: .center, spacing: 0) {
      // Hamburger menu button (two horizontal lines, top longer than bottom).
      HamburgerMenuButton {
        withAnimation(.easeOut(duration: 0.15)) {
          isChatHistoryVisible = true
        }
      }

      Spacer()

      // Native Apple Menu dropdowns side by side.
      HStack(spacing: 8) {
        // Model selector menu.
        ModelMenuView(selectedModel: $selectedModel)

        // Context selector menu.
        ContextMenuView(
          selectedDashboardContext: $selectedDashboardContext,
          selectedNoteContext: $selectedNoteContext,
          isLightbulbVisible: $isLightbulbVisible,
          contextDisplayValue: contextDisplayValue,
          location: location,
          contextMenuOptions: AnyView(contextMenuOptions)
        )
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 12)
    .padding(.top, 8)
  }

  // Skills box that slides in from the right side of the overlay with blurred edge.
  private var skillsBox: some View {
    let boxWidth: CGFloat = 260
    let boxHeight: CGFloat = 240
    let blurWidth: CGFloat = 20
    // Offset to fully hide the box off-screen.
    let hideOffset: CGFloat = boxWidth + 32

    return VStack(alignment: .leading, spacing: 0) {
      Text("Skills")
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.black)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)

      // Scrollable list of available skills from SkillRegistry.
      ScrollView {
        VStack(spacing: 0) {
          ForEach(availableSkills) { skill in
            SkillItemView(skill: skill) {
              handleSkillTapped(skill)
            }
          }
        }
      }
    }
    .frame(width: boxWidth, height: boxHeight)
    .modifier(LiquidGlassModifier())
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .mask(
      // Create a gradient mask that fades out the trailing edge.
      LinearGradient(
        gradient: Gradient(stops: [
          .init(color: .clear, location: 0.0),
          .init(
            color: .white,
            location: isSkillsBoxVisible ? 0.0 : (blurWidth / boxWidth)
          ),
          .init(color: .white, location: 1.0)
        ]),
        startPoint: .trailing,
        endPoint: .leading
      )
    )
    .padding(.top, 56)
    .padding(.trailing, 16)
    .offset(x: isSkillsBoxVisible ? 0 : hideOffset)
    .animation(.easeOut(duration: 0.15), value: isSkillsBoxVisible)
    .allowsHitTesting(isSkillsBoxVisible)
  }

  // Context menu options based on current location.
  @ViewBuilder
  private var contextMenuOptions: some View {
    switch location {
    case .dashboard, .folder:
      ForEach(DashboardContextScope.allCases) { scope in
        let displayTitle =
          (location == .folder && scope == .specificFolder)
          ? "This folder"
          : scope.rawValue

        Button(
          action: {
            selectedDashboardContext = scope
          },
          label: {
            HStack {
              Text(displayTitle)
              if selectedDashboardContext == scope {
                Image(systemName: "checkmark")
              }
            }
          }
        )
      }

    case .note:
      ForEach(NoteContextScope.allCases) { scope in
        Button(
          action: {
            selectedNoteContext = scope
          },
          label: {
            HStack {
              Text(scope.rawValue)
              if selectedNoteContext == scope {
                Image(systemName: "checkmark")
              }
            }
          }
        )
      }
    }
  }

  // Handle skill tap: insert skill prompt into chat, close skills box, and focus input.
  private func handleSkillTapped(_ skill: SkillMetadata) {
    // Insert skill-specific prompt into chat input.
    text = "/\(skill.id) "

    // Close the skills box.
    withAnimation(.easeOut(duration: 0.15)) {
      isSkillsBoxVisible = false
    }

    // Focus the input bar so user can continue typing.
    internalInputFocused = true
  }

  // Load skills from SkillRegistry asynchronously.
  private func loadSkills() async {
    let skills = await SkillRegistry.shared.allSkills()
    await MainActor.run {
      availableSkills = skills
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
      AIChatOverlayContent(text: .constant(""), location: .note, onSend: {})
        .frame(width: 400, height: 560)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial))
    }
  }
#endif
