// MathExpressionParserContract.swift
// Defines the API contract for parsing and evaluating mathematical expressions.
// This parser enables the GraphView to evaluate equations at specific points.
// Supports explicit (y=f(x)), parametric (x=f(t),y=g(t)), and polar (r=f(theta)) forms.
// This contract specifies all public interfaces, acceptance criteria, and edge cases
// for test-driven development before implementation begins.

import Foundation

// MARK: - API Contract

// MARK: - MathExpressionToken Enum

// Represents a single token in a parsed mathematical expression.
// Used internally by the parser for tokenization and parsing stages.
enum MathExpressionToken: Sendable, Equatable {
  // A numeric literal (e.g., 3.14, -5, 2.0e10).
  case number(Double)

  // A variable reference (e.g., x, t, theta).
  case variable(String)

  // A mathematical constant (pi, e).
  case constant(MathConstant)

  // A binary operator (+, -, *, /, ^).
  case binaryOperator(MathBinaryOperator)

  // A unary operator (negation).
  case unaryOperator(MathUnaryOperator)

  // A mathematical function (sin, cos, sqrt, etc.).
  case function(MathFunction)

  // Left parenthesis for grouping.
  case leftParen

  // Right parenthesis for grouping.
  case rightParen

  // Comma separator for multi-argument functions.
  case comma
}

/*
 ACCEPTANCE CRITERIA: MathExpressionToken

 SCENARIO: Tokenize numeric literal
 GIVEN: Expression string "3.14159"
 WHEN: Tokenized
 THEN: Single token .number(3.14159) is produced
  AND: Value is stored as Double

 SCENARIO: Tokenize variable
 GIVEN: Expression string "x"
 WHEN: Tokenized
 THEN: Single token .variable("x") is produced
  AND: Variable name is preserved

 SCENARIO: Tokenize constant
 GIVEN: Expression string "pi"
 WHEN: Tokenized
 THEN: Single token .constant(.pi) is produced
  AND: Recognized as mathematical constant

 SCENARIO: Tokenize operator
 GIVEN: Expression string "+"
 WHEN: Tokenized
 THEN: Single token .binaryOperator(.add) is produced

 SCENARIO: Tokenize function
 GIVEN: Expression string "sin"
 WHEN: Tokenized (followed by parenthesis)
 THEN: Single token .function(.sin) is produced
*/

// MARK: - MathConstant Enum

// Mathematical constants supported in expressions.
enum MathConstant: String, Sendable, Equatable, CaseIterable {
  // Pi (approximately 3.14159265358979).
  case pi

  // Euler's number e (approximately 2.71828182845905).
  case e

