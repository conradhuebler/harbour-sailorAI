# Basic Integration Example
# Claude Generated - Simple API abstraction usage example

// Include the API abstraction layer
Qt.include("src/js/ConfigLoader.js")
Qt.include("src/js/ApiAbstraction.js")

// Basic usage example
function demonstrateBasicUsage() {
    console.log("=== Basic API Abstraction Example ===");

    // 1. Load configuration
    var config = loadConfig("config/api_endpoints.json");
    if (!config) {
        console.error("Failed to load configuration");
        return;
    }

    // 2. Create API abstraction instance
    var api = new ApiAbstraction(config);
    console.log("Available providers:", api.getProviderIds());

    // 3. Check provider features
    var supportsStreaming = api.supportsFeature("openai", "supportsStreaming");
    var supportsImages = api.supportsFeature("openai", "supportsImages");
    console.log("OpenAI supports streaming:", supportsStreaming);
    console.log("OpenAI supports images:", supportsImages);

    // 4. Build a request
    var messages = [
        {role: "user", message: "Hello! Can you help me with something?"}
    ];

    var request = api.buildRequest("openai", "gpt-4", messages, {
        apiKey: "your-api-key-here",
        streaming: false
    });

    if (request) {
        console.log("Request URL:", request.url);
        console.log("Request method:", request.method);
        console.log("Request headers:", Object.keys(request.headers));
        console.log("Request data preview:", request.data.substring(0, 100) + "...");

        // 5. Send the request (with mock callbacks)
        api.sendRequest(request, function(response) {
            console.log("Success! Response:", response);
        }, function(error) {
            console.error("Error:", error);
        });
    }
}

// Example: Testing different providers
function demonstrateMultipleProviders() {
    console.log("=== Multiple Provider Example ===");

    var config = loadConfig("config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    var providers = ["openai", "anthropic", "gemini", "ollama"];
    var testMessage = {role: "user", message: "Hello from multiple providers!"};

    providers.forEach(function(providerId) {
        var request = api.buildRequest(providerId, "default-model", [testMessage], {
            apiKey: "test-key"
        });

        if (request) {
            console.log(providerId + " URL:", request.url);
            console.log(providerId + " Auth header:", request.headers);

            // Test different features
            console.log(providerId + " streaming:", api.supportsFeature(providerId, "supportsStreaming"));
            console.log(providerId + " images:", api.supportsFeature(providerId, "supportsImages"));
            console.log(providerId + " thinking:", api.supportsFeature(providerId, "supportsThinking"));
        }
    });
}

// Example: Model fetching
function demonstrateModelFetching() {
    console.log("=== Model Fetching Example ===");

    var config = loadConfig("config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    var providerId = "openai";

    // Get models URL
    var modelsUrl = api.getModelsUrl(providerId);
    console.log("Models URL:", modelsUrl);

    // Fetch models (would need real API key for actual call)
    api.fetchModels(providerId, "test-api-key", function(models) {
        console.log("Available models:", models);
    }, function(error) {
        console.log("Models fetch error:", error);
    });
}

// Example: Streaming request
function demonstrateStreaming() {
    console.log("=== Streaming Example ===");

    var config = loadConfig("config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    var messages = [
        {role: "user", message: "Tell me a story about programming"}
    ];

    var request = api.buildRequest("openai", "gpt-4", messages, {
        apiKey: "your-api-key",
        streaming: true
    });

    if (request) {
        console.log("Setting up streaming request...");

        api.sendRequest(request,
            function(finalResponse) {
                console.log("Streaming completed!");
            },
            function(error) {
                console.error("Streaming error:", error);
            },
            function(streamChunk) {
                // This callback gets called for each streaming chunk
                console.log("Stream chunk:", streamChunk);
            }
        );
    }
}

// Example: Custom provider addition
function demonstrateCustomProvider() {
    console.log("=== Custom Provider Example ===");

    var config = loadConfig("config/api_endpoints.json");

    // Add a custom provider to the configuration
    var customProvider = {
        "name": "My Custom API",
        "base_url": "https://api.mycustom.com/v1",
        "endpoints": {
            "chat": "/chat/completions",
            "models": "/models",
            "streaming": "/chat/completions/stream"
        },
        "authentication": {
            "header": "X-API-Key",
            "prefix": ""
        },
        "features": {
            "supportsStreaming": true,
            "supportsImages": false,
            "supportsThinking": false
        },
        "defaultModels": ["custom-model-1", "custom-model-2"],
        "headers": {
            "required": ["Content-Type", "X-API-Key"],
            "optional": {
                "X-Custom-Header": "custom-value"
            }
        }
    };

    // This would require modifying the actual config file or
    // extending the API to support runtime provider addition
    console.log("Custom provider structure:", customProvider);
}

// Example: Error handling
function demonstrateErrorHandling() {
    console.log("=== Error Handling Example ===");

    var config = loadConfig("config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    // Test invalid provider
    var invalidRequest = api.buildRequest("invalid-provider", "model", []);
    if (!invalidRequest) {
        console.log("✓ Invalid provider correctly rejected");
    }

    // Test missing API key (for providers that require it)
    var requestNoKey = api.buildRequest("openai", "gpt-4", [{role: "user", message: "test"}]);
    if (requestNoKey) {
        console.log("✓ Request built without API key (but should fail on send)");
    }

    // Test configuration validation
    var validConfig = validateConfig(config);
    console.log("Configuration validation:", validConfig);
}

// Run all examples
function runAllExamples() {
    console.log("Running API Abstraction Examples");
    console.log("==================================");

    try {
        demonstrateBasicUsage();
        console.log("");
        demonstrateMultipleProviders();
        console.log("");
        demonstrateModelFetching();
        console.log("");
        demonstrateStreaming();
        console.log("");
        demonstrateCustomProvider();
        console.log("");
        demonstrateErrorHandling();
    } catch (e) {
        console.error("Example execution error:", e.toString());
    }

    console.log("==================================");
    console.log("Examples completed");
}

// Export functions for external use
if (typeof exports !== 'undefined') {
    exports.demonstrateBasicUsage = demonstrateBasicUsage;
    exports.demonstrateMultipleProviders = demonstrateMultipleProviders;
    exports.demonstrateModelFetching = demonstrateModelFetching;
    exports.demonstrateStreaming = demonstrateStreaming;
    exports.demonstrateCustomProvider = demonstrateCustomProvider;
    exports.demonstrateErrorHandling = demonstrateErrorHandling;
    exports.runAllExamples = runAllExamples;
}