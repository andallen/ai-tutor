import Combine
import SwiftUI

// Observable view model for chat input state.
// Allows UIKit to manage text state while SwiftUI renders the view.
final class AIChatInputViewModel: ObservableObject {
  @Published var text: String = ""
}

// Chat input bar for the AI overlay.
// Pill-shaped with text field and send button.
struct AIChatInputBar: View {
  // Text entered by the user.
  @Binding var text: String
  // Called when the send button is tapped.
  var onSend: () -> Void

  // Whether the send button is enabled (has non-whitespace text).
  private var isSendEnabled: Bool {
    !text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    HStack(spacing: 0) {
      // Text field with placeholder.
      TextField("Ask anything", text: $text)
        .font(.system(size: 17))
        .foregroundColor(.primary)
        .padding(.leading, 20)
        .padding(.vertical, 14)

      Spacer()

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
      .padding(.vertical, 6)
    }
    .background(
      Capsule()
        .fill(Color(white: 0.93))
    )
  }
}

#if DEBUG
struct AIChatInputBar_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 20) {
      // Empty state.
      AIChatInputBar(text: .constant(""), onSend: {})
        .padding()

      // With text.
      AIChatInputBar(text: .constant("Hello"), onSend: {})
        .padding()
    }
    .background(Color.white)
  }
}
#endif
