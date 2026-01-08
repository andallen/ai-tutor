// MathExpressionParser.swift
// Implementation of the math expression parser for evaluating mathematical expressions.
// Uses a recursive descent parser with shunting-yard algorithm for operator precedence.

import Foundation

// MARK: - ParsedExpression

// Concrete implementation of ParsedExpressionProtocol.
// Holds a syntax tree representation of the parsed expression.
struct ParsedExpression: ParsedExpressionProtocol, Sendable {
  let variables: Set<String>
  let originalExpression: String
  let isConstant: Bool
  private let rootNode: ExpressionNode

  init(rootNode: ExpressionNode, originalExpression: String) {
    self.rootNode = rootNode
    self.originalExpression = originalExpression
    self.variables = rootNode.collectVariables()
    self.isConstant = variables.isEmpty
  }

  func evaluate(with variables: [String: Double]) -> Double {
    return rootNode.evaluate(with: variables)
  }
}

// MARK: - ExpressionNode

// Abstract syntax tree node for a parsed expression.
// Each node type represents a different kind of expression component.
enum ExpressionNode: Sendable {
  // A numeric literal value.
  case number(Double)

  // A variable reference.
  case variable(String)

  // A constant value (pi, e).
  case constant(MathConstant)

  // A binary operation (left op right).
  indirect case binary(left: ExpressionNode, op: MathBinaryOperator, right: ExpressionNode)

  // A unary operation (op operand).
  indirect case unary(op: MathUnaryOperator, operand: ExpressionNode)

  // A function call (func(arg)).
  indirect case function(MathFunction, argument: ExpressionNode)

  // Evaluates the node with the given variable values.
  func evaluate(with variables: [String: Double]) -> Double {
    switch self {
    case .number(let value):
      return value

    case .variable(let name):
      guard let value = variables[name] else {
        return .nan
      }
      return value

    case .constant(let constant):
      return constant.value

    case .binary(let left, let op, let right):
      let leftValue = left.evaluate(with: variables)
      let rightValue = right.evaluate(with: variables)
      return op.evaluate(left: leftValue, right: rightValue)

    case .unary(let op, let operand):
      let operandValue = operand.evaluate(with: variables)
      return op.evaluate(operand: operandValue)

    case .function(let function, let argument):
      let argValue = argument.evaluate(with: variables)
      return function.evaluate(arguments: [argValue])
    }
  }

  // Collects all variable names used in this node and its children.
  func collectVariables() -> Set<String> {
    switch self {
    case .number, .constant:
      return []

    case .variable(let name):
      return [name]

    case .binary(let left, _, let right):
      return left.collectVariables().union(right.collectVariables())

    case .unary(_, let operand):
      return operand.collectVariables()

    case .function(_, let argument):
      return argument.collectVariables()
    }
  }
}

// MARK: - MathExpressionParser

// Parses mathematical expression strings into evaluable ParsedExpression objects.
// Uses a tokenizer followed by a recursive descent parser with precedence climbing.
final class MathExpressionParser: MathExpressionParserProtocol, @unchecked Sendable {
  private let configuration: MathExpressionParserConfiguration

  init(configuration: MathExpressionParserConfiguration = .default) {
    self.configuration = configuration
  }

  func parse(_ expression: String) throws -> any ParsedExpressionProtocol {
    // Check expression length limit.
    guard expression.count <= configuration.maxExpressionLength else {
      throw MathExpressionError.expressionTooComplex(
        reason: "Expression exceeds maximum length of \(configuration.maxExpressionLength)")
    }

    // Trim whitespace and check for empty expression.
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      throw MathExpressionError.emptyExpression
    }

    // Tokenize the expression.
    var tokenizer = Tokenizer(
      expression: trimmed,
      configuration: configuration
    )
    let tokens = try tokenizer.tokenize()

    // Parse the tokens into an AST.
    var parser = TokenParser(
      tokens: tokens,
      configuration: configuration
    )
    let rootNode = try parser.parseExpression()

    // Check that all tokens were consumed.
    if parser.currentIndex < tokens.count {
      let remainingToken = tokens[parser.currentIndex]
      throw MathExpressionError.unexpectedToken(
        token: describeToken(remainingToken),
        position: parser.currentIndex
      )
    }

