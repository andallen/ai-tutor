import SwiftUI
import UIKit

// Shared UI components used across multiple features.

// Background view with white color and subtle gradients.
struct BackgroundWhite: View {
  var body: some View {
    ZStack {
      Color.white

      RadialGradient(
        colors: [Color.black.opacity(0.06), Color.clear],
        center: .topTrailing,
        startRadius: 40,
        endRadius: 520
      )
      .blendMode(.multiply)

      RadialGradient(
        colors: [Color.black.opacity(0.04), Color.clear],
        center: .bottomLeading,
        startRadius: 60,
        endRadius: 620
      )
      .blendMode(.multiply)
    }
  }
}

// View modifier that applies a glass background effect.
extension View {
  func glassBackground(cornerRadius: CGFloat) -> some View {
    Group {
      if #available(iOS 26.0, *) {
        self
          .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
      } else {
        // Falls back to a blurred material background on older iOS.
        self
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          )
      }
    }
  }
}

// Shared color definitions.
extension Color {
  static let rule = Color.black.opacity(0.10)
  static let separator = Color.black.opacity(0.14)

  // Matches the navigation bar icon tint.
  static let offBlack = Color(red: 0.20, green: 0.20, blue: 0.20)

  static let ink = Color.black.opacity(0.88)
  static let inkSubtle = Color.black.opacity(0.62)
  static let inkFaint = Color.black.opacity(0.40)
}

// MARK: - Animated Blur View

// UIViewRepresentable that wraps a UIVisualEffectView for smooth blur animation.
// Uses UIViewPropertyAnimator with CADisplayLink for smooth interpolation.
// Animates smoothly between clear (0) and fully blurred (1).
struct AnimatedBlurView: UIViewRepresentable {
  // Target blur intensity from 0 (clear) to 1 (full blur).
  let blurFraction: CGFloat
  // Duration for blur animation.
  let animationDuration: TimeInterval
  // Style of blur effect to use.
  let style: UIBlurEffect.Style

  init(
    blurFraction: CGFloat,
    animationDuration: TimeInterval = 0.35,
    style: UIBlurEffect.Style = .regular
  ) {
    self.blurFraction = blurFraction
    self.animationDuration = animationDuration
    self.style = style
  }

  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurView = UIVisualEffectView(effect: nil)
    // Create an animator that applies blur when its fractionComplete increases.
    let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
      blurView.effect = UIBlurEffect(style: self.style)
    }
    animator.pausesOnCompletion = true
    animator.fractionComplete = 0
    context.coordinator.animator = animator
    context.coordinator.currentFraction = 0
    // Start animation to target if not zero.
    if blurFraction > 0 {
      context.coordinator.animateTo(blurFraction, duration: animationDuration)
    }
    return blurView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    // Animate to new target fraction if different from current target.
    let target = blurFraction
    if abs(context.coordinator.targetFraction - target) > 0.001 {
      context.coordinator.animateTo(target, duration: animationDuration)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    var animator: UIViewPropertyAnimator?
    var displayLink: CADisplayLink?
    var currentFraction: CGFloat = 0
    var targetFraction: CGFloat = 0
    var animationStartTime: CFTimeInterval = 0
    var animationStartFraction: CGFloat = 0
    var animationDuration: TimeInterval = 0.35

    // Starts a smooth animation from current fraction to target.
    func animateTo(_ target: CGFloat, duration: TimeInterval) {
      targetFraction = target
      animationStartFraction = currentFraction
      animationDuration = duration
      animationStartTime = CACurrentMediaTime()

      // Cancel existing display link.
      displayLink?.invalidate()

      // Create new display link for animation.
      let link = CADisplayLink(target: self, selector: #selector(updateAnimation))
      link.add(to: .main, forMode: .common)
      displayLink = link
    }

    @objc func updateAnimation() {
      let elapsed = CACurrentMediaTime() - animationStartTime
      var progress = min(1.0, elapsed / animationDuration)

      // Apply ease-out cubic for smooth deceleration.
      progress = easeOutCubic(progress)

      // Interpolate between start and target.
      let newFraction = animationStartFraction + (targetFraction - animationStartFraction) * progress
      currentFraction = newFraction
      animator?.fractionComplete = newFraction

      // Stop animation when complete.
      if progress >= 1.0 {
        displayLink?.invalidate()
        displayLink = nil
      }
    }

    // Ease out cubic for a smooth deceleration.
    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
      let adjusted = t - 1
      return adjusted * adjusted * adjusted + 1
    }

    deinit {
      displayLink?.invalidate()
      animator?.stopAnimation(true)
    }
  }
}

// MARK: - Rounded Corner Shape

// Rounded rectangle with individually rounded corners.
struct RoundedCornerShape: Shape {
  struct Corner: OptionSet {
    let rawValue: Int

    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
  }

  var radius: CGFloat
  let corners: Corner

  var animatableData: CGFloat {
    get { radius }
    set { radius = newValue }
  }

