// QuestionSectionCell.swift
// UICollectionViewCell displaying question sections with answer input.
// Uses LessonTypography for consistent visual design.

import UIKit

// Delegate for QuestionSectionCell events.
protocol QuestionSectionCellDelegate: AnyObject {
  // Called when the cell needs a canvas embedded for handwriting input.
  func questionCell(_ cell: QuestionSectionCell, needsCanvasFor sectionID: String, questionType: QuestionType, in container: UIView)

  // Called when the canvas is tapped to become active.
  func questionCell(_ cell: QuestionSectionCell, didActivateCanvas sectionID: String)
}

// Cell displaying a question with appropriate answer input based on type.
// Supports multiple choice, free response, and math questions.
final class QuestionSectionCell: UICollectionViewCell {

  static let reuseIdentifier = "QuestionSectionCell"

  // MARK: - Properties

  weak var delegate: QuestionSectionCellDelegate?

  private var section: QuestionSection?
  private weak var viewModel: LessonViewModel?
  private var selectedOptionIndex: Int?

  // MARK: - UI Elements

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = LessonTypography.Color.questionBackground
    view.layer.cornerRadius = LessonTypography.CornerRadius.medium
    view.layer.borderWidth = 1
    view.layer.borderColor = LessonTypography.Color.border.cgColor
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  // Overline label indicating question number.
  private let questionOverline: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let questionContentView: MathContentView = {
    let view = MathContentView()
    view.fontSize = LessonTypography.Size.body
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let optionsStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = LessonTypography.Spacing.sm
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  private let checkAnswerButton: UIButton = {
    let button = UIButton(type: .system)
    button.titleLabel?.font = LessonTypography.font(size: LessonTypography.Size.body, weight: .semibold)
    button.backgroundColor = LessonTypography.Color.primary
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
    button.layer.cornerRadius = LessonTypography.CornerRadius.small
    button.clipsToBounds = true
    button.isEnabled = false
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  // Container for handwriting canvas (freeResponse/math questions).
  // Public so the canvas manager can embed the InputViewController here.
  let canvasContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .white
    view.layer.cornerRadius = LessonTypography.CornerRadius.small
    view.layer.borderWidth = 1
    view.layer.borderColor = LessonTypography.Color.border.cgColor
    view.isHidden = true
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let canvasLabel: UILabel = {
    let label = UILabel()
    label.text = "Handwriting input area"
    label.font = LessonTypography.font(size: LessonTypography.Size.caption, weight: .medium)
    label.textColor = LessonTypography.Color.tertiary
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // Reload button to reset question state and try again.
  private let reloadButton: UIButton = {
    let button = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
    let image = UIImage(systemName: "arrow.counterclockwise", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = LessonTypography.Color.secondary
    button.backgroundColor = LessonTypography.Color.cardBackground
    button.layer.cornerRadius = 16
    button.clipsToBounds = true
    button.isHidden = true
    button.translatesAutoresizingMaskIntoConstraints = false
    button.accessibilityLabel = "Reset question"
    button.accessibilityHint = "Double tap to reset and try again"
    return button
  }()

  private let canvasIcon: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "pencil.tip")
    imageView.tintColor = LessonTypography.Color.tertiary
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  // Constraint for canvas placeholder height.
  private var canvasHeightConstraint: NSLayoutConstraint!

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
    setupActions()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setupViews() {
    contentView.addSubview(containerView)
    containerView.addSubview(questionOverline)
    containerView.addSubview(reloadButton)
    containerView.addSubview(questionContentView)
    containerView.addSubview(optionsStack)
    containerView.addSubview(canvasContainer)
    containerView.addSubview(checkAnswerButton)

    canvasContainer.addSubview(canvasIcon)
    canvasContainer.addSubview(canvasLabel)

    canvasHeightConstraint = canvasContainer.heightAnchor.constraint(equalToConstant: 150)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LessonTypography.Spacing.md),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LessonTypography.Spacing.sm),

      questionOverline.topAnchor.constraint(equalTo: containerView.topAnchor, constant: LessonTypography.Spacing.lg),
      questionOverline.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      questionOverline.trailingAnchor.constraint(lessThanOrEqualTo: reloadButton.leadingAnchor, constant: -LessonTypography.Spacing.sm),

      reloadButton.centerYAnchor.constraint(equalTo: questionOverline.centerYAnchor),
      reloadButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),
      reloadButton.widthAnchor.constraint(equalToConstant: 32),
      reloadButton.heightAnchor.constraint(equalToConstant: 32),

      questionContentView.topAnchor.constraint(equalTo: questionOverline.bottomAnchor, constant: LessonTypography.Spacing.xs),
      questionContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      questionContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),

