//
// VisualPlaceholderView.swift
// InkOS
//
// Displays a placeholder for visual sections.
// Shows the image prompt text since image generation is deferred.
//

import SwiftUI

// Placeholder view for visual sections showing the image prompt.
struct VisualPlaceholderView: View {
  let section: VisualSection
  @ObservedObject var viewModel: LessonViewModel

  var body: some View {
    VStack(spacing: 12) {
      // Placeholder container.
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.rule)

        VStack(spacing: 16) {
          // Image icon.
          Image(systemName: "photo")
            .font(.title.weight(.light))
            .foregroundStyle(Color.inkFaint)
            .accessibilityHidden(true)

          // Image prompt text.
          if let imagePrompt = section.imagePrompt {
            Text("\"\(imagePrompt)\"")
              .font(.subheadline.italic())
              .foregroundStyle(Color.inkSubtle)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          } else if let fallbackDescription = section.fallbackDescription {
            Text(fallbackDescription)
              .font(.subheadline)
              .foregroundStyle(Color.inkSubtle)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }
        }
        .padding(.vertical, 24)
      }
      .frame(minHeight: 160)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityDescription)
    }
  }

  // Provides a meaningful description for VoiceOver.
  private var accessibilityDescription: String {
    if let imagePrompt = section.imagePrompt {
      return "Visual illustration: \(imagePrompt)"
    } else if let fallbackDescription = section.fallbackDescription {
      return "Visual illustration: \(fallbackDescription)"
    }
    return "Visual illustration placeholder"
  }
}

// MARK: - Preview

#Preview {
  let sampleVisual = VisualSection(
    visualType: .generated,
    imagePrompt: "Labeled cross-section diagram of a chloroplast showing thylakoid membranes, stroma, and granum stacks"
  )

  return VStack {
    VisualPlaceholderView(section: sampleVisual, viewModel: LessonViewModel())
      .padding(24)
  }
  .background(Color.white)
}
