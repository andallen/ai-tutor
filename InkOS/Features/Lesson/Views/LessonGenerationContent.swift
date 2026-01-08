import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

// Available lesson generation models.
enum LessonModel: String, CaseIterable, Identifiable {
  case gemini3FlashPreview = "Gemini 3 Flash Preview"

  var id: String { rawValue }
}

// Lesson difficulty levels.
enum LessonDifficulty: String, CaseIterable, Identifiable {
  case elementary = "Elementary"
  case middleSchool = "Middle School"
  case highSchool = "High School"
  case college = "College"

  var id: String { rawValue }
}

// MARK: - Lesson Input Bar

// Expanding input bar for lesson description.
// Similar to AIChatInputBar but with lesson-specific placeholder.
struct LessonInputBar: View {
  // Text entered by the user.
  @Binding var text: String
  // External focus control binding.
  var isFocused: FocusState<Bool>.Binding?
  // Called when the generate button is tapped.
  var onGenerate: () -> Void
  // Whether generation is in progress.
  var isGenerating: Bool
  // Called when a file is selected.
  var onFileSelected: (URL) -> Void

  // Internal focus state used when no external binding is provided.
  @FocusState private var internalFocus: Bool
  // Controls file picker presentation.
  @State private var showFilePicker = false

  // Line height for the text editor (17pt font + line spacing).
  private let lineHeight: CGFloat = 22
  // Maximum number of visible lines before scrolling.
  private let maxLines: Int = 8
  // Minimum height for single line (includes padding).
  private let minHeight: CGFloat = 48
  // Vertical padding inside the text editor area.
  private let verticalPadding: CGFloat = 14
  // Corner radius for the rounded rectangle background.
  private let cornerRadius: CGFloat = 24

  // Supported file types for Gemini API (images and documents only).
  private let supportedFileTypes: [UTType] = [
    // Images
    .png, .jpeg, .webP, .heic, .heif,
    // Documents
    .pdf, .plainText, .html, .xml
  ]

  // Whether the generate button is enabled (has non-whitespace text and not generating).
  private var isGenerateEnabled: Bool {
    !text.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating
  }

  // Calculates the number of lines in the current text.
  private var lineCount: Int {
    let lines = text.components(separatedBy: .newlines)
    // Count wrapped lines by estimating characters per line.
    let estimatedCharsPerLine = 35
    var totalLines = 0
    for line in lines {
      if line.isEmpty {
        totalLines += 1
      } else {
        totalLines += max(1, Int(ceil(Double(line.count) / Double(estimatedCharsPerLine))))
      }
    }
    return max(1, totalLines)
  }

  // Dynamic height based on content, capped at maxLines.
  private var dynamicHeight: CGFloat {
    let contentLines = min(lineCount, maxLines)
    let contentHeight = CGFloat(contentLines) * lineHeight + verticalPadding * 2
    return max(minHeight, contentHeight)
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      // Plus button for file upload - fixed size white circle.
      Button(action: {
        showFilePicker = true
      }) {
        Circle()
          .fill(Color.white)
          .frame(width: 48, height: 48)
          .overlay(
            Image(systemName: "plus")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.black)
          )
      }
      .disabled(isGenerating)

      // Multiline text editor with placeholder and generate button.
      HStack(alignment: .bottom, spacing: 0) {
        // Multiline text editor with placeholder.
        ZStack(alignment: .topLeading) {
          // Placeholder text shown when empty.
          if text.isEmpty {
            Text("Describe your lesson")
              .font(.system(size: 17))
              .foregroundColor(Color(white: 0.5))
              .padding(.leading, 20)
              .padding(.top, verticalPadding)
              .allowsHitTesting(false)
          }

          // Multiline text editor.
          TextEditor(text: $text)
            .font(.system(size: 17))
            .foregroundColor(.primary)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .scrollDismissesKeyboard(.never)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, verticalPadding - 8)
            .focused(isFocused ?? $internalFocus)
            .frame(height: dynamicHeight)
            .disabled(isGenerating)
        }

