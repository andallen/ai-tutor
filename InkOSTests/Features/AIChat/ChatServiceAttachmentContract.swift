// ChatServiceAttachmentContract.swift
// Defines the test contract for ChatService attachment integration.
// This contract specifies test scenarios and expected behaviors for file attachment
// handling in sendMessage() and streamMessage() operations.
// Tests verify the ChatService correctly routes messages with attachments through
// the multimodal API path (upload, build multimodal message, send/stream multimodal).

import Foundation

// MARK: - Test Contract Overview

/*
 FEATURE: ChatService Attachment Integration

 ChatService now supports optional file attachments in sendMessage() and streamMessage().
 When an attachment is provided:
 1. Upload the attachment via chatClient.uploadFile()
 2. Build multimodal message array using buildAPIMessagesMultimodal()
 3. Send using chatClient.sendMessageMultimodal() or chatClient.streamMessageMultimodal()

 When no attachment is provided:
 - Use existing text-only path (sendMessage or streamMessage)

 DEPENDENCIES:
 - FileAttachment (from AttachmentContract.swift)
 - UploadedFileReference (from AttachmentContract.swift)
 - APIMessageMultimodal (from MultimodalMessageContract.swift)
 - MockChatClient (from ChatClientTests.swift, has all multimodal methods mocked)
 - MockContextGatherer (from existing tests)
 - MockChatStorage (from existing tests)

 TEST FILE LOCATION:
 InkOSTests/Features/AIChat/ChatServiceAttachmentTests.swift
*/

// MARK: - sendMessage Without Attachment Tests

/*
 SCENARIO: Send message without attachment uses text-only path
 GIVEN: A ChatService with MockChatClient, MockContextGatherer, and MockChatStorage
  AND: MockContextGatherer configured to return empty context
  AND: MockChatClient configured to return "AI response"
 WHEN: sendMessage(text: "Hello", attachment: nil, ...) is called
 THEN: chatClient.uploadFile() is NOT called (uploadFileCallCount == 0)
  AND: chatClient.sendMessage() IS called (sendMessageCallCount == 1)
  AND: chatClient.sendMessageMultimodal() is NOT called (sendMessageMultimodalCallCount == 0)
  AND: The returned ChatMessage contains "AI response"

 SCENARIO: Send message without attachment passes correct APIMessage format
 GIVEN: A ChatService with MockChatClient
  AND: An existing conversation with history
 WHEN: sendMessage(text: "New question", attachment: nil, ...) is called
 THEN: chatClient.sendMessage() receives [APIMessage] array
  AND: Messages are in text-only APIMessage format (not APIMessageMultimodal)
  AND: The last message content matches user text (with context if present)
*/

// MARK: - sendMessage With Attachment Tests

