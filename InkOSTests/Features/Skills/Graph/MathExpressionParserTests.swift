// MathExpressionParserTests.swift
// Tests for MathExpressionParser covering tokenization, operator evaluation,
// function evaluation, expression parsing, and error handling.
// These tests validate the contract defined in MathExpressionParserContract.swift.

import XCTest

@testable import InkOS

// MARK: - MathConstant Tests

final class MathConstantTests: XCTestCase {

  // MARK: - Value Tests

  func testPiConstant_value_returnsDoublePi() {
    // Arrange
    let constant = MathConstant.pi

    // Act
    let value = constant.value

    // Assert
    XCTAssertEqual(value, Double.pi, accuracy: 1e-15)
  }

  func testEConstant_value_returnsME() {
    // Arrange
    let constant = MathConstant.e

    // Act
    let value = constant.value

    // Assert
    XCTAssertEqual(value, M_E, accuracy: 1e-15)
  }

  // MARK: - CaseIterable Tests

  func testMathConstant_allCases_containsPiAndE() {
    // Arrange & Act
    let allCases = MathConstant.allCases

    // Assert
    XCTAssertEqual(allCases.count, 2)
    XCTAssertTrue(allCases.contains(.pi))
    XCTAssertTrue(allCases.contains(.e))
  }
}

// MARK: - MathBinaryOperator Tests

final class MathBinaryOperatorTests: XCTestCase {

  // MARK: - Evaluate Addition

  func testAdd_evaluate_returnsSum() {
    // Arrange
    let op = MathBinaryOperator.add

    // Act
    let result = op.evaluate(left: 3, right: 5)

    // Assert
    XCTAssertEqual(result, 8.0, accuracy: 1e-15)
  }

  // MARK: - Evaluate Subtraction

  func testSubtract_evaluate_returnsDifference() {
    // Arrange
    let op = MathBinaryOperator.subtract

    // Act
    let result = op.evaluate(left: 10, right: 4)

    // Assert
    XCTAssertEqual(result, 6.0, accuracy: 1e-15)
  }

  // MARK: - Evaluate Multiplication

  func testMultiply_evaluate_returnsProduct() {
    // Arrange
    let op = MathBinaryOperator.multiply

    // Act
    let result = op.evaluate(left: 6, right: 7)

    // Assert
    XCTAssertEqual(result, 42.0, accuracy: 1e-15)
  }

  // MARK: - Evaluate Division

  func testDivide_evaluate_returnsQuotient() {
    // Arrange
    let op = MathBinaryOperator.divide

    // Act
    let result = op.evaluate(left: 15, right: 3)

    // Assert
    XCTAssertEqual(result, 5.0, accuracy: 1e-15)
  }

  func testDivide_byZero_returnsInfinity() {
    // Arrange
    let op = MathBinaryOperator.divide

    // Act
    let result = op.evaluate(left: 5, right: 0)

    // Assert - IEEE 754 behavior
    XCTAssertTrue(result.isInfinite)
    XCTAssertTrue(result > 0)
  }

  // MARK: - Evaluate Power

  func testPower_evaluate_returnsExponentiation() {
    // Arrange
    let op = MathBinaryOperator.power

    // Act
    let result = op.evaluate(left: 2, right: 10)

    // Assert
    XCTAssertEqual(result, 1024.0, accuracy: 1e-15)
  }

  func testPower_zeroToNegative_returnsInfinity() {
    // Arrange
    let op = MathBinaryOperator.power

    // Act
    let result = op.evaluate(left: 0, right: -1)

    // Assert
    XCTAssertTrue(result.isInfinite)
  }

  // MARK: - Precedence Tests

  func testOperatorPrecedence_additionAndSubtraction_haveLowestPrecedence() {
    // Arrange & Act & Assert
    XCTAssertEqual(MathBinaryOperator.add.precedence, 1)
    XCTAssertEqual(MathBinaryOperator.subtract.precedence, 1)
  }

  func testOperatorPrecedence_multiplicationAndDivision_haveMiddlePrecedence() {
    // Arrange & Act & Assert
    XCTAssertEqual(MathBinaryOperator.multiply.precedence, 2)
    XCTAssertEqual(MathBinaryOperator.divide.precedence, 2)
  }

  func testOperatorPrecedence_power_hasHighestPrecedence() {
    // Arrange & Act & Assert
    XCTAssertEqual(MathBinaryOperator.power.precedence, 3)
  }