        // Generate button - circular black arrow inside the bar.
        Button(action: {
          if isGenerateEnabled {
            onGenerate()
          }
        }) {
          Circle()
            .fill(isGenerateEnabled ? Color.black : Color(white: 0.78))
            .frame(width: 36, height: 36)
            .overlay(
              Group {
                if isGenerating {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                } else {
                  Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isGenerateEnabled ? .white : Color(white: 0.92))
                }
              }
            )
        }
        .disabled(!isGenerateEnabled)
        .animation(.easeInOut(duration: 0.15), value: isGenerateEnabled)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
      }
      .frame(height: dynamicHeight)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color(white: 0.93))
      )
    }
    .animation(.easeInOut(duration: 0.15), value: dynamicHeight)
    .fileImporter(
      isPresented: $showFilePicker,
      allowedContentTypes: supportedFileTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          onFileSelected(url)
        }
      case .failure(let error):
        print("❌ File picker error: \(error.localizedDescription)")
      }
    }
  }

  init(
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding? = nil,
    isGenerating: Bool = false,
    onGenerate: @escaping () -> Void,
    onFileSelected: @escaping (URL) -> Void
  ) {
    self._text = text
    self.isFocused = isFocused
    self.isGenerating = isGenerating
    self.onGenerate = onGenerate
    self.onFileSelected = onFileSelected
  }
}

// MARK: - Main Content View

// Content view for the lesson generation overlay.
// Contains model selector and expanding input bar.
struct LessonGenerationContent: View {
  // Text entered in the input bar.
  @Binding var text: String
  // External focus control binding for keyboard.
  var isFocused: FocusState<Bool>.Binding?
  // Whether generation is in progress.
  var isGenerating: Bool
  // Called when the generate button is tapped (passes optional file URL).
  var onGenerate: (URL?) -> Void

  // Currently selected model.
  @State private var selectedModel: LessonModel = .gemini3FlashPreview
  // Selected file URL for lesson generation.
  @State private var selectedFileURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with model selector and subtle helper text.
      headerView

      Spacer()

      // Selected file indicator (if a file is chosen).
      if let fileURL = selectedFileURL {
        fileIndicator(for: fileURL)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }

      // Expanding lesson input bar with focus binding.
      LessonInputBar(
        text: $text,
        isFocused: isFocused,
        isGenerating: isGenerating,
        onGenerate: {
          onGenerate(selectedFileURL)
        },
        onFileSelected: { url in
          selectedFileURL = url
        }
      )
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
  }

  // Header containing model dropdown selector and subtle helper text.
  private var headerView: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Model selector menu.
      modelMenu

      // Subtle helper text.
      Text("Upload a file or describe your lesson topic")
        .font(.system(size: 12))
        .foregroundColor(Color(white: 0.5))
        .padding(.leading, 10)
    }
    .padding(.leading, 12)
    .padding(.top, 8)
  }

  // Native Apple Menu for model selection.
  private var modelMenu: some View {
    Menu {
      ForEach(LessonModel.allCases) { model in
        Button(action: {
          selectedModel = model
        }) {
          HStack {
            Text(model.rawValue)
            if selectedModel == model {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text("Model:")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.black)

        Text(selectedModel.rawValue)
          .font(.system(size: 14))
          .foregroundColor(Color(white: 0.5))

        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(Color(white: 0.5))
      }
      .fixedSize()
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
    .disabled(isGenerating)
  }

  // File indicator showing selected file name with remove button.
  private func fileIndicator(for url: URL) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "paperclip")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Color(white: 0.5))

      Text(url.lastPathComponent)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(Color.ink)
        .lineLimit(1)

      Button(action: {
        selectedFileURL = nil
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(Color(white: 0.6))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(white: 0.93))
    )
  }

  init(
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding? = nil,
    isGenerating: Bool = false,
    onGenerate: @escaping (URL?) -> Void
  ) {
    self._text = text
    self.isFocused = isFocused
    self.isGenerating = isGenerating
    self.onGenerate = onGenerate
  }
}

#if DEBUG
struct LessonGenerationContent_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color.gray.opacity(0.3)
        .ignoresSafeArea()

      LessonGenerationContent(
        text: .constant(""),
        isGenerating: false,
        onGenerate: { _ in }
      )
      .frame(width: 400, height: 520)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.ultraThinMaterial)
      )
    }
  }
}
#endif