    return ParsedExpression(rootNode: rootNode, originalExpression: expression)
  }

  // Returns a string description of a token for error messages.
  private func describeToken(_ token: MathExpressionToken) -> String {
    switch token {
    case .number(let value): return String(value)
    case .variable(let name): return name
    case .constant(let constant): return constant.rawValue
    case .binaryOperator(let op): return op.rawValue
    case .unaryOperator(let op): return op.rawValue
    case .function(let fn): return fn.rawValue
    case .leftParen: return "("
    case .rightParen: return ")"
    case .comma: return ","
    }
  }
}

// MARK: - Tokenizer

// Tokenizes a mathematical expression string into tokens.
private struct Tokenizer {
  private let expression: String
  private let characters: [Character]
  private var currentIndex: Int = 0
  private let configuration: MathExpressionParserConfiguration

  init(expression: String, configuration: MathExpressionParserConfiguration) {
    self.expression = expression
    self.characters = Array(expression)
    self.configuration = configuration
  }

  mutating func tokenize() throws -> [MathExpressionToken] {
    var tokens: [MathExpressionToken] = []
    var parenDepth = 0

    while currentIndex < characters.count {
      skipWhitespace()
      guard currentIndex < characters.count else { break }

      let char = characters[currentIndex]

      // Numbers (including those starting with decimal point).
      if char.isNumber || char == "." {
        let number = try readNumber()
        tokens.append(.number(number))

        // Check for implicit multiplication before variable or function.
        if configuration.allowImplicitMultiplication {
          skipWhitespace()
          if currentIndex < characters.count {
            let nextChar = characters[currentIndex]
            if nextChar.isLetter || nextChar == "(" {
              tokens.append(.binaryOperator(.multiply))
            }
          }
        }
        continue
      }

      // Identifiers (variables, functions, constants).
      if char.isLetter {
        let identifier = readIdentifier()

        // Check if it's a constant.
        if let constant = parseConstant(identifier) {
          tokens.append(.constant(constant))

          // Check for implicit multiplication.
          if configuration.allowImplicitMultiplication {
            skipWhitespace()
            if currentIndex < characters.count {
              let nextChar = characters[currentIndex]
              if nextChar.isLetter || nextChar.isNumber || nextChar == "(" {
                tokens.append(.binaryOperator(.multiply))
              }
            }
          }
          continue
        }

        // Check if it's a function (followed by parenthesis).
        skipWhitespace()
        if currentIndex < characters.count && characters[currentIndex] == "(" {
          if let function = parseFunction(identifier) {
            tokens.append(.function(function))
          } else {
            throw MathExpressionError.unknownFunction(name: identifier)
          }
        } else {
          // It's a variable.
          tokens.append(.variable(identifier))

          // Check for implicit multiplication after variable.
          if configuration.allowImplicitMultiplication {
            skipWhitespace()
            if currentIndex < characters.count {
              let nextChar = characters[currentIndex]
              if nextChar.isNumber || nextChar == "(" {
                tokens.append(.binaryOperator(.multiply))
              }
            }
          }
        }
        continue
      }

      // Operators and punctuation.
      switch char {
      case "+":
        // Determine if unary or binary.
        if shouldBeUnaryOperator(tokens) {
          tokens.append(.unaryOperator(.plus))
        } else {
          tokens.append(.binaryOperator(.add))
        }
        currentIndex += 1

      case "-":
        // Determine if unary or binary.
        if shouldBeUnaryOperator(tokens) {
          tokens.append(.unaryOperator(.negate))
        } else {
          tokens.append(.binaryOperator(.subtract))
        }
        currentIndex += 1

      case "*":
        tokens.append(.binaryOperator(.multiply))
        currentIndex += 1

      case "/":
        tokens.append(.binaryOperator(.divide))
        currentIndex += 1

      case "^":
        tokens.append(.binaryOperator(.power))
        currentIndex += 1

      case "(":
        parenDepth += 1
        if parenDepth > configuration.maxNestingDepth {
          throw MathExpressionError.expressionTooComplex(
            reason: "Nesting depth exceeds maximum of \(configuration.maxNestingDepth)")
        }
        tokens.append(.leftParen)
        currentIndex += 1

      case ")":
        if parenDepth == 0 {
          throw MathExpressionError.unmatchedParenthesis(position: currentIndex)
        }
        parenDepth -= 1
        tokens.append(.rightParen)
        currentIndex += 1

        // Check for implicit multiplication after closing paren.
        if configuration.allowImplicitMultiplication {
          skipWhitespace()
          if currentIndex < characters.count {
            let nextChar = characters[currentIndex]
            if nextChar.isLetter || nextChar.isNumber || nextChar == "(" {
              tokens.append(.binaryOperator(.multiply))
            }
          }
        }

      case ",":
        tokens.append(.comma)
        currentIndex += 1

      default:
        throw MathExpressionError.unexpectedCharacter(
          character: String(char),
          position: currentIndex
        )
      }
    }

    // Check for unmatched opening parenthesis.
    if parenDepth > 0 {
      throw MathExpressionError.unmatchedParenthesis(position: findLastOpenParen(tokens))
    }

    return tokens
  }