/*
 SCENARIO: Send message with attachment uploads file first
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment (PNG image, 1KB, base64 encoded)
  AND: MockChatClient configured to return UploadedFileReference with fileUri "files/test-123"
 WHEN: sendMessage(text: "What is in this image?", attachment: attachment, ...) is called
 THEN: chatClient.uploadFile() is called BEFORE sendMessageMultimodal()
  AND: uploadFile() receives the exact FileAttachment passed to sendMessage()
  AND: uploadFileCallCount == 1

 SCENARIO: Send message with attachment uses multimodal path
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment
  AND: MockChatClient configured to return UploadedFileReference
  AND: MockChatClient.sendMessageMultimodalResponse = "I see a cat in the image"
 WHEN: sendMessage(text: "Describe this", attachment: attachment, ...) is called
 THEN: chatClient.sendMessageMultimodal() IS called (sendMessageMultimodalCallCount == 1)
  AND: chatClient.sendMessage() is NOT called (sendMessageCallCount == 0)
  AND: The returned ChatMessage.content == "I see a cat in the image"

 SCENARIO: Send message with attachment builds correct multimodal message format
 GIVEN: A ChatService with MockChatClient
  AND: FileAttachment with mimeType .png
  AND: MockChatClient returns UploadedFileReference(fileUri: "files/abc", mimeType: "image/png", ...)
 WHEN: sendMessage(text: "What is this?", attachment: attachment, ...) is called
 THEN: chatClient.sendMessageMultimodal() receives [APIMessageMultimodal] array
  AND: The last message (user's new message) has role "user"
  AND: The last message has parts array with 2 elements
  AND: parts[0] is .fileData with fileUri "files/abc" and mimeType "image/png"
  AND: parts[1] is .text containing the user's text (with context if present)

 SCENARIO: Send message with attachment preserves conversation history
 GIVEN: A ChatService with MockChatClient and MockChatStorage
  AND: An existing conversation with 3 messages (user, assistant, user)
  AND: A new FileAttachment
 WHEN: sendMessage(text: "New message", attachment: attachment, conversationID: "conv-1", ...) is called
 THEN: chatClient.sendMessageMultimodal() receives all messages
  AND: Older messages are converted to text-only APIMessageMultimodal format
  AND: Only the newest user message contains the file attachment parts
  AND: Message order is preserved (chronological)

 SCENARIO: Send message with attachment strips context from old user messages
 GIVEN: A ChatService with configured mocks
  AND: An existing conversation where old user messages have embedded context
  AND: A new FileAttachment
 WHEN: sendMessage() is called with attachment
 THEN: Older user messages have context stripped (extractUserTextFromMessage applied)
  AND: Only raw user text is included in conversation history
  AND: Token budget is respected
*/

// MARK: - streamMessage Without Attachment Tests

/*
 SCENARIO: Stream message without attachment uses text-only path
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.streamMessageChunks = ["Hello", " there"]
 WHEN: streamMessage(text: "Hi", attachment: nil, ...) is called
 THEN: chatClient.uploadFile() is NOT called (uploadFileCallCount == 0)
  AND: chatClient.streamMessage() IS called (streamMessageCallCount == 1)
  AND: chatClient.streamMessageMultimodal() is NOT called (streamMessageMultimodalCallCount == 0)
  AND: The returned stream yields "Hello", " there" in order

 SCENARIO: Stream message without attachment returns user message immediately
 GIVEN: A ChatService with MockChatClient
 WHEN: streamMessage(text: "Question", attachment: nil, ...) is called
 THEN: The returned tuple contains userMessage with role .user
  AND: userMessage.content contains "Question"
  AND: userMessage is already saved to storage
*/

// MARK: - streamMessage With Attachment Tests

/*
 SCENARIO: Stream message with attachment uploads file first
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment (PDF, 5KB)
  AND: MockChatClient returns UploadedFileReference
 WHEN: streamMessage(text: "Summarize this document", attachment: attachment, ...) is called
 THEN: chatClient.uploadFile() is called BEFORE streamMessageMultimodal()
  AND: uploadFile() receives the FileAttachment
  AND: uploadFileCallCount == 1

 SCENARIO: Stream message with attachment uses multimodal streaming path
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment
  AND: MockChatClient.streamMessageMultimodalChunks = ["Summary: ", "This document ", "contains..."]
 WHEN: streamMessage(text: "Summarize", attachment: attachment, ...) is called
 THEN: chatClient.streamMessageMultimodal() IS called (streamMessageMultimodalCallCount == 1)
  AND: chatClient.streamMessage() is NOT called (streamMessageCallCount == 0)
  AND: The returned stream yields ["Summary: ", "This document ", "contains..."]

 SCENARIO: Stream message with attachment builds correct multimodal format
 GIVEN: A ChatService with MockChatClient
  AND: FileAttachment with mimeType .pdf
  AND: MockChatClient returns UploadedFileReference(fileUri: "files/pdf-doc", mimeType: "application/pdf", ...)
 WHEN: streamMessage(text: "Analyze", attachment: attachment, ...) is called
 THEN: chatClient.streamMessageMultimodal() receives [APIMessageMultimodal] array
  AND: The last message has parts[0] as .fileData(fileUri: "files/pdf-doc", mimeType: "application/pdf")
  AND: The last message has parts[1] as .text containing user text

 SCENARIO: Stream message with attachment saves user message before streaming
 GIVEN: A ChatService with MockChatClient and MockChatStorage
  AND: A valid FileAttachment
 WHEN: streamMessage(text: "What is this?", attachment: attachment, ...) is called
 THEN: storage.addMessage() is called with user message
  AND: User message is saved BEFORE streaming begins
  AND: The returned userMessage has the same ID as the stored message
*/