      optionsStack.topAnchor.constraint(equalTo: questionContentView.bottomAnchor, constant: LessonTypography.Spacing.lg),
      optionsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      optionsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),

      canvasContainer.topAnchor.constraint(equalTo: questionContentView.bottomAnchor, constant: LessonTypography.Spacing.lg),
      canvasContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      canvasContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),
      canvasHeightConstraint,

      canvasIcon.centerXAnchor.constraint(equalTo: canvasContainer.centerXAnchor),
      canvasIcon.centerYAnchor.constraint(equalTo: canvasContainer.centerYAnchor, constant: -12),
      canvasIcon.widthAnchor.constraint(equalToConstant: 32),
      canvasIcon.heightAnchor.constraint(equalToConstant: 32),

      canvasLabel.topAnchor.constraint(equalTo: canvasIcon.bottomAnchor, constant: LessonTypography.Spacing.xs),
      canvasLabel.centerXAnchor.constraint(equalTo: canvasContainer.centerXAnchor),

      checkAnswerButton.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: LessonTypography.Spacing.lg),
      checkAnswerButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: LessonTypography.Spacing.lg),
      checkAnswerButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -LessonTypography.Spacing.lg),
      checkAnswerButton.heightAnchor.constraint(equalToConstant: 52),
      checkAnswerButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -LessonTypography.Spacing.lg)
    ])

    // Configure button title with proper letter spacing for uppercase text.
    updateButtonTitle("CHECK ANSWER", enabled: false)
  }

  private func setupActions() {
    checkAnswerButton.addTarget(self, action: #selector(checkAnswerTapped), for: .touchUpInside)
    reloadButton.addTarget(self, action: #selector(reloadButtonTapped), for: .touchUpInside)

    // Add tap gesture to canvas container to activate it for tool commands.
    let canvasTap = UITapGestureRecognizer(target: self, action: #selector(canvasContainerTapped))
    canvasContainer.addGestureRecognizer(canvasTap)
  }

  @objc private func canvasContainerTapped() {
    guard let sectionID = section?.id else { return }
    delegate?.questionCell(self, didActivateCanvas: sectionID)
  }

  @objc private func reloadButtonTapped() {
    guard let section = section, let viewModel = viewModel else { return }

    // Haptic feedback.
    let haptic = UIImpactFeedbackGenerator(style: .light)
    haptic.impactOccurred()

    // Animate button rotation.
    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) { [weak self] in
      self?.reloadButton.transform = CGAffineTransform(rotationAngle: -.pi)
    } completion: { [weak self] _ in
      self?.reloadButton.transform = .identity
    }

    // Reset the question in the view model.
    Task {
      await viewModel.resetQuestion(for: section.id)

      // Reset the cell's visual state.
      await MainActor.run { [weak self] in
        self?.resetVisualState()
      }
    }
  }

  // Resets the cell's visual state to unanswered.
  private func resetVisualState() {
    // Clear option selection.
    if let previousIndex = selectedOptionIndex,
       previousIndex < optionsStack.arrangedSubviews.count {
      let previousView = optionsStack.arrangedSubviews[previousIndex]
      updateOptionView(previousView, isSelected: false)
    }
    selectedOptionIndex = nil

    // Reset button state.
    checkAnswerButton.isEnabled = false
    updateButtonTitle("CHECK ANSWER", enabled: false)

    // Hide reload button since question is now unanswered.
    reloadButton.isHidden = true
  }

  // MARK: - Configuration

  func configure(with section: QuestionSection, viewModel: LessonViewModel) {
    self.section = section
    self.viewModel = viewModel

    // Set accessibility identifier for UI testing.
    accessibilityIdentifier = "questionSection_\(section.id)"
    checkAnswerButton.accessibilityIdentifier = "checkAnswerButton_\(section.id)"
    containerView.accessibilityIdentifier = "questionContainer_\(section.id)"

    // Configure overline.
    let overlineAttributes: [NSAttributedString.Key: Any] = [
      .font: LessonTypography.font(size: LessonTypography.Size.overline, weight: .semibold),
      .foregroundColor: LessonTypography.Color.accent,
      .kern: 1.2
    ]
    questionOverline.attributedText = NSAttributedString(string: "QUESTION", attributes: overlineAttributes)

    questionContentView.configure(with: section.prompt)

    // Configure based on question type.
    switch section.questionType {
    case .multipleChoice:
      configureMultipleChoice(options: section.options ?? [])
      optionsStack.isHidden = false
      canvasContainer.isHidden = true

    case .freeResponse:
      configureFreeResponse()
      optionsStack.isHidden = true
      canvasContainer.isHidden = false
      canvasLabel.text = "Write your answer here"
      // Request canvas embedding from delegate.
      delegate?.questionCell(self, needsCanvasFor: section.id, questionType: .freeResponse, in: canvasContainer)

    case .math:
      configureMath()
      optionsStack.isHidden = true
      canvasContainer.isHidden = false
      canvasLabel.text = "Show your work"
      // Request canvas embedding from delegate.
      delegate?.questionCell(self, needsCanvasFor: section.id, questionType: .math, in: canvasContainer)
    }

    // Restore state from view model.
    restoreState(for: section.id)
  }

  private func configureMultipleChoice(options: [String]) {
    // Clear existing options.
    optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    selectedOptionIndex = nil

    // Add option views.
    for (index, option) in options.enumerated() {
      let optionView = createOptionView(text: option, index: index)
      optionsStack.addArrangedSubview(optionView)
    }
  }

  private func createOptionView(text: String, index: Int) -> UIView {
    let container = UIView()
    container.tag = index
    container.backgroundColor = .white
    container.layer.cornerRadius = LessonTypography.CornerRadius.small
    container.layer.borderWidth = 1
    container.layer.borderColor = LessonTypography.Color.border.cgColor

    // Set accessibility identifier for option.
    let optionLetterForID = ["A", "B", "C", "D", "E", "F"]
    let letterID = index < optionLetterForID.count ? optionLetterForID[index] : "\(index + 1)"
    container.accessibilityIdentifier = "option_\(letterID)"
    container.isAccessibilityElement = true
    container.accessibilityLabel = "Option \(letterID)"

    // Option label (A, B, C, D).
    let optionLetters = ["A", "B", "C", "D", "E", "F"]
    let letterLabel = UILabel()
    letterLabel.text = index < optionLetters.count ? optionLetters[index] : "\(index + 1)"
    letterLabel.font = LessonTypography.font(size: LessonTypography.Size.caption, weight: .semibold)
    letterLabel.textColor = LessonTypography.Color.secondary
    letterLabel.textAlignment = .center
    letterLabel.translatesAutoresizingMaskIntoConstraints = false

    let letterContainer = UIView()
    letterContainer.backgroundColor = LessonTypography.Color.cardBackground
    letterContainer.layer.cornerRadius = 14
    letterContainer.translatesAutoresizingMaskIntoConstraints = false

    letterContainer.addSubview(letterLabel)

    let mathContent = MathContentView()
    mathContent.fontSize = LessonTypography.Size.body
    mathContent.configure(with: text)
    mathContent.translatesAutoresizingMaskIntoConstraints = false
    mathContent.isUserInteractionEnabled = false

    container.addSubview(letterContainer)
    container.addSubview(mathContent)

    NSLayoutConstraint.activate([
      letterContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: LessonTypography.Spacing.md),
      letterContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      letterContainer.widthAnchor.constraint(equalToConstant: 28),
      letterContainer.heightAnchor.constraint(equalToConstant: 28),

      letterLabel.centerXAnchor.constraint(equalTo: letterContainer.centerXAnchor),
      letterLabel.centerYAnchor.constraint(equalTo: letterContainer.centerYAnchor),

      mathContent.topAnchor.constraint(equalTo: container.topAnchor, constant: LessonTypography.Spacing.md),
      mathContent.leadingAnchor.constraint(equalTo: letterContainer.trailingAnchor, constant: LessonTypography.Spacing.sm),
      mathContent.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -LessonTypography.Spacing.md),
      mathContent.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -LessonTypography.Spacing.md)
    ])

    // Add tap gesture.
    let tap = UITapGestureRecognizer(target: self, action: #selector(optionViewTapped(_:)))
    container.addGestureRecognizer(tap)
    container.isUserInteractionEnabled = true

    return container
  }

  private func configureFreeResponse() {
    // Canvas placeholder is shown. Actual canvas will be embedded later.
    canvasHeightConstraint.constant = 150
  }

  private func configureMath() {
    // Math questions get a taller canvas for showing work.
    canvasHeightConstraint.constant = 200
  }

  private func restoreState(for sectionID: String) {
    guard let viewModel = viewModel else { return }

    // Check if there's a saved answer state.
    if let answerState = viewModel.answerStates[sectionID] {
      switch answerState {
      case .unanswered:
        reloadButton.isHidden = true

      case .selected(let answer):
        // Find and select the option.
        if let options = section?.options,
           let index = options.firstIndex(of: answer) {
          selectOption(at: index)
        }
        reloadButton.isHidden = true

      case .correct:
        // Restore correct answer visual state.
        if let options = section?.options,
           let selectedAnswer = viewModel.selectedAnswers[sectionID],
           let index = options.firstIndex(of: selectedAnswer) {
          selectOption(at: index)
        }
        updateButtonTitle("CORRECT!", enabled: true)
        checkAnswerButton.isEnabled = false
        // Show reload button so user can try again.
        reloadButton.isHidden = false

      case .checking:
        // Restore selected option for checking state.
        if let options = section?.options,
           let selectedAnswer = viewModel.selectedAnswers[sectionID],
           let index = options.firstIndex(of: selectedAnswer) {
          selectOption(at: index)
        }
        reloadButton.isHidden = true

      case .incorrect, .revealed:
        // Restore selected option for these states.
        if let options = section?.options,
           let selectedAnswer = viewModel.selectedAnswers[sectionID],
           let index = options.firstIndex(of: selectedAnswer) {
          selectOption(at: index)
        }
        // Show reload button so user can try again.
        reloadButton.isHidden = false
      }
    } else {
      reloadButton.isHidden = true
    }
  }

  // MARK: - Actions

  @objc private func optionViewTapped(_ gesture: UITapGestureRecognizer) {
    guard let view = gesture.view else {
      return
    }
    let index = view.tag
    selectOption(at: index)

    // Update view model.
    guard let section = section,
          let options = section.options,
          index < options.count else {
      return
    }

    viewModel?.selectAnswer(options[index], for: section.id)
  }

  private func selectOption(at index: Int) {
    // Deselect previous.
    if let previousIndex = selectedOptionIndex,
       previousIndex < optionsStack.arrangedSubviews.count {
      let previousView = optionsStack.arrangedSubviews[previousIndex]
      updateOptionView(previousView, isSelected: false)
    }

    // Select new.
    selectedOptionIndex = index
    if index < optionsStack.arrangedSubviews.count {
      let view = optionsStack.arrangedSubviews[index]
      updateOptionView(view, isSelected: true)
    }

    checkAnswerButton.isEnabled = true
    updateButtonTitle("CHECK ANSWER", enabled: true)
  }

  private func updateOptionView(_ view: UIView, isSelected: Bool) {
    // Find the letter container (first subview that is a container with background).
    let letterContainer = view.subviews.first { $0.layer.cornerRadius == 14 }

    if isSelected {
      view.backgroundColor = LessonTypography.Color.summaryBackground
      view.layer.borderColor = LessonTypography.Color.borderSelected.cgColor
      view.layer.borderWidth = 2
      letterContainer?.backgroundColor = LessonTypography.Color.accent
      if let letterLabel = letterContainer?.subviews.first as? UILabel {
        letterLabel.textColor = .white
      }
    } else {
      view.backgroundColor = .white
      view.layer.borderColor = LessonTypography.Color.border.cgColor
      view.layer.borderWidth = 1
      letterContainer?.backgroundColor = LessonTypography.Color.cardBackground
      if let letterLabel = letterContainer?.subviews.first as? UILabel {
        letterLabel.textColor = LessonTypography.Color.secondary
      }
    }
  }

  @objc private func checkAnswerTapped() {
    guard let section = section, let viewModel = viewModel else {
      return
    }

    // Disable button during check.
    checkAnswerButton.isEnabled = false

    // Record the answer in the view model and check result.
    Task {
      await viewModel.checkAnswer(for: section.id)

      // Check the answer state after the check completes.
      let answerState = viewModel.answerStates[section.id]

      if case .correct? = answerState {
        await MainActor.run {
          updateButtonTitle("CORRECT!", enabled: true)
        }
      } else {
        // Re-enable the button for another attempt.
        await MainActor.run {
          checkAnswerButton.isEnabled = true
          updateButtonTitle("CHECK ANSWER", enabled: true)
        }
      }
    }
  }

  private func updateButtonTitle(_ title: String, enabled: Bool) {
    // Apply letter spacing for uppercase button text.
    let attributes: [NSAttributedString.Key: Any] = [
      .font: LessonTypography.font(size: LessonTypography.Size.body, weight: .semibold),
      .foregroundColor: enabled ? UIColor.white : UIColor.white.withAlphaComponent(0.5),
      .kern: 1.0
    ]
    let attributedTitle = NSAttributedString(string: title, attributes: attributes)
    checkAnswerButton.setAttributedTitle(attributedTitle, for: .normal)
    checkAnswerButton.setAttributedTitle(attributedTitle, for: .disabled)
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    section = nil
    viewModel = nil
    selectedOptionIndex = nil

    questionContentView.clear()
    optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    checkAnswerButton.isEnabled = false
    checkAnswerButton.backgroundColor = LessonTypography.Color.primary
    updateButtonTitle("CHECK ANSWER", enabled: false)
    canvasContainer.isHidden = true
    optionsStack.isHidden = false

    // Reset reload button.
    reloadButton.isHidden = true
    reloadButton.transform = .identity
  }
}