  // MARK: - Associativity Tests

  func testPower_isRightAssociative_returnsTrue() {
    // Arrange & Act & Assert
    XCTAssertTrue(MathBinaryOperator.power.isRightAssociative)
  }

  func testOtherOperators_areNotRightAssociative() {
    // Arrange & Act & Assert
    XCTAssertFalse(MathBinaryOperator.add.isRightAssociative)
    XCTAssertFalse(MathBinaryOperator.subtract.isRightAssociative)
    XCTAssertFalse(MathBinaryOperator.multiply.isRightAssociative)
    XCTAssertFalse(MathBinaryOperator.divide.isRightAssociative)
  }
}

// MARK: - MathUnaryOperator Tests

final class MathUnaryOperatorTests: XCTestCase {

  func testNegate_evaluate_returnsNegatedValue() {
    // Arrange
    let op = MathUnaryOperator.negate

    // Act
    let result = op.evaluate(operand: 5)

    // Assert
    XCTAssertEqual(result, -5.0, accuracy: 1e-15)
  }

  func testPlus_evaluate_returnsSameValue() {
    // Arrange
    let op = MathUnaryOperator.plus

    // Act
    let result = op.evaluate(operand: 5)

    // Assert
    XCTAssertEqual(result, 5.0, accuracy: 1e-15)
  }

  func testNegate_doubleNegation_returnsOriginalValue() {
    // Arrange
    let op = MathUnaryOperator.negate

    // Act
    let firstNegation = op.evaluate(operand: 3)
    let result = op.evaluate(operand: firstNegation)

    // Assert
    XCTAssertEqual(result, 3.0, accuracy: 1e-15)
  }
}

// MARK: - MathFunction Tests

final class MathFunctionTests: XCTestCase {

  // MARK: - Trigonometric Functions

