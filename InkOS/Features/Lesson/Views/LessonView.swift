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
      // Home button.
      Button(action: {
        onDismiss()
      }) {
        ZStack {
          Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)

          Image(systemName: "house")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Color.offBlack)
        }
      }
      .buttonStyle(GlassButtonStyle())

      Spacer()

      // Options menu placeholder.
      Menu {
        Button(role: .destructive) {
          // Delete action would go here.
        } label: {
          Label("Delete Lesson", systemImage: "trash")
        }
      } label: {
        ZStack {
          Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)

          Image(systemName: "ellipsis")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color.offBlack)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
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
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)

      Text("Loading lesson...")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
    }
  }

  // MARK: - Error View

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundStyle(Color.incorrectRed)

      Text("Unable to load lesson")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Color.ink)

      Text(message)
        .font(.system(size: 15))
        .foregroundStyle(Color.inkSubtle)
        .multilineTextAlignment(.center)

      Button("Go Back") {
        onDismiss()
      }
      .buttonStyle(.borderedProminent)
      .padding(.top, 8)
    }
    .padding(32)
  }
}

// MARK: - Glass Button Style

// Button style matching the glass aesthetic of the app.
struct GlassButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
      .opacity(configuration.isPressed ? 0.8 : 1.0)
      .animation(.spring(response: 0.15, dampingFraction: 0.75), value: configuration.isPressed)
  }
}

// MARK: - Lesson Header View

// Displays the lesson title.
struct LessonHeaderView: View {
  let lesson: Lesson
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Title.
      Text(lesson.title)
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(Color.ink)
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
