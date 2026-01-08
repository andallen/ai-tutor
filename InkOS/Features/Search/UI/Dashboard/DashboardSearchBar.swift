import SwiftUI
import UIKit

// Native UIKit search field that avoids SwiftUI focus hit testing issues.
struct DashboardSearchBar: UIViewRepresentable {
  @Binding var text: String
  @Binding var isFocused: Bool

  func makeUIView(context: Context) -> UIView {
    let container = SearchBarContainerView()
    container.backgroundColor = .clear

    // Search icon.
    let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    iconView.tintColor = UIColor(Color.inkSubtle)
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false

    // Native UITextField for consistent focus and typing.
    let textField = UITextField()
    textField.placeholder = "Search notes..."
    textField.font = .systemFont(ofSize: 17)
    textField.textColor = UIColor(Color.ink)
    textField.tintColor = UIColor(Color.ink)
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.returnKeyType = .search
    textField.clearButtonMode = .never
    textField.delegate = context.coordinator
    textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
    textField.translatesAutoresizingMaskIntoConstraints = false

    // Background capsule.
    let background = UIView()
    background.backgroundColor = UIColor(white: 0.93, alpha: 1.0)
    background.layer.cornerRadius = 24
    background.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(background)
    container.addSubview(iconView)
    container.addSubview(textField)

    NSLayoutConstraint.activate([
      // Container height.
      container.heightAnchor.constraint(equalToConstant: 48),

      // Background fills container.
      background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      background.topAnchor.constraint(equalTo: container.topAnchor),
      background.bottomAnchor.constraint(equalTo: container.bottomAnchor),

      // Icon on left.
      iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 16),
      iconView.heightAnchor.constraint(equalToConstant: 16),

      // TextField fills remaining space.
      textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
      textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    container.textField = textField
    context.coordinator.textField = textField
    return container
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard let textField = context.coordinator.textField else { return }

    // Update text if needed.
    if textField.text != text {
      textField.text = text
    }

    // Update focus state.
    if isFocused && !textField.isFirstResponder {
      textField.becomeFirstResponder()
    } else if !isFocused && textField.isFirstResponder {
      textField.resignFirstResponder()
    }

  }

  // Tell SwiftUI the exact size this view needs.
  // This ensures SwiftUI and UIKit agree on dimensions for proper hit testing.
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
    let width = proposal.width ?? 300
    return CGSize(width: width, height: 48)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, isFocused: $isFocused)
  }

  class Coordinator: NSObject, UITextFieldDelegate {
    @Binding var text: String
    @Binding var isFocused: Bool
    weak var textField: UITextField?

    init(text: Binding<String>, isFocused: Binding<Bool>) {
      _text = text
      _isFocused = isFocused
    }

    @objc func textChanged(_ sender: UITextField) {
      text = sender.text ?? ""
      print("[DashboardSearchBar] Text changed to: '\(text)'")
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
      isFocused = true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
      isFocused = false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      textField.resignFirstResponder()
      return true
    }
  }
}

// Logs container hit testing to identify touch interception.
final class SearchBarContainerView: UIView {
  weak var textField: UITextField?
  private var lastBounds: CGRect = .zero
  private var lastFrame: CGRect = .zero

  override func layoutSubviews() {
    super.layoutSubviews()

    if bounds != lastBounds || frame != lastFrame {
      print(
        "[SearchBarContainerView] frame=\(frame) bounds=\(bounds) textField=\(textField?.frame ?? .zero)"
      )
      lastBounds = bounds
      lastFrame = frame
    }
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let isInside = super.point(inside: point, with: event)
    if isInside {
      print("[SearchBarContainerView] pointInside point=\(point) bounds=\(bounds)")
    }
    return isInside
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hitView = super.hitTest(point, with: event)
    if bounds.contains(point) {
      print("[SearchBarContainerView] hitTest point=\(point) hitView=\(String(describing: hitView))")
    }
    return hitView
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first {
      print("[SearchBarContainerView] touchesBegan location=\(touch.location(in: self)) type=\(touch.type)")
    }
    super.touchesBegan(touches, with: event)
  }
}

#if DEBUG
struct DashboardSearchBar_Previews: PreviewProvider {
  struct PreviewWrapper: View {
    @State private var text = ""
    @State private var isFocused: Bool = false

    var body: some View {
      VStack(spacing: 20) {
        // Empty state.
        DashboardSearchBar(text: $text, isFocused: $isFocused)
          .padding()

        // With text.
        DashboardSearchBar(text: .constant("Budget"), isFocused: $isFocused)
          .padding()
      }
      .background(Color.white)
    }
  }

  static var previews: some View {
    PreviewWrapper()
  }
}
#endif
