//
// OrchestrationActor.swift
// InkOS
//
// Coordinates Alan's output processing and subagent requests.
// Manages the flow from user input to final notebook rendering.
//

import Foundation

// MARK: - OrchestrationDelegate

// Delegate protocol for orchestration events.
@MainActor
protocol OrchestrationDelegate: AnyObject {
  // Called when a block should be inserted into the notebook.
  func orchestration(_ orchestration: OrchestrationActor, didInsertBlock block: Block)

  // Called when a block should be updated (placeholder replaced with content).
  func orchestration(_ orchestration: OrchestrationActor, didUpdateBlock block: Block)

  // Called when streaming text is received (for live typing effect).
  func orchestration(_ orchestration: OrchestrationActor, didReceiveStreamingText text: String)

  // Called when the session model is updated by Alan.
  func orchestration(_ orchestration: OrchestrationActor, didUpdateSessionModel model: SessionModel)

  // Called when all processing is complete.
  func orchestrationDidComplete(_ orchestration: OrchestrationActor, tokenMetadata: TokenMetadata?)

  // Called when an error occurs.
  func orchestration(_ orchestration: OrchestrationActor, didEncounterError error: AlanError)
}

// MARK: - PendingRequest

// Tracks a pending subagent request.
struct PendingRequest: Sendable {
  let request: SubagentRequest
  let placeholderBlockId: BlockID
  let startTime: Date
}

// MARK: - OrchestrationActor

