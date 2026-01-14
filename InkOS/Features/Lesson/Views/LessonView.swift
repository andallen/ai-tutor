//
// LessonView.swift
// InkOS
//
// Main container for viewing interactive lessons.
// Displays sections in a vertical scroll view with navigation controls.
//

import SwiftUI

// Main lesson viewing container.
struct LessonView: View {
  let lessonID: String
  let onDismiss: () -> Void

  @StateObject private var viewModel = LessonViewModel()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // Background matching the app's aesthetic.
      BackgroundWhite()
        .ignoresSafeArea()

      if viewModel.isLoading {
        loadingView
      } else if let errorMessage = viewModel.errorMessage {
        errorView(message: errorMessage)
      } else if let lesson = viewModel.lesson {
        lessonContent(lesson)
      }

      // Floating navigation bar at top.
      VStack {
        navigationBar
        Spacer()
      }
    }
    .navigationBarHidden(true)
    .task {
      await viewModel.loadLesson(lessonID: lessonID)
    }
  }

  // MARK: - Navigation Bar

  private var navigationBar: some View {
    HStack {
      // Home button - matches HomeButtonView styling from editors.
      Button(action: {
        onDismiss()
      }) {
        ZStack {
          Circle()
            .fill(.regularMaterial)
            .frame(width: 48, height: 48)

          Image(systemName: "house")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Color.offBlack)
        }
      }
      .buttonStyle(HomeButtonStyle())
      .accessibilityLabel("Go home")
      .accessibilityHint("Double tap to return to dashboard")

      Spacer()

      // Progress indicator showing current position.
      if let lesson = viewModel.lesson {
        LessonProgressView(
          currentSection: viewModel.currentSectionIndex + 1,
          totalSections: lesson.sections.count
        )
      }

      Spacer()

      // Empty spacer to balance the home button.
      Color.clear
        .frame(width: 48, height: 48)
    }
    .padding(.horizontal, 20)
    .padding(.top, 4)
  }

  // MARK: - Lesson Content

  @ViewBuilder
  private func lessonContent(_ lesson: Lesson) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Header with title, metadata, progress.
        LessonHeaderView(lesson: lesson, viewModel: viewModel)
          .padding(.top, 72)  // Space for floating nav bar.

        // Sections.
        ForEach(Array(lesson.sections.enumerated()), id: \.element.id) { index, section in
          LessonSectionView(
            section: section,
            sectionIndex: index,
            viewModel: viewModel
          )
          .padding(.top, index == 0 ? 24 : 32)
        }

        // Bottom padding.
        Spacer()
          .frame(height: 100)
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: 680)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.automatic)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)

      Text("Loading lesson...")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.inkSubtle)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading lesson")
  }

  // MARK: - Error View

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(Color.incorrectRed)
        .accessibilityHidden(true)

      Text("Unable to load lesson")
        .font(.headline)
        .foregroundStyle(Color.ink)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(Color.inkSubtle)
        .multilineTextAlignment(.center)

      Button("Go Back") {
        onDismiss()
      }
      .buttonStyle(.borderedProminent)
      .padding(.top, 8)
      .accessibilityHint("Returns to the dashboard")
    }
    .padding(32)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Home Button Style

// Button style matching HomeButtonView from the editors.
// Uses scale down on press with white highlight, spring bounce back.
struct HomeButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
      .background(
        Circle()
          .fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0))
          .frame(width: 48, height: 48)
      )
      .animation(
        configuration.isPressed
          ? .easeOut(duration: 0.1)
          : .spring(response: 0.35, dampingFraction: 0.5),
        value: configuration.isPressed
      )
  }
}

// MARK: - Lesson Progress View

// Displays compact progress indicator for the navigation bar.
struct LessonProgressView: View {
  let currentSection: Int
  let totalSections: Int

  var body: some View {
    HStack(spacing: 8) {
      // Progress dots or text for small section counts.
      if totalSections <= 8 {
        HStack(spacing: 4) {
          ForEach(0..<totalSections, id: \.self) { index in
            Circle()
              .fill(index < currentSection ? Color.lessonAccent : Color.inkFaint)
              .frame(width: 6, height: 6)
          }
        }
      } else {
        // Text for larger section counts.
        Text("\(currentSection) of \(totalSections)")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.inkSubtle)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
    )
    .accessibilityLabel("Section \(currentSection) of \(totalSections)")
  }
}

// MARK: - Lesson Header View

// Displays the lesson title.
struct LessonHeaderView: View {
  let lesson: Lesson
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Subject badge if available.
      if let subject = lesson.metadata.subject {
        Text(subject.uppercased())
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.lessonAccent)
          .accessibilityLabel("Subject: \(subject)")
      }

      // Title.
      Text(lesson.title)
        .font(.title.bold())
        .foregroundStyle(Color.ink)
        .accessibilityAddTraits(.isHeader)
    }
  }
}

// MARK: - Lesson Section View

// Routes to the appropriate section view based on type.
struct LessonSectionView: View {
  let section: LessonSection
  let sectionIndex: Int
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    Group {
      switch section {
      case .content(let contentSection):
        ContentSectionView(section: contentSection, viewModel: viewModel)
      case .visual(let visualSection):
        VisualPlaceholderView(section: visualSection, viewModel: viewModel)
      case .question(let questionSection):
        QuestionSectionView(section: questionSection, viewModel: viewModel)
      case .summary(let summarySection):
        SummarySectionView(section: summarySection, viewModel: viewModel)
      }
    }
    .onAppear {
      // Mark section as viewed when it appears.
      Task {
        await viewModel.markSectionViewed(section.id)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  LessonView(lessonID: "preview", onDismiss: {})
}
