// QuestionSectionCell.swift
// UICollectionViewCell displaying question sections with answer input.

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
    view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
    view.layer.cornerRadius = 12
    view.layer.borderWidth = 1
    view.layer.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).cgColor
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let questionLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 17, weight: .medium)
    label.textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let optionsStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  private let feedbackContainer: UIView = {
    let view = UIView()
    view.layer.cornerRadius = 8
    view.clipsToBounds = true
    view.isHidden = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let feedbackLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let checkAnswerButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Check Answer", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    button.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
    button.layer.cornerRadius = 10
    button.isEnabled = false
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  // Container for handwriting canvas (freeResponse/math questions).
  // Public so the canvas manager can embed the InputViewController here.
  let canvasContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .white
    view.layer.cornerRadius = 8
    view.layer.borderWidth = 1
    view.layer.borderColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0).cgColor
    view.isHidden = true
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let canvasLabel: UILabel = {
    let label = UILabel()
    label.text = "Handwriting input area"
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let canvasIcon: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(systemName: "pencil.tip")
    imageView.tintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
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
    containerView.addSubview(questionLabel)
    containerView.addSubview(optionsStack)
    containerView.addSubview(canvasContainer)
    containerView.addSubview(feedbackContainer)
    containerView.addSubview(checkAnswerButton)

    canvasContainer.addSubview(canvasIcon)
    canvasContainer.addSubview(canvasLabel)

    feedbackContainer.addSubview(feedbackLabel)

    canvasHeightConstraint = canvasContainer.heightAnchor.constraint(equalToConstant: 150)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

      questionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
      questionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      questionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

      optionsStack.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 16),
      optionsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      optionsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

      canvasContainer.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 16),
      canvasContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      canvasContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
      canvasHeightConstraint,

      canvasIcon.centerXAnchor.constraint(equalTo: canvasContainer.centerXAnchor),
      canvasIcon.centerYAnchor.constraint(equalTo: canvasContainer.centerYAnchor, constant: -12),
      canvasIcon.widthAnchor.constraint(equalToConstant: 32),
      canvasIcon.heightAnchor.constraint(equalToConstant: 32),

      canvasLabel.topAnchor.constraint(equalTo: canvasIcon.bottomAnchor, constant: 8),
      canvasLabel.centerXAnchor.constraint(equalTo: canvasContainer.centerXAnchor),

      feedbackContainer.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 12),
      feedbackContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      feedbackContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

      feedbackLabel.topAnchor.constraint(equalTo: feedbackContainer.topAnchor, constant: 12),
      feedbackLabel.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 12),
      feedbackLabel.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -12),
      feedbackLabel.bottomAnchor.constraint(equalTo: feedbackContainer.bottomAnchor, constant: -12),

      checkAnswerButton.topAnchor.constraint(equalTo: feedbackContainer.bottomAnchor, constant: 12),
      checkAnswerButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      checkAnswerButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
      checkAnswerButton.heightAnchor.constraint(equalToConstant: 48),
      checkAnswerButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
    ])
  }

  private func setupActions() {
    checkAnswerButton.addTarget(self, action: #selector(checkAnswerTapped), for: .touchUpInside)

    // Add tap gesture to canvas container to activate it for tool commands.
    let canvasTap = UITapGestureRecognizer(target: self, action: #selector(canvasContainerTapped))
    canvasContainer.addGestureRecognizer(canvasTap)
  }

  @objc private func canvasContainerTapped() {
    guard let sectionID = section?.id else { return }
    delegate?.questionCell(self, didActivateCanvas: sectionID)
  }

  // MARK: - Configuration

  func configure(with section: QuestionSection, viewModel: LessonViewModel) {
    self.section = section
    self.viewModel = viewModel

    questionLabel.text = section.prompt

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

    // Add option buttons.
    for (index, option) in options.enumerated() {
      let button = createOptionButton(text: option, index: index)
      optionsStack.addArrangedSubview(button)
    }
  }

  private func createOptionButton(text: String, index: Int) -> UIButton {
    let button = UIButton(type: .system)
    button.tag = index

    // Configure button appearance.
    var config = UIButton.Configuration.plain()
    config.title = text
    config.baseForegroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    config.background.backgroundColor = .white
    config.background.cornerRadius = 8
    config.background.strokeColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
    config.background.strokeWidth = 1
    config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    config.titleAlignment = .leading

    button.configuration = config
    button.contentHorizontalAlignment = .leading
    button.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)

    return button
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
        break

      case .selected(let answer):
        // Find and select the option.
        if let options = section?.options,
           let index = options.firstIndex(of: answer) {
          selectOption(at: index)
        }

      case .checking:
        checkAnswerButton.isEnabled = false
        checkAnswerButton.setTitle("Checking...", for: .normal)

      case .correct(let feedback):
        showFeedback(feedback, isCorrect: true)
        disableInteraction()

      case .incorrect(let feedback):
        showFeedback(feedback, isCorrect: false)

      case .revealed:
        if let answer = section?.answer {
          showFeedback("The correct answer is: \(answer)", isCorrect: false)
        }
        disableInteraction()
      }
    }
  }

  // MARK: - Actions

  @objc private func optionTapped(_ sender: UIButton) {
    let index = sender.tag
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
       previousIndex < optionsStack.arrangedSubviews.count,
       let previousButton = optionsStack.arrangedSubviews[previousIndex] as? UIButton {
      updateOptionButton(previousButton, isSelected: false)
    }

    // Select new.
    selectedOptionIndex = index
    if index < optionsStack.arrangedSubviews.count,
       let button = optionsStack.arrangedSubviews[index] as? UIButton {
      updateOptionButton(button, isSelected: true)
    }

    checkAnswerButton.isEnabled = true
  }

  private func updateOptionButton(_ button: UIButton, isSelected: Bool) {
    guard var config = button.configuration else { return }

    if isSelected {
      config.background.backgroundColor = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)
      config.background.strokeColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
      config.background.strokeWidth = 2
    } else {
      config.background.backgroundColor = .white
      config.background.strokeColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
      config.background.strokeWidth = 1
    }

    button.configuration = config
  }

  @objc private func checkAnswerTapped() {
    guard let section = section else { return }

    checkAnswerButton.isEnabled = false
    checkAnswerButton.setTitle("Checking...", for: .normal)

    Task {
      await viewModel?.checkAnswer(for: section.id)

      // Update UI based on result.
      await MainActor.run {
        if let answerState = viewModel?.answerStates[section.id] {
          switch answerState {
          case .correct(let feedback):
            showFeedback(feedback, isCorrect: true)
            disableInteraction()
          case .incorrect(let feedback):
            showFeedback(feedback, isCorrect: false)
            checkAnswerButton.isEnabled = true
            checkAnswerButton.setTitle("Try Again", for: .normal)
          default:
            checkAnswerButton.isEnabled = true
            checkAnswerButton.setTitle("Check Answer", for: .normal)
          }
        }
      }
    }
  }

  private func showFeedback(_ message: String, isCorrect: Bool) {
    feedbackContainer.isHidden = false
    feedbackLabel.text = message

    if isCorrect {
      feedbackContainer.backgroundColor = UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
      feedbackLabel.textColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
    } else {
      feedbackContainer.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
      feedbackLabel.textColor = UIColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)
    }

    // Update layout.
    setNeedsLayout()
    layoutIfNeeded()
  }

  private func disableInteraction() {
    checkAnswerButton.isHidden = true

    // Disable all option buttons.
    for case let button as UIButton in optionsStack.arrangedSubviews {
      button.isEnabled = false
    }
  }

  // MARK: - Reuse

  override func prepareForReuse() {
    super.prepareForReuse()
    section = nil
    viewModel = nil
    selectedOptionIndex = nil

    questionLabel.text = nil
    optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    feedbackContainer.isHidden = true
    feedbackLabel.text = nil
    checkAnswerButton.isHidden = false
    checkAnswerButton.isEnabled = false
    checkAnswerButton.setTitle("Check Answer", for: .normal)
    canvasContainer.isHidden = true
    optionsStack.isHidden = false
  }
}