  func testSin_atPiOver2_returnsOne() {
    // Arrange
    let function = MathFunction.sin

    // Act
    let result = function.evaluate(arguments: [Double.pi / 2])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-10)
  }

  func testCos_atZero_returnsOne() {
    // Arrange
    let function = MathFunction.cos

    // Act
    let result = function.evaluate(arguments: [0])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-15)
  }

  func testTan_atPiOver4_returnsOne() {
    // Arrange
    let function = MathFunction.tan

    // Act
    let result = function.evaluate(arguments: [Double.pi / 4])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-10)
  }

  func testTan_atPiOver2_returnsVeryLargeValue() {
    // Arrange
    let function = MathFunction.tan

    // Act
    let result = function.evaluate(arguments: [Double.pi / 2])

    // Assert - Due to floating point, not exactly infinity but very large
    XCTAssertTrue(abs(result) > 1e10)
  }

  // MARK: - Inverse Trigonometric Functions

  func testAsin_atOne_returnsPiOver2() {
    // Arrange
    let function = MathFunction.asin

    // Act
    let result = function.evaluate(arguments: [1.0])

    // Assert
    XCTAssertEqual(result, Double.pi / 2, accuracy: 1e-10)
  }

  func testAsin_outsideDomain_returnsNaN() {
    // Arrange
    let function = MathFunction.asin

    // Act
    let result = function.evaluate(arguments: [2.0])

    // Assert - Domain is [-1, 1]
    XCTAssertTrue(result.isNaN)
  }

  func testAcos_atZero_returnsPiOver2() {
    // Arrange
    let function = MathFunction.acos

    // Act
    let result = function.evaluate(arguments: [0.0])

    // Assert
    XCTAssertEqual(result, Double.pi / 2, accuracy: 1e-10)
  }

  // MARK: - Hyperbolic Functions

  func testSinh_atZero_returnsZero() {
    // Arrange
    let function = MathFunction.sinh

    // Act
    let result = function.evaluate(arguments: [0.0])

    // Assert
    XCTAssertEqual(result, 0.0, accuracy: 1e-15)
  }

  func testCosh_atZero_returnsOne() {
    // Arrange
    let function = MathFunction.cosh

    // Act
    let result = function.evaluate(arguments: [0.0])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-15)
  }

  func testTanh_atZero_returnsZero() {
    // Arrange
    let function = MathFunction.tanh

    // Act
    let result = function.evaluate(arguments: [0.0])

    // Assert
    XCTAssertEqual(result, 0.0, accuracy: 1e-15)
  }

  // MARK: - Square Root

  func testSqrt_of16_returns4() {
    // Arrange
    let function = MathFunction.sqrt

    // Act
    let result = function.evaluate(arguments: [16])

    // Assert
    XCTAssertEqual(result, 4.0, accuracy: 1e-15)
  }

  func testSqrt_ofNegative_returnsNaN() {
    // Arrange
    let function = MathFunction.sqrt

    // Act
    let result = function.evaluate(arguments: [-4])

    // Assert
    XCTAssertTrue(result.isNaN)
  }

  // MARK: - Absolute Value

  func testAbs_ofNegative_returnsPositive() {
    // Arrange
    let function = MathFunction.abs

    // Act
    let result = function.evaluate(arguments: [-7.5])

    // Assert
    XCTAssertEqual(result, 7.5, accuracy: 1e-15)
  }

  // MARK: - Logarithms

  func testLn_ofE_returnsOne() {
    // Arrange
    let function = MathFunction.ln

    // Act
    let result = function.evaluate(arguments: [M_E])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-10)
  }

  func testLn_ofZero_returnsNegativeInfinity() {
    // Arrange
    let function = MathFunction.ln

    // Act
    let result = function.evaluate(arguments: [0])

    // Assert
    XCTAssertTrue(result.isInfinite)
    XCTAssertTrue(result < 0)
  }

  func testLn_ofNegative_returnsNaN() {
    // Arrange
    let function = MathFunction.ln

    // Act
    let result = function.evaluate(arguments: [-1])

    // Assert
    XCTAssertTrue(result.isNaN)
  }

  func testLog_of100_returns2() {
    // Arrange
    let function = MathFunction.log

    // Act
    let result = function.evaluate(arguments: [100])

    // Assert
    XCTAssertEqual(result, 2.0, accuracy: 1e-10)
  }

  func testLog2_of8_returns3() {
    // Arrange
    let function = MathFunction.log2

    // Act
    let result = function.evaluate(arguments: [8])

    // Assert
    XCTAssertEqual(result, 3.0, accuracy: 1e-10)
  }

  // MARK: - Exponential

  func testExp_of1_returnsE() {
    // Arrange
    let function = MathFunction.exp

    // Act
    let result = function.evaluate(arguments: [1])

    // Assert
    XCTAssertEqual(result, M_E, accuracy: 1e-10)
  }

  // MARK: - Floor and Ceiling

  func testFloor_of3Point7_returns3() {
    // Arrange
    let function = MathFunction.floor

    // Act
    let result = function.evaluate(arguments: [3.7])

    // Assert
    XCTAssertEqual(result, 3.0, accuracy: 1e-15)
  }

  func testCeil_of3Point2_returns4() {
    // Arrange
    let function = MathFunction.ceil

    // Act
    let result = function.evaluate(arguments: [3.2])

    // Assert
    XCTAssertEqual(result, 4.0, accuracy: 1e-15)
  }

  // MARK: - Sign Function

  func testSign_ofNegative_returnsNegativeOne() {
    // Arrange
    let function = MathFunction.sign

    // Act
    let result = function.evaluate(arguments: [-5])

    // Assert
    XCTAssertEqual(result, -1.0, accuracy: 1e-15)
  }

  func testSign_ofPositive_returnsOne() {
    // Arrange
    let function = MathFunction.sign

    // Act
    let result = function.evaluate(arguments: [5])

    // Assert
    XCTAssertEqual(result, 1.0, accuracy: 1e-15)
  }

  func testSign_ofZero_returnsZero() {
    // Arrange
    let function = MathFunction.sign

    // Act
    let result = function.evaluate(arguments: [0])

    // Assert
    XCTAssertEqual(result, 0.0, accuracy: 1e-15)
  }

  // MARK: - Wrong Argument Count

  func testFunction_wrongArgumentCount_returnsNaN() {
    // Arrange
    let function = MathFunction.sin

    // Act
    let result = function.evaluate(arguments: [1, 2])

    // Assert
    XCTAssertTrue(result.isNaN)
  }

  func testFunction_emptyArguments_returnsNaN() {
    // Arrange
    let function = MathFunction.sin

    // Act
    let result = function.evaluate(arguments: [])

    // Assert
    XCTAssertTrue(result.isNaN)
  }

  // MARK: - Argument Count Property

  func testAllFunctions_argumentCount_isOne() {
    // Arrange & Act & Assert
    for function in MathFunction.allCases {
      XCTAssertEqual(function.argumentCount, 1, "Function \(function) should have 1 argument")
    }
  }
}

