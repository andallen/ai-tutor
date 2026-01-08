// SkillCloudClient.swift
// Production implementation of SkillCloudClientProtocol.
// Executes cloud and hybrid skills via Firebase Cloud Functions.

import Foundation

// Actor that handles cloud skill execution over the network.
// Sends requests to Firebase Cloud Functions and parses responses.
actor SkillCloudClient: SkillCloudClientProtocol {

  // Firebase configuration for building URLs.
  private let configuration: FirebaseConfiguration

  // URLSession for network requests.
  private let session: URLSession

  // Base URL for cloud functions.
  private var baseURL: String {
    "https://\(configuration.region)-\(configuration.projectID).cloudfunctions.net"
  }

  // Initializes with Firebase configuration.
  init(configuration: FirebaseConfiguration, session: URLSession = .shared) {
    self.configuration = configuration
    self.session = session
  }

  // Executes a skill on cloud infrastructure.
  func executeSkill(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) async throws -> SkillResult {
    let urlString = "\(baseURL)/executeSkill"
    guard let url = URL(string: urlString) else {
      throw InvocationError.networkError(reason: "Invalid URL: \(urlString)")
    }

    // Build request body.
    let requestBody = buildRequestBody(skillID: skillID, parameters: parameters, context: context)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = InvocationConstants.defaultCloudTimeoutSeconds

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

    if httpResponse.statusCode == 404 {
      throw InvocationError.skillExecutionFailed(
        skillID: skillID,
        reason: "Skill not found on server"
      )
    }

    if httpResponse.statusCode >= 500 {
      throw InvocationError.skillExecutionFailed(
        skillID: skillID,
        reason: "Server error: \(httpResponse.statusCode)"
      )
    }

    // Parse response.
    return try parseSkillResult(data: data, skillID: skillID)
  }

  // Executes a skill with streaming response from cloud.
  func executeSkillStreaming(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext,
    onChunk: @escaping @Sendable (SkillResultChunk) -> Void
  ) async throws -> SkillResult {
    let urlString = "\(baseURL)/executeSkillStreaming"
    guard let url = URL(string: urlString) else {
      throw InvocationError.networkError(reason: "Invalid URL: \(urlString)")
    }

    // Build request body.
    let requestBody = buildRequestBody(skillID: skillID, parameters: parameters, context: context)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.timeoutInterval = InvocationConstants.defaultCloudTimeoutSeconds

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
      throw InvocationError.skillExecutionFailed(
        skillID: skillID,
        reason: "Server error: \(httpResponse.statusCode)"
      )
    }

    // Parse SSE stream.
    var finalResult: SkillResult?

    do {
      for try await line in bytes.lines {
        // Check for task cancellation.
        try Task.checkCancellation()

        guard line.hasPrefix("data: ") else { continue }
        let jsonString = String(line.dropFirst(6))
        guard !jsonString.isEmpty else { continue }

        guard let jsonData = jsonString.data(using: .utf8) else { continue }

        do {
          let chunk = try JSONDecoder().decode(StreamChunk.self, from: jsonData)

          if let error = chunk.error {
            throw InvocationError.skillExecutionFailed(
              skillID: skillID,
              reason: error.message
            )
          }

          if let text = chunk.text {
            let resultChunk = SkillResultChunk(
              text: text,
              isComplete: chunk.isComplete ?? false
            )
            onChunk(resultChunk)
          }

          if chunk.isComplete == true, let result = chunk.result {
            finalResult = result
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

    // Return final result or synthesize one.
    if let result = finalResult {
      return result
    }

    // If no explicit result, return success.
    return SkillResult.success(text: "Streaming completed")
  }

  // Builds the request body dictionary.
  private func buildRequestBody(
    skillID: String,
    parameters: [String: SkillParameterValue],
    context: SkillContext
  ) -> [String: Any] {
    var body: [String: Any] = [
      "skillID": skillID,
      "parameters": parametersToJSON(parameters),
    ]

    var contextDict: [String: Any] = [:]
    if let notebookID = context.currentNotebookID {
      contextDict["currentNotebookID"] = notebookID
    }
    if let pdfID = context.currentPDFID {
      contextDict["currentPDFID"] = pdfID
    }
    if let userMessage = context.userMessage {
      contextDict["userMessage"] = userMessage
    }
    body["context"] = contextDict

    return body
  }

  // Converts SkillParameterValue dictionary to JSON-compatible dictionary.
  private func parametersToJSON(_ parameters: [String: SkillParameterValue]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in parameters {
      result[key] = parameterValueToJSON(value)
    }
    return result
  }

  // Converts a single SkillParameterValue to JSON-compatible value.
  private func parameterValueToJSON(_ value: SkillParameterValue) -> Any {
    switch value {
    case .string(let s):
      return s
    case .number(let n):
      return n
    case .boolean(let b):
      return b
    case .array(let arr):
      return arr.map { parameterValueToJSON($0) }
    case .object(let obj):
      return parametersToJSON(obj)
    }
  }

  // Parses the skill result from response data.
  private func parseSkillResult(data: Data, skillID: String) throws -> SkillResult {
    do {
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      guard let json = json else {
        throw InvocationError.invalidResponse(reason: "Response is not a JSON object")
      }

      // Check for error in response.
      if let error = json["error"] as? [String: Any],
         let message = error["message"] as? String {
        return SkillResult.failure(
          error: SkillError.executionFailed(reason: message),
          message: message
        )
      }

      // Parse success response.
      let success = json["success"] as? Bool ?? true
      let message = json["message"] as? String

      if success {
        // Parse data field.
        if let dataDict = json["data"] as? [String: Any] {
          let resultData = parseResultData(dataDict)
          return SkillResult.success(data: resultData, message: message)
        }
        return SkillResult.success(text: message ?? "")
      } else {
        let errorMessage = message ?? "Unknown error"
        return SkillResult.failure(
          error: SkillError.executionFailed(reason: errorMessage),
          message: errorMessage
        )
      }
    } catch let invocationError as InvocationError {
      throw invocationError
    } catch {
      throw InvocationError.invalidResponse(
        reason: "Failed to parse response: \(error.localizedDescription)"
      )
    }
  }

  // Parses result data dictionary into SkillResultData.
  private func parseResultData(_ dict: [String: Any]) -> SkillResultData {
    // Determine type from dictionary.
    let type = dict["type"] as? String ?? "unknown"

    switch type {
    case "text":
      let text = dict["text"] as? String ?? ""
      return .text(text)
    case "lesson":
      return .lesson(SkillLessonContent(
        title: dict["title"] as? String ?? "",
        sections: parseSections(dict["sections"]),
        exercises: parseExercises(dict["exercises"])
      ))
    case "graph":
      let graphType = GraphType(rawValue: dict["graphType"] as? String ?? "line") ?? .line
      return .graph(GraphData(
        graphType: graphType,
        xAxisLabel: dict["xAxisLabel"] as? String,
        yAxisLabel: dict["yAxisLabel"] as? String,
        series: parseSeries(dict["series"])
      ))
    case "transcription":
      return .transcription(TranscriptionResult(
        text: dict["text"] as? String ?? "",
        language: dict["language"] as? String,
        confidence: dict["confidence"] as? Double,
        wordTimestamps: parseWordTimestamps(dict["wordTimestamps"])
      ))
    case "mistake_analysis":
      // Parse corrections into string dictionary for analysis case.
      let corrections = parseCorrectionsDict(dict["corrections"])
      return .analysis(corrections)
    case "graphSpecification":
      // Parse GraphSpecification from JSON dictionary.
      if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
         let spec = try? JSONDecoder().decode(GraphSpecification.self, from: jsonData) {
        return .graphSpecification(spec)
      }
      // Fallback to raw JSON if parsing fails.
      if let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
        return .json(jsonData)
      }
      return .text("")
    default:
      // Return as raw JSON for unknown types.
      if let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
        return .json(jsonData)
      }
      return .text("")
    }
  }

  // Parses sections array from JSON.
  private func parseSections(_ value: Any?) -> [SkillLessonSection] {
    guard let array = value as? [[String: Any]] else { return [] }
    return array.compactMap { dict in
      guard let heading = dict["heading"] as? String,
            let content = dict["content"] as? String else { return nil }
      return SkillLessonSection(heading: heading, content: content)
    }
  }

  // Parses exercises array from JSON.
  private func parseExercises(_ value: Any?) -> [SkillLessonExercise]? {
    guard let array = value as? [[String: Any]] else { return nil }
    let exercises = array.compactMap { dict -> SkillLessonExercise? in
      guard let prompt = dict["prompt"] as? String else { return nil }
      return SkillLessonExercise(
        prompt: prompt,
        hint: dict["hint"] as? String,
        answer: dict["answer"] as? String
      )
    }
    return exercises.isEmpty ? nil : exercises
  }

  // Parses data series array from JSON.
  private func parseSeries(_ value: Any?) -> [DataSeries] {
    guard let array = value as? [[String: Any]] else { return [] }
    return array.compactMap { dict in
      guard let name = dict["name"] as? String else { return nil }
      let points = parseDataPoints(dict["dataPoints"])
      return DataSeries(name: name, dataPoints: points)
    }
  }

  // Parses data points as tuples.
  private func parseDataPoints(_ value: Any?) -> [(x: Double, y: Double)] {
    guard let array = value as? [[String: Any]] else { return [] }
    return array.compactMap { dict in
      guard let x = dict["x"] as? Double,
            let y = dict["y"] as? Double else { return nil }
      return (x: x, y: y)
    }
  }

  // Parses word timestamps from JSON.
  private func parseWordTimestamps(_ value: Any?) -> [WordTimestamp]? {
    guard let array = value as? [[String: Any]] else { return nil }
    let timestamps = array.compactMap { dict -> WordTimestamp? in
      guard let word = dict["word"] as? String,
            let startTime = dict["startTime"] as? Double,
            let endTime = dict["endTime"] as? Double else { return nil }
      return WordTimestamp(word: word, startTime: startTime, endTime: endTime)
    }
    return timestamps.isEmpty ? nil : timestamps
  }

  // Parses corrections into a string dictionary.
  private func parseCorrectionsDict(_ value: Any?) -> [String: String] {
    guard let array = value as? [[String: Any]] else { return [:] }
    var result: [String: String] = [:]
    for (index, dict) in array.enumerated() {
      let location = dict["location"] as? String ?? "unknown"
      let original = dict["original"] as? String ?? ""
      let correction = dict["correction"] as? String ?? ""
      let explanation = dict["explanation"] as? String ?? ""
      result["correction_\(index)"] = "\(location): '\(original)' -> '\(correction)' (\(explanation))"
    }
    return result
  }
}

// Helper struct for parsing SSE stream chunks.
private struct StreamChunk {
  let text: String?
  let isComplete: Bool?
  let result: SkillResult?
  let error: StreamError?

  struct StreamError: Decodable {
    let code: String
    let message: String
  }

  // Custom init from JSON decoder to manually parse result.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.text = try container.decodeIfPresent(String.self, forKey: .text)
    self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete)
    self.error = try container.decodeIfPresent(StreamError.self, forKey: .error)

    // Manually parse result if present.
    if let resultDict = try container.decodeIfPresent([String: Any].self, forKey: .result) {
      let success = resultDict["success"] as? Bool ?? false
      let message = resultDict["message"] as? String

      if let dataDict = resultDict["data"] as? [String: Any] {
        let data = Self.parseResultData(dataDict)
        self.result = SkillResult.success(data: data, message: message)
      } else if let errorDict = resultDict["error"] as? [String: Any] {
        let errorMessage = errorDict["message"] as? String ?? "Unknown error"
        let skillError = SkillError.executionFailed(reason: errorMessage)
        self.result = SkillResult.failure(error: skillError, message: message)
      } else {
        self.result = success ? SkillResult.success(data: .text(""), message: message) : SkillResult.failure(error: SkillError.executionFailed(reason: "Unknown error"), message: message)
      }
    } else {
      self.result = nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case text
    case isComplete
    case result
    case error
  }

  // Helper to parse result data from JSON.
  private static func parseResultData(_ dict: [String: Any]) -> SkillResultData {
    guard let type = dict["type"] as? String else {
      return .text("")
    }

    switch type {
    case "text":
      return .text(dict["text"] as? String ?? "")
    case "lesson":
      // Parse lesson content.
      return .text("") // Simplified for now
    case "graph":
      // Parse graph data.
      return .text("") // Simplified for now
    case "transcription":
      // Parse transcription.
      return .text("") // Simplified for now
    case "analysis":
      return .analysis(dict as? [String: String] ?? [:])
    case "graphSpecification":
      // Parse GraphSpecification from JSON dictionary.
      if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
         let spec = try? JSONDecoder().decode(GraphSpecification.self, from: jsonData) {
        return .graphSpecification(spec)
      }
      return .text("")
    default:
      return .text("")
    }
  }
}

// Extension to make StreamChunk decodable.
extension StreamChunk: Decodable {}

// Extension to decode [String: Any] from Decoder.
extension KeyedDecodingContainer {
  func decodeIfPresent(_ type: [String: Any].Type, forKey key: Key) throws -> [String: Any]? {
    guard contains(key) else { return nil }
    guard let dict = try decodeIfPresent(Dictionary<String, AnyCodable>.self, forKey: key) else {
      return nil
    }
    return dict.mapValues { $0.value }
  }
}

// Helper to wrap Any for Codable.
private struct AnyCodable: Codable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict.mapValues { $0.value }
    } else {
      value = NSNull()
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { AnyCodable($0) })
    case let dict as [String: Any]:
      try container.encode(dict.mapValues { AnyCodable($0) })
    default:
      try container.encodeNil()
    }
  }
}
