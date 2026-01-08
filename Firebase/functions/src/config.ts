// Shared configuration for Firebase functions.

// The Gemini model to use across all AI operations.
export const GEMINI_MODEL = "gemini-3-flash-preview";

const BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models";

/**
 * Constructs the Gemini API URL for streaming requests.
 * @param {string} apiKey - The Gemini API key.
 * @return {string} The streaming API URL.
 */
export function geminiStreamUrl(apiKey: string): string {
  const action = "streamGenerateContent";
  return `${BASE_URL}/${GEMINI_MODEL}:${action}?alt=sse&key=${apiKey}`;
}

/**
 * Constructs the Gemini API URL for non-streaming requests.
 * @param {string} apiKey - The Gemini API key.
 * @return {string} The generate API URL.
 */
export function geminiGenerateUrl(apiKey: string): string {
  return `${BASE_URL}/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
}
