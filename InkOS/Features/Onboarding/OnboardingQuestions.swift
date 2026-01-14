import Combine
import Foundation

// Represents a single onboarding question with its answer choices.
struct OnboardingQuestion: Identifiable {
    let id: Int
    let question: String
    let options: [String]
    let allowsMultipleSelection: Bool
    let requiresTextInput: Bool

    init(
        id: Int,
        question: String,
        options: [String],
        allowsMultipleSelection: Bool = false,
        requiresTextInput: Bool = false
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
        self.requiresTextInput = requiresTextInput
    }
}

// All onboarding questions for the Alan app.
// These help Alan tailor the learning experience to each user.
enum OnboardingQuestions {
    static let all: [OnboardingQuestion] = [
        OnboardingQuestion(
            id: 1,
            question: "What are you trying to get done right now?",
            options: ["Study for an exam", "Finish work", "Catch up on lectures", "Teach myself a topic", "Other"]
        ),
        OnboardingQuestion(
            id: 2,
            question: "Which subject are we working on first?",
            options: ["STEM", "Humanities", "Writing and literature", "Social science", "Business", "Law", "Medicine / Health", "Languages", "Other"]
        ),
        OnboardingQuestion(
            id: 3,
            question: "What level is this?",
            options: ["Middle school", "High school", "Undergrad", "Graduate", "Professional", "Other"]
        ),
        OnboardingQuestion(
            id: 4,
            question: "When is your next deadline?",
            options: ["Today", "This week", "2–4 weeks", "1–3 months", "No deadline"]
        ),
        OnboardingQuestion(
            id: 5,
            question: "Which part of learning is most annoying to you right now?",
            options: ["I don't get it in lecture", "I forget fast", "I make dumb mistakes", "I freeze on tests", "I waste time", "Other"]
        ),
        OnboardingQuestion(
            id: 6,
            question: "How do you want Alan to teach?",
            options: ["Direct explanation", "Ask me questions", "Mix of both"]
        ),
        OnboardingQuestion(
            id: 7,
            question: "How much detail should Alan provide by default?",
            options: ["Short", "Medium", "Very detailed", "Auto"]
        ),
        OnboardingQuestion(
            id: 8,
            question: "What helps you learn most?",
            options: ["Worked examples", "Practice questions", "Visuals", "Diagrams", "Summaries", "Other"],
            allowsMultipleSelection: true
        ),
        OnboardingQuestion(
            id: 9,
            question: "When you ask for help, what do you want first?",
            options: ["A hint", "The next step", "A full answer"]
        ),
        OnboardingQuestion(
            id: 10,
            question: "How hard should practice be?",
            options: ["Easy confidence-build", "Medium", "Hard", "Adaptive based on misses"]
        ),
        OnboardingQuestion(
            id: 11,
            question: "How long is a good session for you?",
            options: ["5–10 min", "15–25 min", "30–45 min", "60+ min"]
        ),
        OnboardingQuestion(
            id: 12,
            question: "What will you use most for writing, problem-solving, and/or notes?",
            options: ["Typing", "Handwriting", "Both equally"]
        ),
        OnboardingQuestion(
            id: 13,
            question: "What should Alan's tone be?",
            options: ["Default", "Friendly", "Professional", "Blunt", "Quirky"]
        ),
        OnboardingQuestion(
            id: 14,
            question: "What's one thing you'd like to be true in 30 days?",
            options: ["Higher grades", "Fewer mistakes", "Faster work", "Completing a project", "More discipline", "Other"]
        ),
        OnboardingQuestion(
            id: 15,
            question: "What's a goal you have?",
            options: ["Top grades", "Solid pass", "Understanding deeply", "Getting an internship", "Completing a project"]
        ),
        OnboardingQuestion(
            id: 16,
            question: "What happens if you miss your goal?",
            options: ["Grade drops", "Lose scholarship", "Delay graduation", "Lose job", "Feel behind", "Waste tuition money", "Other"]
        ),
        OnboardingQuestion(
            id: 17,
            question: "If Alan saved you 5 hours a week, what would you do with it?",
            options: ["Sleep", "Gym", "See friends", "Side project", "Job search", "More studying", "Other"],
            allowsMultipleSelection: true
        ),
        OnboardingQuestion(
            id: 18,
            question: "What should Alan call you?",
            options: [],
            requiresTextInput: true
        )
    ]

    static var totalCount: Int {
        all.count
    }
}

// Stores the user's answers to onboarding questions.
class OnboardingAnswers: ObservableObject {
    @Published var answers: [Int: Set<String>] = [:]
    @Published var textInputs: [Int: String] = [:]

    // Record a selected answer for a question.
    func select(_ option: String, for questionId: Int, allowsMultiple: Bool) {
        if allowsMultiple {
            if answers[questionId] == nil {
                answers[questionId] = []
            }
            if answers[questionId]?.contains(option) == true {
                answers[questionId]?.remove(option)
            } else {
                answers[questionId]?.insert(option)
            }
        } else {
            answers[questionId] = [option]
        }
    }

    // Check if an option is selected for a question.
    func isSelected(_ option: String, for questionId: Int) -> Bool {
        answers[questionId]?.contains(option) == true
    }

    // Check if a question has been answered.
    func hasAnswer(for questionId: Int) -> Bool {
        if let textInput = textInputs[questionId], !textInput.isEmpty {
            return true
        }
        return answers[questionId]?.isEmpty == false
    }

    // Set text input for a question.
    func setTextInput(_ text: String, for questionId: Int) {
        textInputs[questionId] = text
    }

    // Get text input for a question.
    func getTextInput(for questionId: Int) -> String {
        textInputs[questionId] ?? ""
    }

    // Persist answers to UserDefaults.
    func save() {
        let encoder = JSONEncoder()

        // Convert Set<String> to Array<String> for encoding
        let answersArray = answers.mapValues { Array($0) }
        if let data = try? encoder.encode(answersArray) {
            UserDefaults.standard.set(data, forKey: "onboarding_answers")
        }
        if let data = try? encoder.encode(textInputs) {
            UserDefaults.standard.set(data, forKey: "onboarding_text_inputs")
        }
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }

    // Load answers from UserDefaults.
    func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "onboarding_answers"),
           let answersArray = try? decoder.decode([Int: [String]].self, from: data) {
            answers = answersArray.mapValues { Set($0) }
        }
        if let data = UserDefaults.standard.data(forKey: "onboarding_text_inputs"),
           let inputs = try? decoder.decode([Int: String].self, from: data) {
            textInputs = inputs
        }
    }

    // Check if onboarding has been completed.
    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "onboarding_completed")
    }

    // Reset onboarding state for testing.
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboarding_answers")
        UserDefaults.standard.removeObject(forKey: "onboarding_text_inputs")
        UserDefaults.standard.removeObject(forKey: "onboarding_completed")
    }
}