  // Determines if the next +/- should be treated as unary.
  private func shouldBeUnaryOperator(_ tokens: [MathExpressionToken]) -> Bool {
    guard let lastToken = tokens.last else { return true }
    switch lastToken {
    case .number, .variable, .constant, .rightParen:
      return false
    default:
      return true
    }
  }

  // Finds the position of the last unmatched opening parenthesis.
  private func findLastOpenParen(_ tokens: [MathExpressionToken]) -> Int {
    var depth = 0
    var lastOpenPos = 0
    for (index, token) in tokens.enumerated() {
      switch token {
      case .leftParen:
        depth += 1
        lastOpenPos = index
      case .rightParen:
        depth -= 1
      default:
        break
      }
    }
    return lastOpenPos
  }

  // Skips whitespace characters.
  private mutating func skipWhitespace() {
    while currentIndex < characters.count && characters[currentIndex].isWhitespace {
      currentIndex += 1
    }
  }

  // Reads a numeric literal (including decimals and scientific notation).
  private mutating func readNumber() throws -> Double {
    let startIndex = currentIndex
    var hasDecimal = false

    // Handle leading decimal point.
    if currentIndex < characters.count && characters[currentIndex] == "." {
      hasDecimal = true
      currentIndex += 1
    }

    // Read integer part.
    while currentIndex < characters.count && characters[currentIndex].isNumber {
      currentIndex += 1
    }

    // Read decimal part.
    if !hasDecimal && currentIndex < characters.count && characters[currentIndex] == "." {
      hasDecimal = true
      currentIndex += 1
      while currentIndex < characters.count && characters[currentIndex].isNumber {
        currentIndex += 1
      }
    }

    // Read exponent part.
    if currentIndex < characters.count && (characters[currentIndex] == "e" || characters[currentIndex] == "E") {
      currentIndex += 1

      // Handle exponent sign.
      if currentIndex < characters.count && (characters[currentIndex] == "+" || characters[currentIndex] == "-") {
        currentIndex += 1
      }

      // Exponent digits.
      let expStart = currentIndex
      while currentIndex < characters.count && characters[currentIndex].isNumber {
        currentIndex += 1
      }

      if currentIndex == expStart {
        throw MathExpressionError.invalidNumber(
          text: String(characters[startIndex..<currentIndex]),
          position: startIndex
        )
      }
    }

    let numberString = String(characters[startIndex..<currentIndex])
    guard let value = Double(numberString) else {
      throw MathExpressionError.invalidNumber(text: numberString, position: startIndex)
    }

    return value
  }

  // Reads an identifier (variable name, function name, or constant name).
  private mutating func readIdentifier() -> String {
    let startIndex = currentIndex

    while currentIndex < characters.count {
      let char = characters[currentIndex]
      if char.isLetter || char.isNumber || char == "_" {
        currentIndex += 1
      } else {
        break
      }
    }

    return String(characters[startIndex..<currentIndex])
  }

  // Parses a constant name (case insensitive).
  private func parseConstant(_ name: String) -> MathConstant? {
    let lowercased = name.lowercased()
    return MathConstant(rawValue: lowercased)
  }

  // Parses a function name (case insensitive by default).
  private func parseFunction(_ name: String) -> MathFunction? {
    let normalized = configuration.caseSensitiveFunctions ? name : name.lowercased()
    return MathFunction(rawValue: normalized)
  }
}

