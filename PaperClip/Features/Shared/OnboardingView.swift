//
// OnboardingView.swift
// PaperClip
//
// Three-page onboarding flow shown on first launch.
// Page 1: Animated paper airplane (app icon) drawing itself, with tagline.
// Page 2: Three-step workflow overview (Write → Send → Arrive).
// Page 3: Companion app setup instructions + Get Started button.
//

import SwiftUI

// MARK: - Icon Reveal Mask

// Diagonal wipe mask that sweeps from bottom-left to top-right.
// Animating `progress` from 0 → 1.2 progressively reveals the content,
// simulating the icon being drawn in the natural trail → airplane direction.
private struct DiagonalRevealMask: View {
  // 0 = fully hidden, ~1.2 = fully revealed.
  let progress: CGFloat

  var body: some View {
    LinearGradient(
      stops: [
        .init(color: .white, location: max(0, progress - 0.2)),
        .init(color: .clear, location: progress)
      ],
      startPoint: .bottomLeading,
      endPoint: .topTrailing
    )
  }
}

// MARK: - Grain Texture

// Canvas-rendered film grain for a tactile paper feel.
// Deterministic pseudo-random hash keeps the pattern stable across redraws.
private struct GrainTexture: View {
  var body: some View {
    Canvas { context, size in
      for x in stride(from: 0, to: size.width, by: 4) {
        for y in stride(from: 0, to: size.height, by: 4) {
          let hash = (Int(x) &* 374761393 &+ Int(y) &* 668265263) &+ 1274126177
          let value = Double(abs(hash) % 1000) / 1000.0
          if value > 0.55 {
            let alpha = (value - 0.55) * 0.12
            context.fill(
              Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)),
              with: .color(.black.opacity(alpha))
            )
          }
        }
      }
    }
    .allowsHitTesting(false)
  }
}

// MARK: - Onboarding Style

// Design constants specific to the onboarding experience.
private enum OnboardingStyle {
  // Accent matches the app's ink color — charcoal black.
  static let accent = NotebookPalette.ink

  // Subtle tint for icon background circles on the setup page.
  static let accentTint = NotebookPalette.ink.opacity(0.08)

  // Maximum content width for readability on large screens.
  static let maxWidth: CGFloat = 500

  // Hero display — larger than the standard display size for dramatic impact.
  static let hero = Font.system(size: 46, weight: .bold, design: .rounded)

  // Subtitle for taglines and supporting copy.
  static let subtitle = Font.system(size: 19, weight: .medium, design: .rounded)

}

// MARK: - OnboardingView

// Full-screen onboarding presented before the main app.
// Three swipeable pages: welcome, workflow explanation, and companion app setup.
struct OnboardingView: View {
  // Called when the user finishes onboarding via the Get Started button.
  let onComplete: () -> Void

  // Active page (0 = Welcome, 1 = How It Works, 2 = Setup).
  @State private var currentPage = 0

  // Page 1: icon reveal progress (0 = hidden, ~1.2 = fully shown).
  @State private var iconReveal: CGFloat = 0
  @State private var iconLift = false

  // Page 1: text reveal flags.
  @State private var showWordmark = false
  @State private var showTagline = false
  @State private var showSwipeHint = false
  @State private var chevronBounce = false

  // Page 2: per-step visibility flags.
  @State private var page2Appeared = false
  @State private var stepVisible = [false, false, false]

  // Page 3: per-item visibility and CTA state.
  @State private var page3Appeared = false
  @State private var checkVisible = [false, false, false]
  @State private var ctaVisible = false
  @State private var ctaPulse = false