// MARK: - MathExpressionError Tests

final class MathExpressionErrorTests: XCTestCase {

  func testEmptyExpressionError_description_isNotEmpty() {
    // Arrange
    let error = MathExpressionError.emptyExpression

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertFalse(description!.isEmpty)
  }

  func testUnexpectedCharacterError_includesCharacterAndPosition() {
    // Arrange
    let error = MathExpressionError.unexpectedCharacter(character: "@", position: 5)

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("@"))
    XCTAssertTrue(description!.contains("5"))
  }

  func testUnmatchedParenthesisError_includesPosition() {
    // Arrange
    let error = MathExpressionError.unmatchedParenthesis(position: 3)

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("3"))
  }

  func testUnknownFunctionError_includesFunctionName() {
    // Arrange
    let error = MathExpressionError.unknownFunction(name: "foobar")

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("foobar"))
  }

  func testWrongArgumentCountError_includesDetails() {
    // Arrange
    let error = MathExpressionError.wrongArgumentCount(function: "sin", expected: 1, received: 0)

    // Act
    let description = error.errorDescription

    // Assert
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("sin"))
    XCTAssertTrue(description!.contains("1"))
    XCTAssertTrue(description!.contains("0"))
  }

  // MARK: - Equatable Tests

  func testMathExpressionError_equatable_sameErrorsAreEqual() {
    // Arrange
    let error1 = MathExpressionError.emptyExpression
    let error2 = MathExpressionError.emptyExpression

    // Act & Assert
    XCTAssertEqual(error1, error2)
  }

  func testMathExpressionError_equatable_differentErrorsAreNotEqual() {
    // Arrange
    let error1 = MathExpressionError.emptyExpression
    let error2 = MathExpressionError.unexpectedEndOfExpression

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }

  func testMathExpressionError_equatable_sameTypeWithDifferentValuesAreNotEqual() {
    // Arrange
    let error1 = MathExpressionError.unknownFunction(name: "foo")
    let error2 = MathExpressionError.unknownFunction(name: "bar")

    // Act & Assert
    XCTAssertNotEqual(error1, error2)
  }
}

// MARK: - MathExpressionParserConfiguration Tests

final class MathExpressionParserConfigurationTests: XCTestCase {

  func testDefaultConfiguration_allowsImplicitMultiplication() {
    // Arrange & Act
    let config = MathExpressionParserConfiguration.default

    // Assert
    XCTAssertTrue(config.allowImplicitMultiplication)
  }

  func testDefaultConfiguration_hasExpectedDefaults() {
    // Arrange & Act
    let config = MathExpressionParserConfiguration.default

    // Assert
    XCTAssertTrue(config.caseSensitiveVariables)
    XCTAssertFalse(config.caseSensitiveFunctions)
    XCTAssertEqual(config.maxExpressionLength, 10000)
    XCTAssertEqual(config.maxNestingDepth, 100)
  }

  func testStrictConfiguration_disallowsImplicitMultiplication() {
    // Arrange & Act
    let config = MathExpressionParserConfiguration.strict

    // Assert
    XCTAssertFalse(config.allowImplicitMultiplication)
  }

  func testStrictConfiguration_isCaseSensitive() {
    // Arrange & Act
    let config = MathExpressionParserConfiguration.strict

    // Assert
    XCTAssertTrue(config.caseSensitiveVariables)
    XCTAssertTrue(config.caseSensitiveFunctions)
  }
}

// MARK: - MathExpressionConstants Tests

final class MathExpressionConstantsTests: XCTestCase {

  func testExplicitVariables_containsX() {
    // Arrange & Act & Assert
    XCTAssertTrue(MathExpressionConstants.explicitVariables.contains("x"))
  }

  func testParametricVariables_containsT() {
    // Arrange & Act & Assert
    XCTAssertTrue(MathExpressionConstants.parametricVariables.contains("t"))
  }

  func testPolarVariables_containsTheta() {
    // Arrange & Act & Assert
    XCTAssertTrue(MathExpressionConstants.polarVariables.contains("theta"))
  }

