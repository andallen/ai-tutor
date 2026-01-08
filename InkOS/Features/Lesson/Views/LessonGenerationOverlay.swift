//
// LessonGenerationOverlay.swift
// InkOS
//
// Custom overlay for creating a new lesson with liquid glass effect.
// Features progressive blur animation and matches AI overlay design.
//

import SwiftUI

// Custom overlay for lesson generation with glass effect and blur background.
struct LessonGenerationOverlay: View {
  let onGenerate: (String, URL?) async throws -> Void
  let onDismiss: () -> Void

  // The lesson description entered by the user.
  @State private var lessonText: String = ""
  // Tracks whether generation is in progress.
  @State private var isGenerating: Bool = false
  // Error message if generation fails.
  @State private var errorMessage: String?
  // Controls the animation state for the overlay.
  @State private var isPresented = false
  // Focus state for the text field.
  @FocusState private var isTextFieldFocused: Bool
  // Selected file for lesson generation.
  @State private var selectedFileURL: URL?

  // Overlay styling - narrower than AI overlay.
  private let overlayCornerRadius: CGFloat = 24
  private let overlayWidth: CGFloat = 400
  private let overlayHeight: CGFloat = 520

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Progressive blur background.
        blurBackground

        // Lesson generation overlay card.
        overlayCard
          .frame(width: overlayWidth, height: overlayHeight)
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
          )
      }
    }
    .ignoresSafeArea()
    .onAppear {
      // Animate overlay in.
      withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
        isPresented = true
      }
      // Focus text field after a short delay.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        isTextFieldFocused = true
      }
    }
  }

  // MARK: - Blur Background

  // Progressive blur background that dims and blurs the dashboard behind.
  private var blurBackground: some View {
    ZStack {
      // Blur effect.
      Rectangle()
        .fill(.ultraThinMaterial)
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isPresented)

      // Tap to dismiss.
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          dismiss()
        }
    }
  }

  // MARK: - Overlay Card

  // Liquid glass overlay card with lesson generation content.
  private var overlayCard: some View {
    VStack(spacing: 0) {
      // Lesson generation content with model selector and input bar.
      LessonGenerationContent(
        text: $lessonText,
        isFocused: $isTextFieldFocused,
        isGenerating: isGenerating,
        onGenerate: { fileURL in
          selectedFileURL = fileURL
          generateLesson()
        }
      )

      // Error message if generation fails.
      if let error = errorMessage {
        errorDisplay(error)
      }
    }
    .glassOverlayBackground(cornerRadius: overlayCornerRadius)
    .clipShape(RoundedRectangle(cornerRadius: overlayCornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    .offset(y: isPresented ? 0 : 100)
    .opacity(isPresented ? 1 : 0)
    .animation(.spring(response: 0.42, dampingFraction: 0.85), value: isPresented)
  }

  // MARK: - Error Display

  // Displays error message in a red-tinted container.
  private func errorDisplay(_ message: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.incorrectRed)

      Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.ink)
        .multilineTextAlignment(.leading)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.incorrectRed.opacity(0.08))
    )
    .padding(.horizontal, 24)
    .padding(.bottom, 20)
  }

  // MARK: - Actions

  // Triggers lesson generation with the current topic and optional file.
  private func generateLesson() {
    let trimmedText = lessonText.trimmingCharacters(in: .whitespaces)
    guard !trimmedText.isEmpty || selectedFileURL != nil else { return }

    isGenerating = true
    errorMessage = nil
    isTextFieldFocused = false

    Task {
      do {
        print("📝 LessonGenerationOverlay: Starting generation...")
        if let fileURL = selectedFileURL {
          print("   📎 With file: \(fileURL.lastPathComponent)")
        }
        try await onGenerate(trimmedText, selectedFileURL)
        // Success: dismiss overlay.
        print("✅ LessonGenerationOverlay: Generation succeeded, dismissing...")
        dismiss()
      } catch {
        // Error: show message to user.
        print("❌ LessonGenerationOverlay: Error - \(error)")
        errorMessage = error.localizedDescription
        isGenerating = false
      }
    }
  }

  // Dismisses the overlay with animation.
  private func dismiss() {
    isTextFieldFocused = false

    withAnimation(.easeOut(duration: 0.25)) {
      isPresented = false
    }

    // Dismiss after animation completes.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      onDismiss()
    }
  }
}

// MARK: - Preview

#Preview {
  ZStack {
    // Mock dashboard background.
    Color.white.ignoresSafeArea()

    VStack(spacing: 16) {
      Text("Dashboard Content")
        .font(.largeTitle)
      Rectangle()
        .fill(Color.gray.opacity(0.2))
        .frame(width: 200, height: 300)
    }

    // Overlay on top.
    LessonGenerationOverlay(
      onGenerate: { topic, fileURL in
        // Simulate generation delay.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        if let fileURL = fileURL {
          print("Generated lesson: \(topic) with file: \(fileURL.lastPathComponent)")
        } else {
          print("Generated lesson: \(topic)")
        }
      },
      onDismiss: {
        print("Dismissed")
      }
    )
  }
}