  func path(in rect: CGRect) -> SwiftUI.Path {
    let clampedRadius = min(radius, min(rect.width, rect.height) * 0.5)
    let topLeft = corners.contains(.topLeft) ? clampedRadius : 0
    let topRight = corners.contains(.topRight) ? clampedRadius : 0
    let bottomLeft = corners.contains(.bottomLeft) ? clampedRadius : 0
    let bottomRight = corners.contains(.bottomRight) ? clampedRadius : 0

    var path = SwiftUI.Path()
    path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
    if topRight > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
        radius: topRight,
        startAngle: .degrees(-90),
        endAngle: .degrees(0),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
    if bottomRight > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
        radius: bottomRight,
        startAngle: .degrees(0),
        endAngle: .degrees(90),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
    if bottomLeft > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
        radius: bottomLeft,
        startAngle: .degrees(90),
        endAngle: .degrees(180),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
    if topLeft > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
        radius: topLeft,
        startAngle: .degrees(180),
        endAngle: .degrees(270),
        clockwise: false
      )
    }
    path.closeSubpath()
    return path
  }
}

// Logs hit testing without capturing touches.
struct HitTestLoggerView: UIViewRepresentable {
  let label: String

  func makeUIView(context: Context) -> UIView {
    HitTestLoggerUIView(label: label)
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    (uiView as? HitTestLoggerUIView)?.label = label
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
    let width = proposal.width ?? 0
    let height = proposal.height ?? 0
    return CGSize(width: width, height: height)
  }

  final class HitTestLoggerUIView: UIView {
    var label: String

    init(label: String) {
      self.label = label
      super.init(frame: .zero)
      isUserInteractionEnabled = true
      backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
      label = "HitTestLoggerView"
      super.init(coder: coder)
      isUserInteractionEnabled = true
      backgroundColor = .clear
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      if bounds.contains(point) {
        print("[HitTestLoggerView] \(label) pointInside point=\(point) bounds=\(bounds)")
      }
      return true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      if bounds.contains(point) {
        print("[HitTestLoggerView] \(label) hitTest point=\(point) bounds=\(bounds)")
      }
      return nil
    }
  }
}

// Logs touch locations and hit-tested views from the window.
struct WindowTapLoggerView: UIViewRepresentable {
  let label: String

  func makeUIView(context: Context) -> UIView {
    WindowTapLoggerHostView(label: label)
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    (uiView as? WindowTapLoggerHostView)?.label = label
  }
}

final class WindowTapLoggerHostView: UIView, UIGestureRecognizerDelegate {
  var label: String
  private weak var touchRecognizer: LoggingTouchRecognizer?
  private weak var attachedWindow: UIWindow?

  init(label: String) {
    self.label = label
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    label = "WindowTapLogger"
    super.init(coder: coder)
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    attachToWindowIfNeeded()
  }

  private func attachToWindowIfNeeded() {
    guard let window = window else { return }

    if attachedWindow === window {
      return
    }

    if let recognizer = touchRecognizer, let oldWindow = attachedWindow {
      oldWindow.removeGestureRecognizer(recognizer)
    }

    let recognizer = LoggingTouchRecognizer(target: self, action: #selector(handleTouch(_:)))
    recognizer.minimumPressDuration = 0
    recognizer.allowableMovement = 10_000
    recognizer.cancelsTouchesInView = false
    recognizer.delaysTouchesBegan = false
    recognizer.delaysTouchesEnded = false
    recognizer.allowedTouchTypes = [
      NSNumber(value: UITouch.TouchType.direct.rawValue),
      NSNumber(value: UITouch.TouchType.pencil.rawValue),
      NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
    ]
    recognizer.delegate = self
    window.addGestureRecognizer(recognizer)

    touchRecognizer = recognizer
    attachedWindow = window
    print("[WindowTapLoggerView] Attached to window for \(label)")
  }

  @objc private func handleTouch(_ recognizer: LoggingTouchRecognizer) {
    guard recognizer.state == .began else { return }
    guard let window = recognizer.view as? UIWindow else { return }
    let location = recognizer.location(in: window)
    let hitView = window.hitTest(location, with: nil)
    let touchType = recognizer.lastTouchTypeName
    print(
      "[WindowTapLoggerView] \(label) touch began location=\(location) type=\(touchType) hitView=\(String(describing: hitView))"
    )
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldReceive touch: UITouch
  ) -> Bool {
    return true
  }

  // Tracks touch type for window-level logging.
  final class LoggingTouchRecognizer: UILongPressGestureRecognizer {
    private(set) var lastTouchTypeName: String = "unknown"

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
      if let touch = touches.first {
        lastTouchTypeName = touchTypeName(for: touch.type)
      }
      super.touchesBegan(touches, with: event)
    }

    private func touchTypeName(for type: UITouch.TouchType) -> String {
      switch type {
      case .direct:
        return "direct"
      case .pencil:
        return "pencil"
      case .indirect:
        return "indirect"
      case .indirectPointer:
        return "indirectPointer"
      @unknown default:
        return "unknown"
      }
    }
  }

  deinit {
    if let recognizer = touchRecognizer, let oldWindow = attachedWindow {
      oldWindow.removeGestureRecognizer(recognizer)
    }
  }
}
