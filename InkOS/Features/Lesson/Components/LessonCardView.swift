//
// LessonCardView.swift
// InkOS
//
// Dashboard card for lessons.
// Matches the styling and interactions of NotebookCardButton and PDFDocumentCardButton.
//

import SwiftUI

// MARK: - Lesson Card Button

// Interactive container for a lesson card.
// Mirrors NotebookCardButton behavior for consistent user experience.
struct LessonCardButton: View {
  let lesson: LessonMetadata
  let action: () -> Void
  let onRename: () -> Void
  let onDelete: () -> Void
  // Opacity for the title/date label. Allows parent to fade the title when targeted.
  var titleOpacity: Double = 1.0

  // CONSISTENCY: These values must match NotebookCardButton, PDFDocumentCardButton, FolderCardButton
  private let cardCornerRadius: CGFloat = CardConstants.cornerRadius
  private let titleAreaHeight: CGFloat = CardConstants.titleAreaHeight
  // Keeps a paper-like portrait ratio for the overall container.
  private let cardAspectRatio: CGFloat = CardConstants.aspectRatio

  var body: some View {
    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight

      VStack(alignment: .leading, spacing: 4) {
        // The card portion.
        cardContent(width: totalWidth, height: cardHeight)

        // Title and metadata below the card.
        LessonCardTitle(lesson: lesson)
          .opacity(titleOpacity)
          .animation(.easeOut(duration: 0.2), value: titleOpacity)
      }
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
  }

  // Builds the card content view with tap gesture and context menu.
  @ViewBuilder
  private func cardContent(width: CGFloat, height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

    LessonCardPreview(lesson: lesson)
      .frame(width: width, height: height)
      .background(Color.white)
      .clipShape(shape)
      .shadow(color: CardConstants.Shadow.color, radius: CardConstants.Shadow.radius, x: 0, y: CardConstants.Shadow.yOffset)
      .contentShape(shape)
      .onTapGesture {
        action()
      }
      .contextMenu {
        Button {
          onRename()
        } label: {
          Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
  }
}

// MARK: - Lesson Card Preview

// Displays the lesson card content: preview image or placeholder.
struct LessonCardPreview: View {
  let lesson: LessonMetadata

  // Inset to crop out the thin black line on the right edge of the canvas capture.
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = lesson.previewImage.flatMap { UIImage(data: $0) }

    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        // Draws the preview or placeholder cover.
        // Uses topLeading alignment to anchor the image consistently,
        // preventing vertical shift during context menu transitions.
        if let previewImage {
          Image(uiImage: previewImage)
            .resizable()
            .scaledToFill()
            .frame(width: width + previewEdgeInset, height: height)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
        } else {
          // Placeholder when no preview image exists.
          VStack(spacing: 8) {
            Image(systemName: "book.pages")
              .font(.system(size: 32))
              .foregroundColor(Color.inkSubtle)
            Text("Lesson")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color.inkSubtle)
          }
          .frame(width: width, height: height)
        }
      }
    }
  }
}

// MARK: - Lesson Card Title

// Displays the lesson title and metadata.
struct LessonCardTitle: View {
  let lesson: LessonMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(lesson.displayName)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.ink)
        .lineLimit(1)
        .truncationMode(.tail)

      Text(subtitleText)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.inkSubtle)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 2)
  }

  // Builds the subtitle text from metadata.
  private var subtitleText: String {
    // Always show "Lesson" for all lessons.
    return "Lesson"
  }
}

// MARK: - Lesson Card Context Menu Preview

// Standalone preview view for context menus.
struct LessonCardContextMenuPreview: View {
  let lesson: LessonMetadata

  private let cardCornerRadius: CGFloat = 10
  private let previewWidth: CGFloat = 160
  private let previewHeight: CGFloat = 200
  private let previewEdgeInset: CGFloat = 2

  var body: some View {
    let previewImage = lesson.previewImage.flatMap { UIImage(data: $0) }

    ZStack {
      Color.white

      // Show preview image if available.
      if let previewImage {
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFill()
          .frame(width: previewWidth + previewEdgeInset, height: previewHeight)
          .frame(width: previewWidth, height: previewHeight, alignment: .topLeading)
          .clipped()
      } else {
        // Placeholder when no preview image exists.
        VStack(spacing: 8) {
          Image(systemName: "book.pages")
            .font(.system(size: 32))
            .foregroundColor(Color.inkSubtle)
          Text("Lesson")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.inkSubtle)
        }
      }
    }
    .frame(width: previewWidth, height: previewHeight)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
  }
}

// MARK: - Preview

#Preview {
  let sampleLesson = LessonMetadata(
    id: "preview-1",
    displayName: "Photosynthesis Basics",
    subject: "Biology",
    estimatedMinutes: nil,
    createdAt: Date(),
    modifiedAt: Date(),
    completionPercentage: 0
  )

  return VStack(spacing: 24) {
    LessonCardButton(
      lesson: sampleLesson,
      action: { print("Tapped") },
      onRename: { print("Rename") },
      onDelete: { print("Delete") }
    )
    .frame(width: 160)

    LessonCardContextMenuPreview(lesson: sampleLesson)
  }
  .padding()
  .background(Color.white)
}