// MARK: - Upload Error Propagation Tests

/*
 SCENARIO: sendMessage propagates uploadFile network error
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileError = ChatError.networkError(reason: "Connection failed")
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Test", attachment: attachment, ...) is called
 THEN: ChatError.networkError is thrown
  AND: chatClient.sendMessageMultimodal() is NOT called
  AND: The user message is still saved to storage (before upload attempt)

 SCENARIO: sendMessage propagates uploadFile uploadFailed error
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileError = ChatError.uploadFailed(reason: "Server rejected file")
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Test", attachment: attachment, ...) is called
 THEN: ChatError.uploadFailed(reason: "Server rejected file") is thrown
  AND: The exact error from uploadFile() propagates unchanged

 SCENARIO: sendMessage propagates uploadFile processingFailed error
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileError = ChatError.processingFailed(filename: "test.pdf")
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Test", attachment: attachment, ...) is called
 THEN: ChatError.processingFailed(filename: "test.pdf") is thrown

 SCENARIO: sendMessage propagates uploadFile processingTimeout error
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileError = ChatError.processingTimeout(filename: "large.pdf")
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Test", attachment: attachment, ...) is called
 THEN: ChatError.processingTimeout(filename: "large.pdf") is thrown

 SCENARIO: streamMessage propagates uploadFile errors
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileError = ChatError.uploadFailed(reason: "Quota exceeded")
  AND: A valid FileAttachment
 WHEN: streamMessage(text: "Test", attachment: attachment, ...) is called
 THEN: ChatError.uploadFailed(reason: "Quota exceeded") is thrown
  AND: chatClient.streamMessageMultimodal() is NOT called
  AND: No stream is returned (error thrown before stream creation)
*/

// MARK: - Multimodal Message Format Tests

/*
 SCENARIO: File reference appears first in parts array
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment
  AND: MockChatClient returns UploadedFileReference
 WHEN: sendMessage(text: "Analyze this", attachment: attachment, ...) is called
 THEN: The APIMessageMultimodal parts array has file data at index 0
  AND: Text content is at index 1
  AND: This order matches Gemini API expectations (file first, then query)

 SCENARIO: File data part contains correct URI from upload response
 GIVEN: A ChatService with MockChatClient
  AND: MockChatClient.uploadFileResponse = UploadedFileReference(
         fileUri: "https://generativelanguage.googleapis.com/v1/files/unique-id-123",
         mimeType: "image/jpeg",
         name: "files/unique-id-123",
         expiresAt: "2024-12-31T23:59:59Z"
       )
  AND: A FileAttachment with mimeType .jpeg
 WHEN: sendMessage(text: "What is this?", attachment: attachment, ...) is called
 THEN: The APIMessageMultimodal parts[0] is .fileData
  AND: fileData.fileUri == "https://generativelanguage.googleapis.com/v1/files/unique-id-123"
  AND: fileData.mimeType == "image/jpeg"

 SCENARIO: Text part contains user message with context
 GIVEN: A ChatService with MockChatClient and MockContextGatherer
  AND: MockContextGatherer returns GatheredContext with text "Context: Meeting notes..."
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Summarize based on my notes", attachment: attachment, ...) is called
 THEN: The APIMessageMultimodal text part contains both context and user text
  AND: Format is "{context}\n\n---\n\nUser: {userText}"
  AND: This matches existing context embedding behavior

 SCENARIO: Text part contains only user text when context is empty
 GIVEN: A ChatService with MockChatClient and MockContextGatherer
  AND: MockContextGatherer returns empty GatheredContext (scope .chatOnly)
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Describe the image", attachment: attachment, ...) is called
 THEN: The APIMessageMultimodal text part contains only "Describe the image"
  AND: No context separator is present

 SCENARIO: Historical messages in multimodal array are text-only
 GIVEN: A ChatService with MockChatClient and MockChatStorage
  AND: Existing conversation with [user-msg-1, assistant-msg-1, user-msg-2]
  AND: A new FileAttachment for the current message
 WHEN: sendMessage(text: "New question", attachment: attachment, conversationID: "conv-1", ...) is called
 THEN: chatClient.sendMessageMultimodal() receives 4 APIMessageMultimodal messages
  AND: Messages 0-2 each have a single .text part (no file data)
  AND: Message 3 (newest) has [.fileData, .text] parts
*/