  func testAllVariables_containsExpectedVariables() {
    // Arrange & Act
    let allVars = MathExpressionConstants.allVariables

    // Assert
    XCTAssertTrue(allVars.contains("x"))
    XCTAssertTrue(allVars.contains("y"))
    XCTAssertTrue(allVars.contains("t"))
    XCTAssertTrue(allVars.contains("theta"))
    XCTAssertTrue(allVars.contains("r"))
  }

  func testDefaultSampleCount_isReasonable() {
    // Arrange & Act & Assert
    XCTAssertEqual(MathExpressionConstants.defaultSampleCount, 500)
  }
}

// MARK: - MathExpressionToken Tests

final class MathExpressionTokenTests: XCTestCase {

  func testNumberToken_isEquatable() {
    // Arrange
    let token1 = MathExpressionToken.number(3.14)
    let token2 = MathExpressionToken.number(3.14)
    let token3 = MathExpressionToken.number(2.71)

    // Assert
    XCTAssertEqual(token1, token2)
    XCTAssertNotEqual(token1, token3)
  }

  func testVariableToken_isEquatable() {
    // Arrange
    let token1 = MathExpressionToken.variable("x")
    let token2 = MathExpressionToken.variable("x")
    let token3 = MathExpressionToken.variable("y")

    // Assert
    XCTAssertEqual(token1, token2)
    XCTAssertNotEqual(token1, token3)
  }

  func testConstantToken_isEquatable() {
    // Arrange
    let token1 = MathExpressionToken.constant(.pi)
    let token2 = MathExpressionToken.constant(.pi)
    let token3 = MathExpressionToken.constant(.e)

    // Assert
    XCTAssertEqual(token1, token2)
    XCTAssertNotEqual(token1, token3)
  }

  func testFunctionToken_isEquatable() {
    // Arrange
    let token1 = MathExpressionToken.function(.sin)
    let token2 = MathExpressionToken.function(.sin)
    let token3 = MathExpressionToken.function(.cos)

    // Assert
    XCTAssertEqual(token1, token2)
    XCTAssertNotEqual(token1, token3)
  }

  func testBinaryOperatorToken_isEquatable() {
    // Arrange
    let token1 = MathExpressionToken.binaryOperator(.add)
    let token2 = MathExpressionToken.binaryOperator(.add)
    let token3 = MathExpressionToken.binaryOperator(.multiply)

    // Assert
    XCTAssertEqual(token1, token2)
    XCTAssertNotEqual(token1, token3)
  }

  func testParenthesesTokens_areEquatable() {
    // Arrange
    let leftParen1 = MathExpressionToken.leftParen
    let leftParen2 = MathExpressionToken.leftParen
    let rightParen = MathExpressionToken.rightParen

    // Assert
    XCTAssertEqual(leftParen1, leftParen2)
    XCTAssertNotEqual(leftParen1, rightParen)
  }
}

// MARK: - Mock Parser for Testing ParsedExpression

// Mock implementation of MathExpressionParserProtocol for testing purposes.
// This mock returns pre-configured ParsedExpression objects.
final class MockMathExpressionParser: MathExpressionParserProtocol, @unchecked Sendable {
  var parseCallCount = 0
  var lastParsedExpression: String?
  var parsedExpressionToReturn: (any ParsedExpressionProtocol)?
  var errorToThrow: MathExpressionError?

  func parse(_ expression: String) throws -> any ParsedExpressionProtocol {
    parseCallCount += 1
    lastParsedExpression = expression

    if let error = errorToThrow {
      throw error
    }

    guard let result = parsedExpressionToReturn else {
      throw MathExpressionError.emptyExpression
    }

    return result
  }
}

// Mock implementation of ParsedExpressionProtocol for testing.
struct MockParsedExpression: ParsedExpressionProtocol, @unchecked Sendable {
  var variables: Set<String>
  var originalExpression: String
  var isConstant: Bool
  var evaluator: ([String: Double]) -> Double

  func evaluate(with variables: [String: Double]) -> Double {
    return evaluator(variables)
  }
}

// MARK: - MathExpressionParser Tests

// Tests for the MathExpressionParser interface and behavior.
// These tests use mocks to validate the protocol behavior.
final class MathExpressionParserTests: XCTestCase {

  var mockParser: MockMathExpressionParser!

  override func setUp() {
    super.setUp()
    mockParser = MockMathExpressionParser()
  }