// Coordinates Alan output processing and subagent requests.
actor OrchestrationActor {
  // API client for Alan and subagent communication.
  private let apiClient: AlanAPIClient

  // Delegate for orchestration events (stored as nonisolated to allow MainActor access).
  private nonisolated(unsafe) weak var _delegate: OrchestrationDelegate?

  // Pending subagent requests awaiting response.
  private var pendingRequests: [SubagentRequestID: PendingRequest] = [:]

  // Timeout for subagent requests.
  private let subagentTimeout: TimeInterval = 30.0

  // Creates an orchestration actor.
  init(apiClient: AlanAPIClient = AlanAPIClient()) {
    self.apiClient = apiClient
  }

  // Sets the delegate for orchestration events.
  func setDelegate(_ delegate: OrchestrationDelegate?) {
    self._delegate = delegate
  }

  // MARK: - Message Processing

  // Sends a message to Alan and processes the response.
  func sendMessage(
    _ content: String,
    conversationHistory: [ChatMessage],
    notebookContext: NotebookContext,
    sessionModel: SessionModel? = nil
  ) async {
    // Build messages array with history and new message.
    var messages = conversationHistory
    messages.append(ChatMessage(role: .user, content: content))

    // Start streaming response from Alan.
    let stream = await apiClient.sendMessage(
      messages: messages,
      notebookContext: notebookContext,
      sessionModel: sessionModel
    )

    // Process the stream.
    await processAlanStream(stream)
  }

  // Processes Alan's streaming response.
  private func processAlanStream(
    _ stream: AsyncThrowingStream<AlanStreamEvent, Error>
  ) async {
    var collectedRequests: [SubagentRequest] = []
    var tokenMetadata: TokenMetadata?

    do {
      for try await event in stream {
        switch event {
        case .textChunk(let text):
          // Forward streaming text to delegate.
          await notifyStreamingText(text)

        case .blockComplete(let block):
          // Insert direct block immediately.
          await notifyBlockInserted(block)

        case .subagentRequest(let request):
          // Create placeholder and queue request.
          let placeholderId = BlockID()
          let placeholder = BlockFactory.createPlaceholder(for: request, id: placeholderId)
          await notifyBlockInserted(placeholder)

          // Track pending request.
          pendingRequests[request.id] = PendingRequest(
            request: request,
            placeholderBlockId: placeholderId,
            startTime: Date()
          )
          collectedRequests.append(request)

        case .sessionModelUpdate(let model):
          // Notify delegate of updated session model.
          await notifySessionModelUpdated(model)

        case .done(let metadata):
          tokenMetadata = metadata

        case .error(let code, let message):
          let error = AlanError.serverError(statusCode: 0, message: "[\(code)] \(message)")
          await notifyError(error)
          return
        }
      }
    } catch let error as AlanError {
      await notifyError(error)
      return
    } catch {
      await notifyError(.networkError(message: error.localizedDescription))
      return
    }

    // Process all subagent requests in parallel.
    if !collectedRequests.isEmpty {
      await processSubagentRequests(collectedRequests)
    }

    // Notify completion.
    await notifyCompletion(tokenMetadata: tokenMetadata)
  }

  // MARK: - Subagent Processing

  // Processes subagent requests in parallel.
  private func processSubagentRequests(_ requests: [SubagentRequest]) async {
    let results = await apiClient.executeSubagentBatch(requests)

    for (requestId, result) in results {
      await handleSubagentResult(requestId: requestId, result: result)
    }
  }

  // Handles a single subagent result.
  private func handleSubagentResult(
    requestId: SubagentRequestID,
    result: Result<SubagentResponse, Error>
  ) async {
    guard let pending = pendingRequests.removeValue(forKey: requestId) else {
      return
    }

    switch result {
    case .success(let response):
      switch response.status {
      case .ready:
        // Block is ready - update placeholder with content.
        if let block = response.block {
          let updatedBlock = Block(
            id: pending.placeholderBlockId,
            type: block.type,
            createdAt: block.createdAt,
            status: .ready,
            content: block.content
          )
          await notifyBlockUpdated(updatedBlock)
        } else {
          // Ready but no block - treat as error.
          let error = SubagentError(code: "no_block", message: "Response ready but no block")
          let errorBlock = BlockFactory.createErrorBlock(
            error: error,
            concept: pending.request.concept,
            id: pending.placeholderBlockId
          )
          await notifyBlockUpdated(errorBlock)
        }

      case .pending:
        // Block is still being generated (async AI generation).
        // The placeholder is already showing; we'll receive an update later.
        // For now, re-add to pending so we can track it.
        pendingRequests[requestId] = pending

      case .failed:
        // Request failed - convert to error block.
        let error = response.error ?? SubagentError(code: "unknown", message: "Unknown error")
        let errorBlock = BlockFactory.createErrorBlock(
          error: error,
          concept: pending.request.concept,
          id: pending.placeholderBlockId
        )
        await notifyBlockUpdated(errorBlock)
      }

    case .failure(let error):
      // Network or other error.
      let subagentError = SubagentError(
        code: "network_error",
        message: error.localizedDescription
      )
      let errorBlock = BlockFactory.createErrorBlock(
        error: subagentError,
        concept: pending.request.concept,
        id: pending.placeholderBlockId
      )
      await notifyBlockUpdated(errorBlock)
    }
  }

  // MARK: - Delegate Notifications

  private func notifyBlockInserted(_ block: Block) async {
    await MainActor.run {
      _delegate?.orchestration(self, didInsertBlock: block)
    }
  }

  private func notifyBlockUpdated(_ block: Block) async {
    await MainActor.run {
      _delegate?.orchestration(self, didUpdateBlock: block)
    }
  }

  private func notifyStreamingText(_ text: String) async {
    await MainActor.run {
      _delegate?.orchestration(self, didReceiveStreamingText: text)
    }
  }

  private func notifySessionModelUpdated(_ model: SessionModel) async {
    await MainActor.run {
      _delegate?.orchestration(self, didUpdateSessionModel: model)
    }
  }

  private func notifyCompletion(tokenMetadata: TokenMetadata?) async {
    await MainActor.run {
      _delegate?.orchestrationDidComplete(self, tokenMetadata: tokenMetadata)
    }
  }

  private func notifyError(_ error: AlanError) async {
    await MainActor.run {
      _delegate?.orchestration(self, didEncounterError: error)
    }
  }

  // MARK: - State Access

  // Returns the number of pending requests.
  var pendingRequestCount: Int {
    pendingRequests.count
  }

  // Cancels all pending requests.
  func cancelAllPendingRequests() {
    pendingRequests.removeAll()
  }
}