// MARK: - TokenParser

// Parses a list of tokens into an expression AST using recursive descent with precedence climbing.
private struct TokenParser {
  let tokens: [MathExpressionToken]
  var currentIndex: Int = 0
  let configuration: MathExpressionParserConfiguration

  // Returns the current token or nil if at end.
  private var currentToken: MathExpressionToken? {
    guard currentIndex < tokens.count else { return nil }
    return tokens[currentIndex]
  }

  // Advances to the next token.
  private mutating func advance() {
    currentIndex += 1
  }

  // Parses a complete expression.
  mutating func parseExpression() throws -> ExpressionNode {
    return try parseBinaryExpression(minPrecedence: 0)
  }

  // Parses a binary expression using precedence climbing.
  private mutating func parseBinaryExpression(minPrecedence: Int) throws -> ExpressionNode {
    var left = try parseUnaryExpression()

    while let token = currentToken {
      guard case .binaryOperator(let op) = token else { break }
      guard op.precedence >= minPrecedence else { break }

      advance()

      // Determine next minimum precedence based on associativity.
      let nextMinPrecedence = op.isRightAssociative ? op.precedence : op.precedence + 1
      let right = try parseBinaryExpression(minPrecedence: nextMinPrecedence)

      left = .binary(left: left, op: op, right: right)
    }

    return left
  }

  // Parses a unary expression (handles unary + and -).
  private mutating func parseUnaryExpression() throws -> ExpressionNode {
    if let token = currentToken, case .unaryOperator(let op) = token {
      advance()
      let operand = try parseUnaryExpression()
      return .unary(op: op, operand: operand)
    }
    return try parsePrimaryExpression()
  }

  // Parses a primary expression (numbers, variables, parentheses, functions).
  private mutating func parsePrimaryExpression() throws -> ExpressionNode {
    guard let token = currentToken else {
      throw MathExpressionError.unexpectedEndOfExpression
    }

    switch token {
    case .number(let value):
      advance()
      return .number(value)

    case .variable(let name):
      advance()
      return .variable(name)

    case .constant(let constant):
      advance()
      return .constant(constant)

    case .function(let function):
      advance()
      return try parseFunctionCall(function)

    case .leftParen:
      advance()
      let innerExpression = try parseExpression()
      guard case .rightParen = currentToken else {
        throw MathExpressionError.unmatchedParenthesis(position: currentIndex)
      }
      advance()
      return innerExpression

    case .rightParen:
      throw MathExpressionError.unexpectedToken(token: ")", position: currentIndex)

    case .binaryOperator(let op):
      throw MathExpressionError.unexpectedToken(token: op.rawValue, position: currentIndex)

    case .unaryOperator(let op):
      throw MathExpressionError.unexpectedToken(token: op.rawValue, position: currentIndex)

    case .comma:
      throw MathExpressionError.unexpectedToken(token: ",", position: currentIndex)
    }
  }

  // Parses a function call (expects opening paren, argument, closing paren).
  private mutating func parseFunctionCall(_ function: MathFunction) throws -> ExpressionNode {
    guard case .leftParen = currentToken else {
      throw MathExpressionError.unexpectedToken(
        token: describeCurrentToken(),
        position: currentIndex
      )
    }
    advance()

    // Check for empty argument list.
    if case .rightParen = currentToken {
      throw MathExpressionError.wrongArgumentCount(
        function: function.rawValue,
        expected: function.argumentCount,
        received: 0
      )
    }

    let argument = try parseExpression()

    guard case .rightParen = currentToken else {
      throw MathExpressionError.unmatchedParenthesis(position: currentIndex)
    }
    advance()

    return .function(function, argument: argument)
  }

  // Returns a description of the current token for error messages.
  private func describeCurrentToken() -> String {
    guard let token = currentToken else { return "end of expression" }
    switch token {
    case .number(let value): return String(value)
    case .variable(let name): return name
    case .constant(let constant): return constant.rawValue
    case .binaryOperator(let op): return op.rawValue
    case .unaryOperator(let op): return op.rawValue
    case .function(let fn): return fn.rawValue
    case .leftParen: return "("
    case .rightParen: return ")"
    case .comma: return ","
    }
  }
}
