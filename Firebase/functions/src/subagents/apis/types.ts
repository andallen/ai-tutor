// types.ts
// Shared types for external image API clients.

/**
 * Common result type returned by all API clients.
 * Normalized structure regardless of which API provided the image.
 */
export interface APISearchResult {
  // Source identifier
  source: string; // "nasa", "smithsonian", "wikimedia", etc.

  // Image URLs
  image_url: string; // Direct URL to image
  thumbnail_url?: string; // Smaller preview if available

  // Metadata
  title: string;
  description?: string;

  // Attribution (required for proper licensing)
  attribution: {
    source: string; // Human-readable source name (e.g., "NASA")
    url: string; // Link to original item page
    license: string; // "Public Domain", "CC0", "CC BY 4.0", etc.
    author?: string; // Creator if known
  };

  // Optional relevance score for ranking (higher = more relevant)
  relevance_score?: number;
}

/**
 * Interface that all API clients must implement.
 */
export interface ImageAPIClient {
  // Human-readable name for logging
  name: string;

  // Search for images matching the query
  search(query: string, limit?: number): Promise<APISearchResult[]>;
}

/**
 * Configuration for API clients that require authentication.
 */
export interface APIConfig {
  smithsonianApiKey?: string;
}

/**
 * User-Agent header required by some APIs (Wikimedia).
 * Format: AppName/Version (contact email)
 */
export const USER_AGENT = "AlanEducationalApp/1.0 (alan@example.com)";
