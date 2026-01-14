import Combine
import SwiftUI

// Observable view model for chat input state.
// Allows UIKit to manage text state while SwiftUI renders the view.
final class AIChatInputViewModel: ObservableObject {
  @Published var text: String = ""
}

// Chat input bar for the AI overlay.
// Rounded rectangle with multiline text field and send button.
// Supports external focus control via FocusState binding.
// Text input grows automatically up to 8 lines, then becomes scrollable.
struct AIChatInputBar: View {
  // Text entered by the user.
  @Binding var text: String
  // External focus control binding. When true, the text field gains focus.
  var isFocused: FocusState<Bool>.Binding?
  // Called when the send button is tapped.
  var onSend: () -> Void

  // Internal focus state used when no external binding is provided.
  @FocusState private var internalFocus: Bool

  // Corner radius for the rounded rectangle background.
  private let cornerRadius: CGFloat = 24

  // Whether the send button is enabled (has non-whitespace text).
  private var isSendEnabled: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 0) {
      // Multiline text field that expands automatically.
      TextField("Ask anything", text: $text, axis: .vertical)
        .font(.system(size: 17))
        .foregroundColor(.primary)
        .lineLimit(1...8)
        .textFieldStyle(.plain)
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 14)
        .focused(isFocused ?? $internalFocus)

      // Send button - circular, enabled state depends on text content.
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
    .background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color(white: 0.93))
    )
    .animation(.easeInOut(duration: 0.15), value: text)
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