// MARK: - Token Budget Integration Tests

/*
 SCENARIO: Attachment token cost is included in budget calculation
 GIVEN: A ChatService with MockChatClient
  AND: A conversation history near the token limit
  AND: A new FileAttachment (adds ~258 tokens for images)
 WHEN: sendMessage(text: "Question", attachment: attachment, ...) is called
 THEN: The token budget calculation includes attachment cost
  AND: Some older messages may be excluded to fit within budget
  AND: Newer messages are prioritized over older ones

 SCENARIO: Large attachment does not cause crash
 GIVEN: A ChatService with MockChatClient
  AND: A FileAttachment representing a 50MB PDF
  AND: MockChatClient configured to succeed
 WHEN: sendMessage(text: "Summarize", attachment: attachment, ...) is called
 THEN: Upload and send complete without crash
  AND: Token estimation uses AttachmentTokenEstimation constants
*/

// MARK: - Edge Cases

/*
 EDGE CASE: Empty text with attachment
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "", attachment: attachment, ...) is called
 THEN: ChatError.invalidRequest(reason: "Message text cannot be empty") is thrown
  AND: uploadFile() is NOT called
  AND: Empty text validation occurs before attachment processing

 EDGE CASE: Whitespace-only text with attachment
 GIVEN: A ChatService with MockChatClient
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "   \n\t  ", attachment: attachment, ...) is called
 THEN: ChatError.invalidRequest is thrown
  AND: Text is trimmed and detected as empty
  AND: uploadFile() is NOT called

 EDGE CASE: Conversation not found with attachment
 GIVEN: A ChatService with MockChatStorage
  AND: MockChatStorage.getConversation returns nil for "invalid-conv"
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "Test", attachment: attachment, conversationID: "invalid-conv", ...) is called
 THEN: ChatError.conversationNotFound(conversationID: "invalid-conv") is thrown
  AND: uploadFile() is NOT called
  AND: Conversation validation occurs before attachment processing

 EDGE CASE: New conversation created when conversationID is nil
 GIVEN: A ChatService with MockChatClient and MockChatStorage
  AND: A valid FileAttachment
 WHEN: sendMessage(text: "First message", attachment: attachment, conversationID: nil, ...) is called
 THEN: storage.createConversation() is called
  AND: A new conversation is created
  AND: Upload and multimodal send proceed normally
  AND: Messages are stored in the new conversation

 EDGE CASE: Attachment with all MIME types works
 GIVEN: A ChatService with MockChatClient configured to succeed
 FOR EACH mimeType IN [.png, .jpeg, .webp, .heic, .heif, .gif, .pdf, .plainText]:
   WHEN: sendMessage(text: "Test", attachment: FileAttachment(mimeType: mimeType, ...), ...) is called
   THEN: Upload and send complete successfully
    AND: The correct mimeType string is included in APIFileData

 EDGE CASE: Multiple sequential messages with attachments
 GIVEN: A ChatService with MockChatClient
  AND: An existing conversation
 WHEN: sendMessage with attachment is called 3 times in sequence
 THEN: Each call uploads its own attachment
  AND: uploadFileCallCount == 3
  AND: Each subsequent message includes the growing history
  AND: Only the newest message in each call has file attachment parts

 EDGE CASE: Concurrent attachment uploads
 GIVEN: A ChatService with MockChatClient
  AND: Two different FileAttachments
 WHEN: Two sendMessage calls with attachments are made concurrently (different conversations)
 THEN: Both uploads complete without interference
  AND: Actor isolation ensures thread safety
  AND: uploadFileCallCount == 2
*/

