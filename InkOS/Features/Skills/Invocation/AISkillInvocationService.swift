// AISkillInvocationService.swift
// Production implementation of AISkillInvocationServiceProtocol.
// Orchestrates AI chat with Gemini function calling for skills.

import Foundation

// Actor that orchestrates AI chat with Gemini function calling.
// Manages conversation flow and executes skills when AI requests them.
actor AISkillInvocationService: AISkillInvocationServiceProtocol {

  // Skill registry for looking up skill metadata.
  private let registry: any SkillRegistryProtocol

  // Skill executor for running skills locally.
  private let executor: any SkillExecutorProtocol

  // Cloud client for Firebase calls.
  private let cloudClient: any SkillCloudClientProtocol

  // Firebase configuration.
  private let configuration: FirebaseConfiguration

  // URLSession for network requests.
  private let session: URLSession

  // Base URL for cloud functions.
  private var baseURL: String {
    "https://\(configuration.region)-\(configuration.projectID).cloudfunctions.net"
  }

  // Initializes with required dependencies.
  init(
    registry: any SkillRegistryProtocol,
    executor: any SkillExecutorProtocol,
    cloudClient: any SkillCloudClientProtocol,
    configuration: FirebaseConfiguration,
    session: URLSession = .shared
  ) {
    self.registry = registry
    self.executor = executor
    self.cloudClient = cloudClient
    self.configuration = configuration
    self.session = session
  }

  // Convenience initializer using shared instances.
  init(configuration: FirebaseConfiguration) {
    let registry = SkillRegistry.shared
    let executor = SkillExecutor(registry: registry)
    let cloudClient = SkillCloudClient(configuration: configuration)
    self.registry = registry
    self.executor = executor
    self.cloudClient = cloudClient
    self.configuration = configuration
    self.session = .shared
  }

  // Returns Gemini-compatible function declarations for registered skills.
  func getToolDeclarations() async -> [GeminiFunctionDeclaration] {
    await registry.generateGeminiFunctionDeclarations()
  }

  // Sends a message to the AI and processes the response.
  func sendMessage(
    messages: [ConversationMessage],
    context: SkillContext
  ) async throws -> AISkillResponse {
    let toolDeclarations = await getToolDeclarations()

    let urlString = "\(baseURL)/sendMessageWithTools"
    guard let url = URL(string: urlString) else {
      throw InvocationError.networkError(reason: "Invalid URL: \(urlString)")
    }

    // Build request body.
    let requestBody = buildRequestBody(
      messages: messages,
      tools: toolDeclarations,
      toolConfig: nil
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = InvocationConstants.defaultAITimeoutSeconds

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw InvocationError.networkError(reason: "Failed to encode request: \(error)")
    }

    // Send request.
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let urlError as URLError {
      if urlError.code == .timedOut {
        throw InvocationError.timeout
      } else if urlError.code == .cancelled {
        throw InvocationError.cancelled
      }
      throw InvocationError.networkError(reason: urlError.localizedDescription)
    } catch {
      throw InvocationError.networkError(reason: error.localizedDescription)
    }

    // Check HTTP status.
    guard let httpResponse = response as? HTTPURLResponse else {
      throw InvocationError.invalidResponse(reason: "Not an HTTP response")
    }

    if httpResponse.statusCode >= 400 {
      throw InvocationError.networkError(
        reason: "Server error: \(httpResponse.statusCode)"
      )
    }

    // Parse and handle response.
    return try await parseAndHandleResponse(data: data, context: context)
  }

  // Sends a message with streaming response from AI.
  func sendMessageStreaming(
    messages: [ConversationMessage],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> AISkillResponse {
    let toolDeclarations = await getToolDeclarations()

    let urlString = "\(baseURL)/streamMessageWithTools"
    guard let url = URL(string: urlString) else {
      throw InvocationError.networkError(reason: "Invalid URL: \(urlString)")
    }

    // Build request body.
    let requestBody = buildRequestBody(
      messages: messages,
      tools: toolDeclarations,
      toolConfig: nil
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.timeoutInterval = InvocationConstants.defaultAITimeoutSeconds

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw InvocationError.networkError(reason: "Failed to encode request: \(error)")
    }

    // Create streaming task.
    let (bytes, response) = try await session.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw InvocationError.invalidResponse(reason: "Not an HTTP response")
    }

    if httpResponse.statusCode >= 400 {
      throw InvocationError.networkError(
        reason: "Server error: \(httpResponse.statusCode)"
      )
    }

    // Parse SSE stream.
    var accumulatedText = ""
    var functionCall: GeminiFunctionCall?

    do {
      for try await line in bytes.lines {
        try Task.checkCancellation()

        guard line.hasPrefix("data: ") else { continue }
        let jsonString = String(line.dropFirst(6))
        guard !jsonString.isEmpty else { continue }
        guard let jsonData = jsonString.data(using: .utf8) else { continue }

        do {
          let chunk = try JSONDecoder().decode(StreamingChunk.self, from: jsonData)

          // Emit text chunks.
          if let text = chunk.text {
            accumulatedText += text
            let resultChunk = SkillResultChunk(text: text, isComplete: false)
            onChunk(resultChunk)
          }

          // Check for function call.
          if chunk.type == "functionCall", let fc = chunk.functionCall {
            functionCall = GeminiFunctionCall(
              name: fc.name,
              arguments: parseArguments(fc.args)
            )
          }

          // Check for done signal.
          if chunk.done == true {
            onChunk(SkillResultChunk(text: "", isComplete: true))
            break
          }
        } catch is DecodingError {
          // Skip malformed chunks.
          continue
        }
      }
    } catch is CancellationError {
      throw InvocationError.cancelled
    } catch let urlError as URLError {
      throw InvocationError.streamingFailed(reason: urlError.localizedDescription)
    }

    // Handle function call if present.
    if let fc = functionCall {
      return try await executeSkillFromFunctionCall(fc, context: context)
    }

    // Return accumulated text.
    return .text(accumulatedText)
  }

  // Builds request body for AI endpoint.
  private func buildRequestBody(
    messages: [ConversationMessage],
    tools: [GeminiFunctionDeclaration],
    toolConfig: [String: Any]?
  ) -> [String: Any] {
    // Convert messages.
    let messageArray = messages.map { msg -> [String: String] in
      [
        "role": msg.role.rawValue,
        "content": msg.content,
      ]
    }

    var body: [String: Any] = ["messages": messageArray]

    // Add tools if any.
    if !tools.isEmpty {
      let toolsArray = tools.map { tool -> [String: Any] in
        var params: [String: Any] = [
          "type": "object",
          "properties": tool.parameters.properties.mapValues { prop -> [String: Any] in
            var propDict: [String: Any] = [
              "type": prop.type,
              "description": prop.description
            ]
            if let enumVals = prop.enumValues {
              propDict["enum"] = enumVals
            }
            return propDict
          },
        ]
        if !tool.parameters.required.isEmpty {
          params["required"] = tool.parameters.required
        }

        return [
          "name": tool.name,
          "description": tool.description,
          "parameters": params,
        ]
      }
      body["tools"] = toolsArray
    }

    // Add tool config if provided.
    if let config = toolConfig {
      body["toolConfig"] = config
    }

    return body
  }

  // Parses response from AI endpoint.
  private func parseAndHandleResponse(
    data: Data,
    context: SkillContext
  ) async throws -> AISkillResponse {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw InvocationError.invalidResponse(reason: "Response is not valid JSON")
    }

    // Check response type.
    guard let type = json["type"] as? String else {
      throw InvocationError.invalidResponse(reason: "Missing 'type' field")
    }

    switch type {
    case "text":
      let content = json["content"] as? String ?? ""
      return .text(content)

    case "functionCall":
      guard let fc = json["functionCall"] as? [String: Any],
            let name = fc["name"] as? String else {
        throw InvocationError.invalidResponse(reason: "Invalid function call format")
      }

      let args = fc["args"] as? [String: Any] ?? [:]
      let functionCall = GeminiFunctionCall(
        name: name,
        arguments: parseArguments(args)
      )

      return try await executeSkillFromFunctionCall(functionCall, context: context)

    default:
      throw InvocationError.invalidResponse(reason: "Unknown response type: \(type)")
    }
  }

  // Executes a skill based on Gemini function call.
  private func executeSkillFromFunctionCall(
    _ functionCall: GeminiFunctionCall,
    context: SkillContext
  ) async throws -> AISkillResponse {
    let skillID = functionCall.name
    let parameters = functionCall.arguments

    // Check if skill exists.
    let metadata = await registry.skill(withID: skillID)
    guard metadata != nil else {
      throw InvocationError.skillExecutionFailed(
        skillID: skillID,
        reason: "Skill not found"
      )
    }

    // Execute the skill.
    do {
      let result = try await executor.execute(
        skillID: skillID,
        parameters: parameters,
        context: context
      )
      return .skillInvocation(skillID: skillID, result: result)
    } catch let skillError as SkillError {
      let failedResult = SkillResult.failure(
        error: skillError,
        message: skillError.localizedDescription
      )
      return .skillInvocation(skillID: skillID, result: failedResult)
    } catch {
      throw InvocationError.skillExecutionFailed(
        skillID: skillID,
        reason: error.localizedDescription
      )
    }
  }

  // Parses arguments from JSON to SkillParameterValue.
  private func parseArguments(_ args: [String: Any]) -> [String: SkillParameterValue] {
    var result: [String: SkillParameterValue] = [:]
    for (key, value) in args {
      result[key] = parseValue(value)
    }
    return result
  }

  // Parses a single value to SkillParameterValue.
  private func parseValue(_ value: Any) -> SkillParameterValue {
    switch value {
    case let string as String:
      return .string(string)
    case let number as NSNumber:
      // Check if it's actually a boolean.
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return .boolean(number.boolValue)
      }
      return .number(number.doubleValue)
    case let array as [Any]:
      return .array(array.map { parseValue($0) })
    case let dict as [String: Any]:
      return .object(parseArguments(dict))
    default:
      return .string(String(describing: value))
    }
  }
}

// Helper struct for parsing streaming chunks.
private struct StreamingChunk: Decodable {
  let text: String?
  let type: String?
  let functionCall: FunctionCallChunk?
  let done: Bool?
  let error: String?

  struct FunctionCallChunk: Decodable {
    let name: String
    let args: [String: Any]

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try container.decode(String.self, forKey: .name)

      // Decode args as Any.
      let argsContainer = try container.nestedContainer(
        keyedBy: DynamicCodingKey.self,
        forKey: .args
      )
      var argsDict: [String: Any] = [:]
      for key in argsContainer.allKeys {
        if let stringValue = try? argsContainer.decode(String.self, forKey: key) {
          argsDict[key.stringValue] = stringValue
        } else if let doubleValue = try? argsContainer.decode(Double.self, forKey: key) {
          argsDict[key.stringValue] = doubleValue
        } else if let boolValue = try? argsContainer.decode(Bool.self, forKey: key) {
          argsDict[key.stringValue] = boolValue
        }
      }
      args = argsDict
    }

    enum CodingKeys: String, CodingKey {
      case name, args
    }
  }
}

// Dynamic coding key for parsing arbitrary JSON keys.
private struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
