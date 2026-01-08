import Combine
import SwiftUI

// Observable view model for chat input state.
// Allows UIKit to manage text state while SwiftUI renders the view.
final class AIChatInputViewModel: ObservableObject {
  @Published var text: String = ""
}

// Chat input bar for the AI overlay.
// Rounded rectangle with multiline text editor and send button.
// Supports external focus control via FocusState binding.
// Text input grows up to 8 lines, then becomes scrollable.
struct AIChatInputBar: View {
  // Text entered by the user.
  @Binding var text: String
  // External focus control binding. When true, the text field gains focus.
  var isFocused: FocusState<Bool>.Binding?
  // Called when the send button is tapped.
  var onSend: () -> Void

  // Internal focus state used when no external binding is provided.
  @FocusState private var internalFocus: Bool

  // Line height for the text editor (17pt font + line spacing).
  private let lineHeight: CGFloat = 22
  // Maximum number of visible lines before scrolling.
  private let maxLines: Int = 8
  // Minimum height for single line (includes padding).
  private let minHeight: CGFloat = 48
  // Vertical padding inside the text editor area.
  private let verticalPadding: CGFloat = 14
  // Corner radius for the rounded rectangle background.
  private let cornerRadius: CGFloat = 24

  // Whether the send button is enabled (has non-whitespace text).
  private var isSendEnabled: Bool {
    !text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  // Calculates the number of lines in the current text.
  private var lineCount: Int {
    let lines = text.components(separatedBy: .newlines)
    // Count wrapped lines by estimating characters per line.
    // Approximate width available for text (minus padding and button).
    let estimatedCharsPerLine = 35
    var totalLines = 0
    for line in lines {
      if line.isEmpty {
        totalLines += 1
      } else {
        // Each line wraps based on character count.
        totalLines += max(1, Int(ceil(Double(line.count) / Double(estimatedCharsPerLine))))
      }
    }
    return max(1, totalLines)
  }

  // Dynamic height based on content, capped at maxLines.
  private var dynamicHeight: CGFloat {
    let contentLines = min(lineCount, maxLines)
    let contentHeight = CGFloat(contentLines) * lineHeight + verticalPadding * 2
    return max(minHeight, contentHeight)
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 0) {
      // Multiline text editor with placeholder.
      ZStack(alignment: .topLeading) {
        // Placeholder text shown when empty.
        if text.isEmpty {
          Text("Ask anything")
            .font(.system(size: 17))
            .foregroundColor(Color(white: 0.5))
            .padding(.leading, 20)
            .padding(.top, verticalPadding)
            .allowsHitTesting(false)
        }

        // Multiline text editor.
        // Keyboard dismissal via scroll is disabled so fast scrolling doesn't hide it.
        TextEditor(text: $text)
          .font(.system(size: 17))
          .foregroundColor(.primary)
          .scrollContentBackground(.hidden)
          .background(Color.clear)
          .scrollDismissesKeyboard(.never)
          .padding(.leading, 16)
          .padding(.trailing, 8)
          .padding(.vertical, verticalPadding - 8)
          .focused(isFocused ?? $internalFocus)
          .frame(height: dynamicHeight)
      }

      // Send button - circular, enabled state depends on text content.
      // Anchored to bottom of the bar.
      Button(action: {
        if isSendEnabled {
          onSend()
        }
      }) {
        Circle()
          .fill(isSendEnabled ? Color.black : Color(white: 0.78))
          .frame(width: 36, height: 36)
          .overlay(
            Image(systemName: "arrow.up")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(isSendEnabled ? .white : Color(white: 0.92))
          )
      }
      .disabled(!isSendEnabled)
      .animation(.easeInOut(duration: 0.15), value: isSendEnabled)
      .padding(.trailing, 6)
      .padding(.bottom, 6)
    }
    .frame(height: dynamicHeight)
    .background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color(white: 0.93))
    )
    .animation(.easeInOut(duration: 0.15), value: dynamicHeight)
  }

  // Initializer with optional focus binding for backward compatibility.
  init(
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding? = nil,
    onSend: @escaping () -> Void
  ) {
    self._text = text
    self.isFocused = isFocused
    self.onSend = onSend
  }
}

#if DEBUG
struct AIChatInputBar_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 20) {
      // Empty state.
      AIChatInputBar(text: .constant(""), onSend: {})
        .padding()

      // With short text.
      AIChatInputBar(text: .constant("Hello"), onSend: {})
        .padding()

      // With multiline text.
      AIChatInputBar(
        text: .constant("This is a longer message\nthat spans multiple lines\nto test the growing behavior"),
        onSend: {}
      )
      .padding()
    }
    .background(Color.white)
  }
}
#endif