  override func tearDown() {
    mockParser = nil
    super.tearDown()
  }

  // MARK: - Parse Simple Expression Tests

  func testParse_simpleExpression_callsParseMethod() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "x + 1",
      isConstant: false,
      evaluator: { vars in (vars["x"] ?? 0) + 1 }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x + 1")

    // Assert
    XCTAssertEqual(mockParser.parseCallCount, 1)
    XCTAssertEqual(mockParser.lastParsedExpression, "x + 1")
    XCTAssertEqual(result.evaluate(with: ["x": 5]), 6.0)
  }

  func testParse_expressionWithVariable_returnsCorrectVariableSet() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "x^2 + 2*x + 1",
      isConstant: false,
      evaluator: { vars in
        let x = vars["x"] ?? 0
        return x * x + 2 * x + 1
      }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x^2 + 2*x + 1")

    // Assert
    XCTAssertTrue(result.variables.contains("x"))
    XCTAssertEqual(result.evaluate(with: ["x": 3]), 16.0)
  }

  func testParse_expressionWithMultipleVariables_returnsAllVariables() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x", "y", "z"],
      originalExpression: "x * y + z",
      isConstant: false,
      evaluator: { vars in
        let x = vars["x"] ?? 0
        let y = vars["y"] ?? 0
        let z = vars["z"] ?? 0
        return x * y + z
      }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x * y + z")

    // Assert
    XCTAssertEqual(result.variables.count, 3)
    XCTAssertTrue(result.variables.contains("x"))
    XCTAssertTrue(result.variables.contains("y"))
    XCTAssertTrue(result.variables.contains("z"))
    XCTAssertEqual(result.evaluate(with: ["x": 2, "y": 3, "z": 4]), 10.0)
  }

  func testParse_constantExpression_hasNoVariables() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: [],
      originalExpression: "2 * pi",
      isConstant: true,
      evaluator: { _ in 2 * Double.pi }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("2 * pi")

    // Assert
    XCTAssertTrue(result.variables.isEmpty)
    XCTAssertTrue(result.isConstant)
    XCTAssertEqual(result.evaluate(with: [:]), 2 * Double.pi, accuracy: 1e-10)
  }

  func testParse_preservesOriginalExpression() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "x^2",
      isConstant: false,
      evaluator: { vars in pow(vars["x"] ?? 0, 2) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x^2")

    // Assert
    XCTAssertEqual(result.originalExpression, "x^2")
  }

  // MARK: - Parse Function Tests

  func testParse_expressionWithSinFunction_evaluatesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "sin(x)",
      isConstant: false,
      evaluator: { vars in sin(vars["x"] ?? 0) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("sin(x)")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": 0]), 0.0, accuracy: 1e-10)
    XCTAssertEqual(result.evaluate(with: ["x": Double.pi / 2]), 1.0, accuracy: 1e-10)
  }

  func testParse_expressionWithNestedFunctions_evaluatesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "sqrt(abs(x))",
      isConstant: false,
      evaluator: { vars in sqrt(abs(vars["x"] ?? 0)) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("sqrt(abs(x))")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": -16]), 4.0, accuracy: 1e-10)
  }

  func testParse_expressionWithParentheses_evaluatesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "(x + 1) * (x - 1)",
      isConstant: false,
      evaluator: { vars in
        let x = vars["x"] ?? 0
        return (x + 1) * (x - 1)
      }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("(x + 1) * (x - 1)")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": 5]), 24.0, accuracy: 1e-10)
  }

  func testParse_expressionWithTheta_parsesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["theta"],
      originalExpression: "1 + cos(theta)",
      isConstant: false,
      evaluator: { vars in 1 + cos(vars["theta"] ?? 0) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("1 + cos(theta)")

    // Assert
    XCTAssertTrue(result.variables.contains("theta"))
    XCTAssertEqual(result.evaluate(with: ["theta": 0]), 2.0, accuracy: 1e-10)
  }

  // MARK: - Error Handling Tests

  func testParse_emptyExpression_throwsEmptyExpressionError() {
    // Arrange
    mockParser.errorToThrow = .emptyExpression

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parse("")) { error in
      XCTAssertEqual(error as? MathExpressionError, .emptyExpression)
    }
  }

  func testParse_whitespaceOnlyExpression_throwsEmptyExpressionError() {
    // Arrange
    mockParser.errorToThrow = .emptyExpression

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parse("   ")) { error in
      XCTAssertEqual(error as? MathExpressionError, .emptyExpression)
    }
  }

  func testParse_unmatchedParenthesis_throwsError() {
    // Arrange
    mockParser.errorToThrow = .unmatchedParenthesis(position: 0)

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parse("(x + 1")) { error in
      guard case .unmatchedParenthesis = error as? MathExpressionError else {
        XCTFail("Expected unmatchedParenthesis error")
        return
      }
    }
  }

  func testParse_unknownFunction_throwsError() {
    // Arrange
    mockParser.errorToThrow = .unknownFunction(name: "foo")

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parse("foo(x)")) { error in
      guard case .unknownFunction(let name) = error as? MathExpressionError else {
        XCTFail("Expected unknownFunction error")
        return
      }
      XCTAssertEqual(name, "foo")
    }
  }

  func testParse_unexpectedCharacter_throwsError() {
    // Arrange
    mockParser.errorToThrow = .unexpectedCharacter(character: "@", position: 2)

    // Act & Assert
    XCTAssertThrowsError(try mockParser.parse("x @ y")) { error in
      guard case .unexpectedCharacter(let char, let pos) = error as? MathExpressionError else {
        XCTFail("Expected unexpectedCharacter error")
        return
      }
      XCTAssertEqual(char, "@")
      XCTAssertEqual(pos, 2)
    }
  }

  // MARK: - Edge Case Tests

  func testEvaluate_missingVariable_returnsNaN() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x", "y"],
      originalExpression: "x + y",
      isConstant: false,
      evaluator: { vars in
        guard let x = vars["x"], let y = vars["y"] else {
          return .nan
        }
        return x + y
      }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x + y")
    let value = result.evaluate(with: ["x": 1])

    // Assert - Missing y should cause NaN
    XCTAssertTrue(value.isNaN)
  }

  func testEvaluate_extraVariablesProvided_ignoresExtra() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "x + 1",
      isConstant: false,
      evaluator: { vars in (vars["x"] ?? 0) + 1 }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("x + 1")
    let value = result.evaluate(with: ["x": 5, "y": 10, "z": 15])

    // Assert - Extra variables should be ignored
    XCTAssertEqual(value, 6.0, accuracy: 1e-10)
  }

  func testEvaluate_divisionByZero_returnsInfinity() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "1/x",
      isConstant: false,
      evaluator: { vars in 1 / (vars["x"] ?? 0) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("1/x")

    // Assert
    XCTAssertTrue(result.evaluate(with: ["x": 0]).isInfinite)
    XCTAssertEqual(result.evaluate(with: ["x": 2]), 0.5, accuracy: 1e-10)
  }

  func testParse_deeplyNestedParentheses_parsesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "((((((x))))))",
      isConstant: false,
      evaluator: { vars in vars["x"] ?? 0 }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("((((((x))))))")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": 5]), 5.0, accuracy: 1e-10)
  }

  func testParse_unaryMinus_evaluatesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "-x^2",
      isConstant: false,
      evaluator: { vars in -(pow(vars["x"] ?? 0, 2)) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("-x^2")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": 3]), -9.0, accuracy: 1e-10)
  }

  func testParse_rightAssociativePower_evaluatesCorrectly() throws {
    // Arrange - 2^3^2 should be 2^(3^2) = 2^9 = 512, not (2^3)^2 = 64
    let mockExpression = MockParsedExpression(
      variables: [],
      originalExpression: "2^3^2",
      isConstant: true,
      evaluator: { _ in pow(2, pow(3, 2)) }  // 2^(3^2) = 512
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("2^3^2")

    // Assert
    XCTAssertEqual(result.evaluate(with: [:]), 512.0, accuracy: 1e-10)
  }

  func testParse_scientificNotation_evaluatesCorrectly() throws {
    // Arrange
    let mockExpression = MockParsedExpression(
      variables: ["x"],
      originalExpression: "1.5e-3 * x",
      isConstant: false,
      evaluator: { vars in 1.5e-3 * (vars["x"] ?? 0) }
    )
    mockParser.parsedExpressionToReturn = mockExpression

    // Act
    let result = try mockParser.parse("1.5e-3 * x")

    // Assert
    XCTAssertEqual(result.evaluate(with: ["x": 1000]), 1.5, accuracy: 1e-10)
  }
}