  var body: some View {
    ZStack {
      // Warm paper background.
      NotebookPalette.paper
        .ignoresSafeArea()

      // Subtle grain overlay for tactile depth.
      GrainTexture()
        .opacity(0.035)
        .ignoresSafeArea()

      // Swipeable pages with hidden system indicator.
      TabView(selection: $currentPage) {
        welcomePage.tag(0)

        howItWorksPage
          .onAppear { triggerPage2Animations() }
          .tag(1)

        setupPage
          .onAppear { triggerPage3Animations() }
          .tag(2)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      // Custom expanding-capsule page indicator pinned to bottom.
      VStack {
        Spacer()
        pageIndicator
          .padding(.bottom, 48)
      }
    }
    .task { await animateWelcome() }
  }

  // MARK: - Page 1: Welcome

  // Brand hero with animated paper airplane drawing itself.
  private var welcomePage: some View {
    VStack(spacing: 0) {
      Spacer()

      // App icon with diagonal reveal animation — sweeps bottom-left to top-right.
      Image("PaperPlaneIcon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 180, height: 180)
        .mask(DiagonalRevealMask(progress: iconReveal))
        .offset(y: iconLift ? -6 : 0)

      Spacer().frame(height: 32)

      // App name in hero typography.
      Text("PaperClip")
        .font(OnboardingStyle.hero)
        .foregroundColor(NotebookPalette.ink)
        .opacity(showWordmark ? 1 : 0)
        .offset(y: showWordmark ? 0 : 14)

      Spacer().frame(height: 10)

      // Tagline.
      Text("Empower AI to read your handwriting.")
        .font(OnboardingStyle.subtitle)
        .foregroundColor(NotebookPalette.inkSubtle)
        .opacity(showTagline ? 1 : 0)
        .offset(y: showTagline ? 0 : 8)

      Spacer()

      // Swipe hint with animated chevron.
      HStack(spacing: 6) {
        Text("Swipe to begin")
          .font(NotebookTypography.caption)
          .foregroundColor(NotebookPalette.inkFaint)

        Image(systemName: "chevron.compact.right")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(NotebookPalette.inkFaint)
          .offset(x: chevronBounce ? 4 : 0)
      }
      .opacity(showSwipeHint ? 1 : 0)

      Spacer().frame(height: 76)
    }
    .padding(.horizontal, 40)
  }

  // MARK: - Page 2: How It Works

  // Three numbered workflow steps — editorial layout, no icons.
  private var howItWorksPage: some View {
    VStack(spacing: 0) {
      Spacer()

      // Section heading.
      Text("How It Works")
        .font(NotebookTypography.display)
        .foregroundColor(NotebookPalette.ink)

      Spacer().frame(height: 52)

      // Workflow steps with staggered entrance.
      VStack(spacing: 36) {
        workflowStep(
          number: "1",
          title: "Write",
          description: "Draw on the canvas with Apple Pencil. Only Pencil input draws; your finger scrolls.",
          visible: stepVisible[0]
        )

        workflowStep(
          number: "2",
          title: "Send",
          description: "Crop a region, capture the screen, or grab the full canvas — then tap Send.",
          visible: stepVisible[1]
        )

        workflowStep(
          number: "3",
          title: "Arrive",
          description: "It lands on your Mac's clipboard. Simply ⌘V to paste.",
          visible: stepVisible[2]
        )
      }
      .frame(maxWidth: OnboardingStyle.maxWidth, alignment: .leading)

      Spacer().frame(height: 28)

      // Compatibility note.
      Text("Works for ChatGPT, any terminal, or any app that accepts images.")
        .font(NotebookTypography.caption)
        .foregroundColor(NotebookPalette.inkFaint)
        .multilineTextAlignment(.center)
        .frame(maxWidth: OnboardingStyle.maxWidth)

      Spacer()
      Spacer().frame(height: 76)
    }
    .padding(.horizontal, 40)
  }

  // Numbered workflow step: ink badge with number, title, and description.
  private func workflowStep(
    number: String,
    title: String,
    description: String,
    visible: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: 18) {
      // Number badge — ink circle with paper-colored text.
      ZStack {
        Circle()
          .fill(NotebookPalette.ink)
          .frame(width: 44, height: 44)
          .shadow(color: NotebookPalette.ink.opacity(0.15), radius: 8, y: 3)

        Text(number)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundColor(NotebookPalette.paper)
      }

      // Step title and description — fills width so all rows align evenly.
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(NotebookTypography.headline)
          .foregroundColor(NotebookPalette.ink)

        Text(description)
          .font(NotebookTypography.body)
          .foregroundColor(NotebookPalette.inkSubtle)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .opacity(visible ? 1 : 0)
    .offset(x: visible ? 0 : -16)
  }

  // MARK: - Page 3: Setup

  // Companion app install instructions and Get Started CTA.
  private var setupPage: some View {
    VStack(spacing: 0) {
      Spacer()

      // Section heading.
      Text("Set Up Your Mac")
        .font(NotebookTypography.display)
        .foregroundColor(NotebookPalette.ink)

      Spacer().frame(height: 10)

      // Setup explanation.
      Text("Install the free companion app so your\ndrawings arrive on your Mac instantly.")
        .font(NotebookTypography.body)
        .foregroundColor(NotebookPalette.inkSubtle)
        .multilineTextAlignment(.center)

      Spacer().frame(height: 44)

      // Setup step cards with liquid glass backgrounds.
      VStack(spacing: 14) {
        setupCard(
          icon: "arrow.down.circle",
          title: "Get PaperClip for Mac",
          detail: Text("Free companion app — lives in your menu bar"),
          visible: checkVisible[0],
          action: AppStoreLinks.openMacReceiver
        )

        setupCard(
          icon: "desktopcomputer",
          title: "Launch It",
          detail: Text("Look for the \(Image(systemName: "paperclip")) icon in your menu bar"),
          visible: checkVisible[1]
        )

        setupCard(
          icon: "checkmark.circle",
          title: "You're Connected",
          detail: Text("A green dot on your canvas means your Mac is nearby"),
          visible: checkVisible[2]
        )
      }
      .frame(maxWidth: OnboardingStyle.maxWidth)

      Spacer().frame(height: 44)

      // Get Started button — solid ink capsule with subtle shadow.
      Button(action: onComplete) {
        Text("Get Started")
          .font(.system(size: 18, weight: .semibold, design: .rounded))
          .foregroundColor(NotebookPalette.paper)
          .frame(maxWidth: 280)
          .padding(.vertical, 16)
          .background(
            Capsule()
              .fill(NotebookPalette.ink)
              .shadow(
                color: NotebookPalette.ink.opacity(ctaPulse ? 0.35 : 0.15),
                radius: ctaPulse ? 16 : 10,
                y: 4
              )
          )
      }
      .scaleEffect(ctaVisible ? 1 : 0.92)
      .opacity(ctaVisible ? 1 : 0)

      Spacer()
      Spacer().frame(height: 76)
    }
    .padding(.horizontal, 40)
  }

  // Setup step card with icon, title, detail, and optional tap action.
  // When action is non-nil, a subtle arrow glyph appears and the card is tappable.
  private func setupCard(
    icon: String,
    title: String,
    detail: Text,
    visible: Bool,
    action: (() -> Void)? = nil
  ) -> some View {
    HStack(spacing: 14) {
      // Icon in a subtle ink-tinted circle.
      Image(systemName: icon)
        .font(.system(size: 19, weight: .medium))
        .foregroundColor(NotebookPalette.ink)
        .frame(width: 42, height: 42)
        .background(Circle().fill(OnboardingStyle.accentTint))

      // Step text.
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(NotebookTypography.headline)
          .foregroundColor(NotebookPalette.ink)

        detail
          .font(NotebookTypography.body)
          .foregroundColor(NotebookPalette.inkSubtle)
      }

      Spacer()

      // Trailing arrow — only visible when the card is tappable.
      if action != nil {
        Image(systemName: "arrow.up.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(NotebookPalette.inkFaint)
      }
    }
    .padding(16)
    .liquidGlassBackground(cornerRadius: 14)
    .opacity(visible ? 1 : 0)
    .offset(y: visible ? 0 : 10)
    .onTapGesture { action?() }
    .allowsHitTesting(visible)
  }

  // MARK: - Page Indicator

  // Active page shown as a wider capsule, inactive as small circles.
  private var pageIndicator: some View {
    HStack(spacing: 10) {
      ForEach(0..<3, id: \.self) { index in
        Capsule()
          .fill(
            currentPage == index
              ? NotebookPalette.ink
              : NotebookPalette.inkFaint.opacity(0.3)
          )
          .frame(
            width: currentPage == index ? 24 : 8,
            height: 8
          )
          .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
      }
    }
  }

  // MARK: - Animation Triggers

  // Fires page 2 animations on first appearance.
  private func triggerPage2Animations() {
    guard !page2Appeared else { return }
    page2Appeared = true
    Task { await animateHowItWorks() }
  }

  // Fires page 3 animations on first appearance.
  private func triggerPage3Animations() {
    guard !page3Appeared else { return }
    page3Appeared = true
    Task { await animateSetup() }
  }

  // MARK: - Animation Sequences

  // Page 1: icon reveals diagonally → lifts → text reveals.
  private func animateWelcome() async {
    // Brief pause before the sequence begins.
    try? await Task.sleep(for: .milliseconds(300))

    // Diagonal wipe reveals the icon from bottom-left (trail) to top-right (plane).
    withAnimation(.easeInOut(duration: 1.4)) { iconReveal = 1.25 }
    try? await Task.sleep(for: .milliseconds(1200))

    // Subtle upward lift — the plane "takes flight."
    withAnimation(.easeOut(duration: 0.5)) { iconLift = true }
    try? await Task.sleep(for: .milliseconds(200))

    // Wordmark slides up.
    withAnimation(.easeOut(duration: 0.45)) { showWordmark = true }
    try? await Task.sleep(for: .milliseconds(200))

    // Tagline fades in.
    withAnimation(.easeOut(duration: 0.4)) { showTagline = true }
    try? await Task.sleep(for: .milliseconds(600))

    // Swipe hint appears.
    withAnimation(.easeOut(duration: 0.5)) { showSwipeHint = true }

    // Repeating chevron nudge to indicate swipe direction.
    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
      chevronBounce = true
    }
  }

  // Page 2: steps slide in from the left one by one.
  private func animateHowItWorks() async {
    try? await Task.sleep(for: .milliseconds(250))

    for i in 0..<3 {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
        stepVisible[i] = true
      }
      try? await Task.sleep(for: .milliseconds(180))
    }
  }

  // Page 3: cards drop in, then CTA appears with pulsing shadow.
  private func animateSetup() async {
    try? await Task.sleep(for: .milliseconds(250))

    for i in 0..<3 {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
        checkVisible[i] = true
      }
      try? await Task.sleep(for: .milliseconds(160))
    }

    try? await Task.sleep(for: .milliseconds(220))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { ctaVisible = true }

    // Gentle breathing glow on the CTA shadow.
    try? await Task.sleep(for: .milliseconds(500))
    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
      ctaPulse = true
    }
  }
}