  // Returns the numeric value of the constant.
  var value: Double {
    switch self {
    case .pi: return Double.pi
    case .e: return M_E
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MathConstant

 SCENARIO: Evaluate pi constant
 GIVEN: MathConstant.pi
 WHEN: value property is accessed
 THEN: Returns Double.pi (3.141592653589793)

 SCENARIO: Evaluate e constant
 GIVEN: MathConstant.e
 WHEN: value property is accessed
 THEN: Returns M_E (2.718281828459045)

 SCENARIO: Case insensitive parsing
 GIVEN: Expression "PI" or "Pi"
 WHEN: Parsed
 THEN: Recognized as MathConstant.pi
  AND: Case normalization handled by parser
*/

// MARK: - MathBinaryOperator Enum

// Binary operators supported in expressions.
// Listed in order of precedence (lowest to highest).
enum MathBinaryOperator: String, Sendable, Equatable {
  // Addition (+).
  case add = "+"

  // Subtraction (-).
  case subtract = "-"

  // Multiplication (*).
  case multiply = "*"

  // Division (/).
  case divide = "/"

  // Exponentiation (^).
  case power = "^"

  // Operator precedence level for parsing.
  // Higher values bind tighter.
  var precedence: Int {
    switch self {
    case .add, .subtract: return 1
    case .multiply, .divide: return 2
    case .power: return 3
    }
  }

  // Associativity for operators of same precedence.
  var isRightAssociative: Bool {
    switch self {
    case .power: return true
    default: return false
    }
  }

  // Evaluates the operator with two operands.
  func evaluate(left: Double, right: Double) -> Double {
    switch self {
    case .add: return left + right
    case .subtract: return left - right
    case .multiply: return left * right
    case .divide: return left / right
    case .power: return pow(left, right)
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MathBinaryOperator

 SCENARIO: Evaluate addition
 GIVEN: MathBinaryOperator.add
 WHEN: evaluate(left: 3, right: 5) is called
 THEN: Returns 8.0

 SCENARIO: Evaluate subtraction
 GIVEN: MathBinaryOperator.subtract
 WHEN: evaluate(left: 10, right: 4) is called
 THEN: Returns 6.0

 SCENARIO: Evaluate multiplication
 GIVEN: MathBinaryOperator.multiply
 WHEN: evaluate(left: 6, right: 7) is called
 THEN: Returns 42.0

 SCENARIO: Evaluate division
 GIVEN: MathBinaryOperator.divide
 WHEN: evaluate(left: 15, right: 3) is called
 THEN: Returns 5.0

 SCENARIO: Evaluate power
 GIVEN: MathBinaryOperator.power
 WHEN: evaluate(left: 2, right: 10) is called
 THEN: Returns 1024.0

 SCENARIO: Operator precedence order
 GIVEN: Operators +, -, *, /, ^
 WHEN: Precedence is compared
 THEN: + and - have lowest (1)
  AND: * and / have middle (2)
  AND: ^ has highest (3)

 SCENARIO: Power is right associative
 GIVEN: Expression "2^3^2"
 WHEN: Parsed with associativity rules
 THEN: Evaluates as 2^(3^2) = 2^9 = 512
  AND: Not (2^3)^2 = 8^2 = 64

 EDGE CASE: Division by zero
 GIVEN: MathBinaryOperator.divide
 WHEN: evaluate(left: 5, right: 0) is called
 THEN: Returns Double.infinity
  AND: Consistent with IEEE 754

 EDGE CASE: Zero to negative power
 GIVEN: MathBinaryOperator.power
 WHEN: evaluate(left: 0, right: -1) is called
 THEN: Returns Double.infinity
*/

// MARK: - MathUnaryOperator Enum

// Unary operators supported in expressions.
enum MathUnaryOperator: String, Sendable, Equatable {
  // Unary negation (-x).
  case negate = "-"

  // Unary plus (+x, identity).
  case plus = "+"

  // Evaluates the operator with one operand.
  func evaluate(operand: Double) -> Double {
    switch self {
    case .negate: return -operand
    case .plus: return operand
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MathUnaryOperator

 SCENARIO: Evaluate negation
 GIVEN: MathUnaryOperator.negate
 WHEN: evaluate(operand: 5) is called
 THEN: Returns -5.0

 SCENARIO: Evaluate unary plus
 GIVEN: MathUnaryOperator.plus
 WHEN: evaluate(operand: 5) is called
 THEN: Returns 5.0

 SCENARIO: Double negation
 GIVEN: Expression "--x" with x = 3
 WHEN: Evaluated
 THEN: Returns 3.0 (negation of negation)
*/

// MARK: - MathFunction Enum

// Mathematical functions supported in expressions.
enum MathFunction: String, Sendable, Equatable, CaseIterable {
  // Trigonometric functions.
  case sin
  case cos
  case tan
  case asin
  case acos
  case atan

  // Hyperbolic functions.
  case sinh
  case cosh
  case tanh

  // Square root.
  case sqrt

  // Absolute value.
  case abs

  // Natural logarithm (base e).
  case ln

  // Common logarithm (base 10).
  case log

  // Logarithm base 2.
  case log2

  // Exponential function e^x.
  case exp

  // Floor function (round down).
  case floor

  // Ceiling function (round up).
  case ceil

  // Sign function (-1, 0, or 1).
  case sign

  // Number of arguments this function takes.
  var argumentCount: Int {
    return 1  // All current functions are unary.
  }

  // Evaluates the function with given arguments.
  // Returns .nan for invalid inputs (e.g., sqrt of negative).
  func evaluate(arguments: [Double]) -> Double {
    guard arguments.count == argumentCount else { return .nan }
    let x = arguments[0]
    switch self {
    case .sin: return Foundation.sin(x)
    case .cos: return Foundation.cos(x)
    case .tan: return Foundation.tan(x)
    case .asin: return Foundation.asin(x)
    case .acos: return Foundation.acos(x)
    case .atan: return Foundation.atan(x)
    case .sinh: return Foundation.sinh(x)
    case .cosh: return Foundation.cosh(x)
    case .tanh: return Foundation.tanh(x)
    case .sqrt: return Foundation.sqrt(x)
    case .abs: return Swift.abs(x)
    case .ln: return Foundation.log(x)
    case .log: return Foundation.log10(x)
    case .log2: return Foundation.log2(x)
    case .exp: return Foundation.exp(x)
    case .floor: return Foundation.floor(x)
    case .ceil: return Foundation.ceil(x)
    case .sign: return x > 0 ? 1.0 : (x < 0 ? -1.0 : 0.0)
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MathFunction

 SCENARIO: Evaluate sin function
 GIVEN: MathFunction.sin
 WHEN: evaluate(arguments: [Double.pi / 2]) is called
 THEN: Returns 1.0 (approximately)

 SCENARIO: Evaluate cos function
 GIVEN: MathFunction.cos
 WHEN: evaluate(arguments: [0]) is called
 THEN: Returns 1.0

 SCENARIO: Evaluate tan function
 GIVEN: MathFunction.tan
 WHEN: evaluate(arguments: [Double.pi / 4]) is called
 THEN: Returns 1.0 (approximately)

 SCENARIO: Evaluate sqrt function
 GIVEN: MathFunction.sqrt
 WHEN: evaluate(arguments: [16]) is called
 THEN: Returns 4.0

 SCENARIO: Evaluate abs function
 GIVEN: MathFunction.abs
 WHEN: evaluate(arguments: [-7.5]) is called
 THEN: Returns 7.5

 SCENARIO: Evaluate ln function
 GIVEN: MathFunction.ln
 WHEN: evaluate(arguments: [M_E]) is called
 THEN: Returns 1.0

 SCENARIO: Evaluate log function (base 10)
 GIVEN: MathFunction.log
 WHEN: evaluate(arguments: [100]) is called
 THEN: Returns 2.0

 SCENARIO: Evaluate exp function
 GIVEN: MathFunction.exp
 WHEN: evaluate(arguments: [1]) is called
 THEN: Returns M_E (approximately 2.718)

 SCENARIO: Evaluate floor function
 GIVEN: MathFunction.floor
 WHEN: evaluate(arguments: [3.7]) is called
 THEN: Returns 3.0

 SCENARIO: Evaluate ceil function
 GIVEN: MathFunction.ceil
 WHEN: evaluate(arguments: [3.2]) is called
 THEN: Returns 4.0

 SCENARIO: Evaluate sign function
 GIVEN: MathFunction.sign
 WHEN: evaluate(arguments: [-5]) is called
 THEN: Returns -1.0

 EDGE CASE: sqrt of negative number
 GIVEN: MathFunction.sqrt
 WHEN: evaluate(arguments: [-4]) is called
 THEN: Returns .nan
  AND: Indicates invalid input for real numbers

 EDGE CASE: ln of zero
 GIVEN: MathFunction.ln
 WHEN: evaluate(arguments: [0]) is called
 THEN: Returns -.infinity
  AND: Consistent with mathematical limit

 EDGE CASE: ln of negative number
 GIVEN: MathFunction.ln
 WHEN: evaluate(arguments: [-1]) is called
 THEN: Returns .nan
  AND: Not defined for real numbers

 EDGE CASE: asin out of domain
 GIVEN: MathFunction.asin
 WHEN: evaluate(arguments: [2]) is called
 THEN: Returns .nan
  AND: Domain is [-1, 1]

 EDGE CASE: tan at pi/2
 GIVEN: MathFunction.tan
 WHEN: evaluate(arguments: [Double.pi / 2]) is called
 THEN: Returns very large value (approaching infinity)
  AND: Due to floating point, not exactly infinity

 EDGE CASE: Wrong argument count
 GIVEN: MathFunction.sin
 WHEN: evaluate(arguments: [1, 2]) is called
 THEN: Returns .nan
  AND: Expected 1 argument, received 2
*/

// MARK: - ParsedExpression Protocol

// Protocol for a parsed mathematical expression that can be evaluated.
// Returned by MathExpressionParser after successful parsing.
protocol ParsedExpressionProtocol: Sendable {
  // Evaluates the expression with given variable values.
  // variables: Dictionary mapping variable names to their values.
  // Returns the computed result, which may be .nan or .infinity for edge cases.
  func evaluate(with variables: [String: Double]) -> Double

  // Set of variable names used in this expression.
  // Used to validate that all required variables are provided.
  var variables: Set<String> { get }

  // Original expression string that was parsed.
  var originalExpression: String { get }

  // Whether this expression is constant (no variables).
  var isConstant: Bool { get }
}

/*
 ACCEPTANCE CRITERIA: ParsedExpressionProtocol

 SCENARIO: Evaluate expression with variable
 GIVEN: ParsedExpression for "x^2 + 1"
 WHEN: evaluate(with: ["x": 3]) is called
 THEN: Returns 10.0

 SCENARIO: Evaluate expression with multiple variables
 GIVEN: ParsedExpression for "x * y + z"
 WHEN: evaluate(with: ["x": 2, "y": 3, "z": 4]) is called
 THEN: Returns 10.0

 SCENARIO: Get variable set
 GIVEN: ParsedExpression for "x^2 + 2*x + 1"
 WHEN: variables property is accessed
 THEN: Returns Set containing "x"
  AND: No duplicates

 SCENARIO: Get variables for parametric
 GIVEN: ParsedExpression for "sin(t) + cos(t)"
 WHEN: variables property is accessed
 THEN: Returns Set containing "t"

 SCENARIO: Constant expression
 GIVEN: ParsedExpression for "2 * pi"
 WHEN: variables property is accessed
 THEN: Returns empty Set
  AND: isConstant returns true

 SCENARIO: Preserve original expression
 GIVEN: ParsedExpression for "x^2"
 WHEN: originalExpression property is accessed
 THEN: Returns "x^2"

 EDGE CASE: Missing variable during evaluation
 GIVEN: ParsedExpression for "x + y"
 WHEN: evaluate(with: ["x": 1]) is called (missing y)
 THEN: Returns .nan
  AND: Missing variable causes undefined result

 EDGE CASE: Extra variables provided
 GIVEN: ParsedExpression for "x + 1"
 WHEN: evaluate(with: ["x": 5, "y": 10, "z": 15]) is called
 THEN: Returns 6.0
  AND: Extra variables are ignored

 EDGE CASE: Case sensitivity of variables
 GIVEN: ParsedExpression for "X + x"
 WHEN: variables property is accessed
 THEN: Contains both "X" and "x" (case sensitive)
*/

// MARK: - MathExpressionParser Protocol

// Protocol for parsing mathematical expression strings into evaluable form.
protocol MathExpressionParserProtocol: Sendable {
  // Parses an expression string into a ParsedExpression.
  // expression: The mathematical expression string to parse.
  // Returns: A ParsedExpression that can be evaluated.
  // Throws: MathExpressionError if parsing fails.
  func parse(_ expression: String) throws -> any ParsedExpressionProtocol
}

/*
 ACCEPTANCE CRITERIA: MathExpressionParserProtocol

 SCENARIO: Parse simple expression
 GIVEN: Expression string "x + 1"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5]) returns 6.0

 SCENARIO: Parse expression with operators
 GIVEN: Expression string "x^2 + 2*x + 1"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: Respects operator precedence
  AND: evaluate(with: ["x": 3]) returns 16.0

 SCENARIO: Parse expression with function
 GIVEN: Expression string "sin(x)"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 0]) returns 0.0

 SCENARIO: Parse expression with nested functions
 GIVEN: Expression string "sqrt(abs(x))"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": -16]) returns 4.0

 SCENARIO: Parse expression with parentheses
 GIVEN: Expression string "(x + 1) * (x - 1)"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5]) returns 24.0

 SCENARIO: Parse expression with constants
 GIVEN: Expression string "2 * pi"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: [:]) returns approximately 6.283

 SCENARIO: Parse expression with theta
 GIVEN: Expression string "1 + cos(theta)"
 WHEN: parse() is called
 THEN: Returns ParsedExpression with variable "theta"
  AND: evaluate(with: ["theta": 0]) returns 2.0

 SCENARIO: Parse expression with implicit multiplication
 GIVEN: Expression string "2x" or "2(x+1)"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: Implicit multiplication is recognized
  AND: "2x" with x=3 returns 6.0

 SCENARIO: Parse expression with unary minus
 GIVEN: Expression string "-x^2"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 3]) returns -9.0
  AND: Unary minus binds correctly

 SCENARIO: Parse expression with scientific notation
 GIVEN: Expression string "1.5e-3 * x"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 1000]) returns 1.5

 EDGE CASE: Empty expression
 GIVEN: Expression string ""
 WHEN: parse() is called
 THEN: Throws MathExpressionError.emptyExpression

 EDGE CASE: Whitespace only expression
 GIVEN: Expression string "   "
 WHEN: parse() is called
 THEN: Throws MathExpressionError.emptyExpression

 EDGE CASE: Invalid syntax - unmatched parenthesis
 GIVEN: Expression string "(x + 1"
 WHEN: parse() is called
 THEN: Throws MathExpressionError.unmatchedParenthesis

 EDGE CASE: Invalid syntax - missing operand
 GIVEN: Expression string "x + "
 WHEN: parse() is called
 THEN: Throws MathExpressionError.unexpectedEndOfExpression

 EDGE CASE: Invalid syntax - consecutive operators
 GIVEN: Expression string "x + + y"
 WHEN: parse() is called
 THEN: Throws MathExpressionError.unexpectedToken
  AND: Second + is unexpected

 EDGE CASE: Unknown function
 GIVEN: Expression string "foo(x)"
 WHEN: parse() is called
 THEN: Throws MathExpressionError.unknownFunction("foo")

 EDGE CASE: Unknown character
 GIVEN: Expression string "x @ y"
 WHEN: parse() is called
 THEN: Throws MathExpressionError.unexpectedCharacter("@")

 EDGE CASE: Division expression
 GIVEN: Expression string "1/x"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 0]) returns .infinity
  AND: evaluate(with: ["x": 2]) returns 0.5

 EDGE CASE: Very long expression
 GIVEN: Expression string with 1000 terms
 WHEN: parse() is called
 THEN: Parsing succeeds (or throws length limit error)
  AND: No stack overflow

 EDGE CASE: Deeply nested parentheses
 GIVEN: Expression string "((((((x))))))"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5]) returns 5.0

 EDGE CASE: Expression with all supported functions
 GIVEN: Expression "sin(x) + cos(x) + tan(x) + sqrt(x) + abs(x) + ln(x) + exp(x)"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: All functions are recognized

 EDGE CASE: Multiple minus signs
 GIVEN: Expression string "x--y" (x minus negative y)
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5, "y": 3]) returns 8.0

 EDGE CASE: Expression starting with plus
 GIVEN: Expression string "+x"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5]) returns 5.0

 EDGE CASE: Decimal number without leading digit
 GIVEN: Expression string ".5 * x"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 4]) returns 2.0
*/

// MARK: - MathExpressionError Enum

// Errors that can occur during expression parsing.
enum MathExpressionError: Error, LocalizedError, Equatable, Sendable {
  // The expression string was empty or whitespace only.
  case emptyExpression

  // An unexpected character was encountered.
  case unexpectedCharacter(character: String, position: Int)

  // A token was found in an unexpected position.
  case unexpectedToken(token: String, position: Int)

  // Opening parenthesis without matching close.
  case unmatchedParenthesis(position: Int)

  // Expression ended unexpectedly (e.g., trailing operator).
  case unexpectedEndOfExpression

  // Unknown function name was used.
  case unknownFunction(name: String)

  // Wrong number of arguments provided to function.
  case wrongArgumentCount(function: String, expected: Int, received: Int)

  // Expression exceeds maximum allowed complexity.
  case expressionTooComplex(reason: String)

  // Invalid number format in expression.
  case invalidNumber(text: String, position: Int)

  var errorDescription: String? {
    switch self {
    case .emptyExpression:
      return "Expression is empty"
    case .unexpectedCharacter(let character, let position):
      return "Unexpected character '\(character)' at position \(position)"
    case .unexpectedToken(let token, let position):
      return "Unexpected token '\(token)' at position \(position)"
    case .unmatchedParenthesis(let position):
      return "Unmatched parenthesis at position \(position)"
    case .unexpectedEndOfExpression:
      return "Expression ended unexpectedly"
    case .unknownFunction(let name):
      return "Unknown function: \(name)"
    case .wrongArgumentCount(let function, let expected, let received):
      return "Function '\(function)' expects \(expected) arguments, received \(received)"
    case .expressionTooComplex(let reason):
      return "Expression too complex: \(reason)"
    case .invalidNumber(let text, let position):
      return "Invalid number '\(text)' at position \(position)"
    }
  }
}

/*
 ACCEPTANCE CRITERIA: MathExpressionError

 SCENARIO: Empty expression error
 GIVEN: parse("") is called
 WHEN: Parser detects empty input
 THEN: MathExpressionError.emptyExpression is thrown
  AND: Error message explains the issue

 SCENARIO: Unexpected character error
 GIVEN: parse("x @ y") is called
 WHEN: Parser encounters '@'
 THEN: MathExpressionError.unexpectedCharacter("@", position) is thrown
  AND: Position indicates where '@' was found

 SCENARIO: Unmatched parenthesis error
 GIVEN: parse("(x + 1") is called
 WHEN: Parser reaches end without closing paren
 THEN: MathExpressionError.unmatchedParenthesis is thrown
  AND: Position indicates the opening paren

 SCENARIO: Unknown function error
 GIVEN: parse("foobar(x)") is called
 WHEN: Parser encounters unknown function name
 THEN: MathExpressionError.unknownFunction("foobar") is thrown
  AND: Function name is included in error

 SCENARIO: Error equatable comparison
 GIVEN: Two MathExpressionError values
 WHEN: Compared for equality
 THEN: Same error type with same values returns true
  AND: Different types or values return false
*/

// MARK: - MathExpressionParserConfiguration Struct

// Configuration options for the math expression parser.
struct MathExpressionParserConfiguration: Sendable, Equatable {
  // Whether to allow implicit multiplication (e.g., "2x" = "2*x").
  let allowImplicitMultiplication: Bool

  // Whether variable names are case sensitive.
  let caseSensitiveVariables: Bool

  // Whether function names are case sensitive.
  let caseSensitiveFunctions: Bool

  // Maximum expression length in characters.
  let maxExpressionLength: Int

  // Maximum nesting depth for parentheses.
  let maxNestingDepth: Int

  // Default configuration for standard math expressions.
  static let `default` = MathExpressionParserConfiguration(
    allowImplicitMultiplication: true,
    caseSensitiveVariables: true,
    caseSensitiveFunctions: false,
    maxExpressionLength: 10000,
    maxNestingDepth: 100
  )

  // Strict configuration with no implicit features.
  static let strict = MathExpressionParserConfiguration(
    allowImplicitMultiplication: false,
    caseSensitiveVariables: true,
    caseSensitiveFunctions: true,
    maxExpressionLength: 10000,
    maxNestingDepth: 100
  )
}

/*
 ACCEPTANCE CRITERIA: MathExpressionParserConfiguration

 SCENARIO: Default allows implicit multiplication
 GIVEN: MathExpressionParserConfiguration.default
 WHEN: Parser parses "2x"
 THEN: Interpreted as "2*x"
  AND: Returns ParsedExpression

 SCENARIO: Strict rejects implicit multiplication
 GIVEN: MathExpressionParserConfiguration.strict
 WHEN: Parser parses "2x"
 THEN: Throws error (unexpected token after number)

 SCENARIO: Case insensitive functions
 GIVEN: Configuration with caseSensitiveFunctions = false
 WHEN: Parser parses "SIN(x)"
 THEN: Recognized as sin function
  AND: Returns ParsedExpression

 SCENARIO: Max nesting depth enforced
 GIVEN: Configuration with maxNestingDepth = 10
 WHEN: Parser parses expression with 15 nested parens
 THEN: Throws MathExpressionError.expressionTooComplex

 SCENARIO: Max expression length enforced
 GIVEN: Configuration with maxExpressionLength = 100
 WHEN: Parser parses expression of 200 characters
 THEN: Throws MathExpressionError.expressionTooComplex
*/

// MARK: - Constants

// Constants for math expression parsing.
enum MathExpressionConstants {
  // Reserved variable names for different equation types.
  static let explicitVariables: Set<String> = ["x"]
  static let parametricVariables: Set<String> = ["t"]
  static let polarVariables: Set<String> = ["theta"]

  // All supported variable names.
  static let allVariables: Set<String> = ["x", "y", "t", "theta", "r"]

  // Maximum recommended samples for curve evaluation.
  static let defaultSampleCount: Int = 500

  // Epsilon for floating point comparisons.
  static let epsilon: Double = 1e-10

  // Threshold for detecting discontinuities (ratio of consecutive values).
  static let discontinuityThreshold: Double = 1000.0
}

/*
 ACCEPTANCE CRITERIA: MathExpressionConstants

 SCENARIO: Explicit equation variables
 GIVEN: MathExpressionConstants.explicitVariables
 WHEN: Accessed
 THEN: Contains "x"
  AND: Used for y = f(x) equations

 SCENARIO: Parametric equation variables
 GIVEN: MathExpressionConstants.parametricVariables
 WHEN: Accessed
 THEN: Contains "t"
  AND: Used for x = f(t), y = g(t) equations

 SCENARIO: Polar equation variables
 GIVEN: MathExpressionConstants.polarVariables
 WHEN: Accessed
 THEN: Contains "theta"
  AND: Used for r = f(theta) equations
*/

// MARK: - Edge Cases & Error Conditions

/*
 EDGE CASE: Infinity in expression result
 GIVEN: Expression "1/x"
 WHEN: evaluate(with: ["x": 0]) is called
 THEN: Returns Double.infinity (positive)
  AND: Graphing code handles infinity for asymptotes

 EDGE CASE: Negative infinity
 GIVEN: Expression "-1/x"
 WHEN: evaluate(with: ["x": 0.0000001]) approaches 0 from right
 THEN: Returns large negative value
  AND: As x approaches 0 from right: -.infinity

 EDGE CASE: NaN propagation
 GIVEN: Expression "sqrt(x) + 1"
 WHEN: evaluate(with: ["x": -1]) is called
 THEN: Returns .nan
  AND: NaN propagates through operations

 EDGE CASE: Indeterminate form 0/0
 GIVEN: Expression "(x^2 - 1)/(x - 1)" at x = 1
 WHEN: evaluate(with: ["x": 1]) is called
 THEN: Returns .nan (0/0 is indeterminate)
  AND: Renderer can handle with limit analysis

 EDGE CASE: Very large exponent
 GIVEN: Expression "x^1000"
 WHEN: evaluate(with: ["x": 2]) is called
 THEN: Returns large but finite result or .infinity
  AND: No crash from overflow

 EDGE CASE: Very small numbers
 GIVEN: Expression "x^(-1000)"
 WHEN: evaluate(with: ["x": 2]) is called
 THEN: Returns very small positive number or 0 (underflow)
  AND: Handled gracefully

 EDGE CASE: Unicode in variable names
 GIVEN: Expression with Greek letter variable
 WHEN: Parser encounters "theta" or actual Greek theta
 THEN: Handled consistently
  AND: "theta" is standard representation

 EDGE CASE: Whitespace handling
 GIVEN: Expression "  x   +   1  "
 WHEN: parse() is called
 THEN: Whitespace is ignored
  AND: Returns same result as "x+1"

 EDGE CASE: Consecutive unary operators
 GIVEN: Expression "---x"
 WHEN: parse() is called
 THEN: Returns ParsedExpression
  AND: evaluate(with: ["x": 5]) returns -5.0

 EDGE CASE: Function without parentheses
 GIVEN: Expression "sin x"
 WHEN: parse() is called
 THEN: Throws error (function requires parentheses)
  AND: Clear error message

 EDGE CASE: Empty function call
 GIVEN: Expression "sin()"
 WHEN: parse() is called
 THEN: Throws MathExpressionError.wrongArgumentCount
  AND: Expected 1, received 0

 EDGE CASE: Exponent with negative base
 GIVEN: Expression "(-2)^0.5"
 WHEN: evaluate(with: [:]) is called
 THEN: Returns .nan
  AND: Complex result not supported

 EDGE CASE: Zero to zero power
 GIVEN: Expression "x^x"
 WHEN: evaluate(with: ["x": 0]) is called
 THEN: Returns .nan or 1.0 (mathematically debated)
  AND: Consistent behavior defined

 EDGE CASE: Trigonometric function of large angle
 GIVEN: Expression "sin(x)"
 WHEN: evaluate(with: ["x": 1e10]) is called
 THEN: Returns value in [-1, 1]
  AND: Precision may be reduced for very large angles

 EDGE CASE: log of very small positive number
 GIVEN: Expression "ln(x)"
 WHEN: evaluate(with: ["x": 1e-300]) is called
 THEN: Returns large negative value
  AND: Approximately -690.7755
*/

// MARK: - Integration Points

/*
 INTEGRATION: GraphEquation
 MathExpressionParser is used to parse GraphEquation.expression fields.
 For explicit: parse expression with variable "x"
 For parametric: parse xExpression and yExpression with variable "t"
 For polar: parse rExpression with variable "theta"

 INTEGRATION: EquationRenderer
 ParsedExpression is used by EquationRenderer to sample points.
 For each sample point, evaluate() is called with appropriate variables.
 Results are used to construct CGPath for rendering.

 INTEGRATION: GraphViewModel
 Parser errors are surfaced through GraphViewModel to UI.
 Failed equations show error state rather than crashing.

 INTEGRATION: Error Handling
 MathExpressionError should be wrapped in GraphSpecificationError.invalidExpression
 when equation validation fails during specification processing.
*/
