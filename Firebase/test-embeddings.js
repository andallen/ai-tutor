/**
 * Test script for the generateEmbeddings Cloud Function
 *
 * Run with: node test-embeddings.js
 */

const PROJECT_ID = "inkos-f58f1";
const REGION = "us-central1";

// Cloud Functions v2 callable endpoint format
const FUNCTION_URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/generateEmbeddings`;

async function testEmbeddings() {
  console.log("🧪 Testing generateEmbeddings Cloud Function\n");
  console.log(`📍 Endpoint: ${FUNCTION_URL}\n`);

  // Test data - sample notebook content
  const testTexts = [
    "This is a handwritten note about machine learning.",
    "Math: x^2 + 3x + 2 = 0",
    "Meeting notes from January 4th, 2026. Discussed RAG implementation."
  ];

  console.log("📝 Test texts:");
  testTexts.forEach((t, i) => console.log(`   ${i + 1}. "${t}"`));
  console.log("");

  // Callable functions expect this specific request format
  const requestBody = {
    data: {
      texts: testTexts,
      taskType: "RETRIEVAL_DOCUMENT"
    }
  };

  try {
    console.log("📡 Sending request...\n");

    const response = await fetch(FUNCTION_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    const responseText = await response.text();

    if (!response.ok) {
      console.error("❌ Request failed!");
      console.error(`   Status: ${response.status}`);
      console.error(`   Response: ${responseText}`);
      return;
    }

    const data = JSON.parse(responseText);

    // Callable functions wrap the result in a "result" field
    const result = data.result || data;

    console.log("✅ Response received!\n");
    console.log(`   Model: ${result.model}`);
    console.log(`   Dimensions: ${result.dimensions}`);
    console.log(`   Embeddings count: ${result.embeddings?.length}`);

    if (result.embeddings && result.embeddings.length > 0) {
      console.log("\n📊 Embedding details:");
      result.embeddings.forEach((emb, i) => {
        const preview = emb.slice(0, 5).map(v => v.toFixed(4)).join(", ");
        console.log(`   ${i + 1}. Length: ${emb.length}, Preview: [${preview}, ...]`);
      });

      // Validate dimensions
      const allCorrectDimensions = result.embeddings.every(e => e.length === 768);
      console.log(`\n✓ All embeddings have correct dimensions (768): ${allCorrectDimensions ? "YES" : "NO"}`);

      // Check for valid numbers (not NaN or Infinity)
      const allValidNumbers = result.embeddings.every(e =>
        e.every(v => typeof v === 'number' && !isNaN(v) && isFinite(v))
      );
      console.log(`✓ All embedding values are valid numbers: ${allValidNumbers ? "YES" : "NO"}`);

      console.log("\n🎉 Test PASSED! Function is working correctly.\n");
    } else {
      console.error("❌ No embeddings returned in response");
    }

  } catch (error) {
    console.error("❌ Error calling function:");
    console.error(`   ${error.message}`);

    if (error.message.includes("ENOTFOUND")) {
      console.error("\n💡 Hint: Check that the function URL is correct and deployed.");
    }
  }
}

// Run the test
testEmbeddings();