// MARK: - Test Helpers

/*
 HELPER: createTestAttachment(mimeType:sizeBytes:)
 Creates a FileAttachment for testing with specified MIME type and size.
 Uses synthetic base64 data.

 HELPER: createTestUploadedFileReference(fileUri:mimeType:)
 Creates an UploadedFileReference for configuring MockChatClient responses.

 HELPER: assertMultimodalMessageFormat(messages:expectedFileUri:expectedMimeType:expectedUserText:)
 Verifies the structure of APIMessageMultimodal array matches expected format.

 HELPER: extractFileDataFromMessage(message:)
 Extracts the APIFileData from an APIMessageMultimodal for verification.

 HELPER: extractTextFromMessage(message:)
 Extracts the text content from an APIMessageMultimodal for verification.
*/

// MARK: - Test Fixture Requirements

/*
 FIXTURE: MockChatClient must support:
 - uploadFile(_ attachment: FileAttachment) async throws -> UploadedFileReference
 - uploadFileCallCount: Int
 - uploadFileCalls: [FileAttachment]
 - uploadFileResponse: UploadedFileReference?
 - uploadFileError: Error?
 - sendMessageMultimodal(messages: [APIMessageMultimodal]) async throws -> String
 - sendMessageMultimodalCallCount: Int
 - sendMessageMultimodalCalls: [[APIMessageMultimodal]]
 - sendMessageMultimodalResponse: String
 - sendMessageMultimodalError: Error?
 - streamMessageMultimodal(messages: [APIMessageMultimodal]) -> AsyncThrowingStream<String, Error>
 - streamMessageMultimodalCallCount: Int
 - streamMessageMultimodalCalls: [[APIMessageMultimodal]]
 - streamMessageMultimodalChunks: [String]
 - streamMessageMultimodalError: Error?

 FIXTURE: MockContextGatherer must support:
 - gatherContext(scope:currentNoteID:currentFolderID:) async throws -> GatheredContext
 - Configurable to return empty or populated context

 FIXTURE: MockChatStorage must support:
 - createConversation(initialScope:) -> ChatConversation
 - getConversation(id:) -> ChatConversation?
 - addMessage(_ message: ChatMessage)
 - getMessages(conversationID:) -> [ChatMessage]
*/

// MARK: - Test Organization

/*
 TEST SUITE STRUCTURE:

 @Suite("ChatService Attachment Integration Tests")
 struct ChatServiceAttachmentTests {

   @Suite("sendMessage Without Attachment")
   struct SendWithoutAttachmentTests {
     // Tests for nil attachment path
   }

   @Suite("sendMessage With Attachment")
   struct SendWithAttachmentTests {
     // Tests for attachment upload and multimodal path
   }

   @Suite("streamMessage Without Attachment")
   struct StreamWithoutAttachmentTests {
     // Tests for nil attachment streaming path
   }

   @Suite("streamMessage With Attachment")
   struct StreamWithAttachmentTests {
     // Tests for attachment upload and multimodal streaming path
   }

   @Suite("Upload Error Propagation")
   struct UploadErrorTests {
     // Tests for error handling from uploadFile
   }

   @Suite("Multimodal Message Format")
   struct MessageFormatTests {
     // Tests for correct APIMessageMultimodal structure
   }

   @Suite("Edge Cases")
   struct EdgeCaseTests {
     // Tests for boundary conditions and special scenarios
   }
 }
*/
