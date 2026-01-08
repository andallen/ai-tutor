import SwiftUI

// Represents a single chat conversation in the history.
struct AIChatItem: Identifiable {
  let id: UUID
  let title: String
  let lastUpdated: Date

  init(id: UUID = UUID(), title: String, lastUpdated: Date = Date()) {
    self.id = id
    self.title = title
    self.lastUpdated = lastUpdated
  }
}

// Chat history sidebar that slides in from the left.
// Shows a list of previous chats with a "New Chat" button at the top.
struct AIChatHistoryView: View {
  // Binding to control visibility (for dismissal).
  @Binding var isVisible: Bool
  // List of chat items to display.
  let chatItems: [AIChatItem]
  // Called when user taps "New Chat" button.
  var onNewChat: () -> Void
  // Called when user selects a chat from the list.
  var onSelectChat: (AIChatItem) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with "New Chat" button.
      HStack {
        Spacer()

        // New chat button (compose icon).
        Button(action: {
          onNewChat()
        }) {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.black)
            .frame(width: 44, height: 44)
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)

      // Chat list.
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(chatItems) { item in
            Button(action: {
              onSelectChat(item)
            }) {
              Text(item.title)
                .font(.system(size: 17))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
  }
}

// Overlay container that handles the slide-in animation and tap/swipe-to-dismiss.
struct AIChatHistorySidebar: View {
  @Binding var isVisible: Bool
  let chatItems: [AIChatItem]
  var onNewChat: () -> Void
  var onSelectChat: (AIChatItem) -> Void

  // Width of the sidebar as a fraction of the overlay width.
  private let sidebarWidthRatio: CGFloat = 0.75
  // Animation duration for slide in/out.
  private let animationDuration: Double = 0.15
  // Corner radius for the sidebar.
  private let cornerRadius: CGFloat = 16
  // Threshold for swipe-to-close (fraction of sidebar width).
  private let swipeThreshold: CGFloat = 0.3

  // Tracks the current drag offset during swipe gesture.
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    GeometryReader { geometry in
      let sidebarWidth = geometry.size.width * sidebarWidthRatio
      // Clamp drag offset so sidebar doesn't go past its open position.
      let clampedOffset = min(0, dragOffset)

      ZStack(alignment: .leading) {
        // Blurred background (tap to dismiss). Fades based on sidebar position.
        Color.clear
          .background(.ultraThinMaterial)
          .opacity(isVisible ? Double(1 + clampedOffset / sidebarWidth) : 0)
          .animation(dragOffset == 0 ? .easeOut(duration: animationDuration) : .none, value: isVisible)
          .onTapGesture {
            withAnimation(.easeOut(duration: animationDuration)) {
              isVisible = false
            }
          }
          .simultaneousGesture(
            DragGesture()
              .onChanged { value in
                // Only track horizontal drags going left.
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                // Require primarily horizontal movement.
                if horizontal < 0 && abs(horizontal) > vertical {
                  dragOffset = horizontal
                }
              }
              .onEnded { value in
                // Close if dragged past threshold or with enough velocity.
                let shouldClose = value.translation.width < -sidebarWidth * swipeThreshold ||
                  value.predictedEndTranslation.width < -sidebarWidth * 0.5
                if shouldClose {
                  withAnimation(.easeOut(duration: animationDuration)) {
                    isVisible = false
                  }
                }
                // Reset drag offset.
                withAnimation(.easeOut(duration: animationDuration)) {
                  dragOffset = 0
                }
              }
          )

        // Sidebar content with rounded corners.
        AIChatHistoryView(
          isVisible: $isVisible,
          chatItems: chatItems,
          onNewChat: {
            withAnimation(.easeOut(duration: animationDuration)) {
              isVisible = false
            }
            onNewChat()
          },
          onSelectChat: { item in
            withAnimation(.easeOut(duration: animationDuration)) {
              isVisible = false
            }
            onSelectChat(item)
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: sidebarWidth)
        .offset(x: isVisible ? clampedOffset : -sidebarWidth)
        .animation(dragOffset == 0 ? .easeOut(duration: animationDuration) : .none, value: isVisible)
        .allowsHitTesting(isVisible)
        // Allow swipe-to-close gesture from within the sidebar.
        .simultaneousGesture(
          DragGesture()
            .onChanged { value in
              // Only track horizontal drags going left.
              let horizontal = value.translation.width
              let vertical = abs(value.translation.height)
              // Require primarily horizontal movement to avoid conflicts with scrolling.
              if horizontal < 0 && abs(horizontal) > vertical * 1.5 {
                dragOffset = horizontal
              }
            }
            .onEnded { value in
              // Close if dragged past threshold or with enough velocity.
              let shouldClose = value.translation.width < -sidebarWidth * swipeThreshold ||
                value.predictedEndTranslation.width < -sidebarWidth * 0.5
              if shouldClose {
                withAnimation(.easeOut(duration: animationDuration)) {
                  isVisible = false
                }
              }
              // Reset drag offset.
              withAnimation(.easeOut(duration: animationDuration)) {
                dragOffset = 0
              }
            }
        )
      }
    }
  }
}

#if DEBUG
struct AIChatHistoryView_Previews: PreviewProvider {
  static var previews: some View {
    AIChatHistorySidebar(
      isVisible: .constant(true),
      chatItems: [
        AIChatItem(title: "UI vs Backend Prioritization"),
        AIChatItem(title: "MVP Features for Notetaking"),
        AIChatItem(title: "iOS App Auth Strategy"),
        AIChatItem(title: "UI Change Workflow Optimization"),
        AIChatItem(title: "Prompt Improvement Request"),
        AIChatItem(title: "Speech to Text MacOS"),
        AIChatItem(title: "App Review and Security"),
        AIChatItem(title: "Chat Bar Expansion Design"),
        AIChatItem(title: "New Chat"),
        AIChatItem(title: "Getting Started with tmux")
      ],
      onNewChat: {},
      onSelectChat: { _ in }
    )
    .frame(width: 400, height: 560)
    .background(Color.gray.opacity(0.3))
  }
}
#endif
