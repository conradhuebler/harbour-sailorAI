// JavaScript API Tests
// Claude Generated - JavaScript testing for API abstraction with QML compatibility

.pragma library

// Include API abstraction components for testing
Qt.include("../../src/js/ConfigLoader.js")
Qt.include("../../src/js/EndpointBuilder.js")
Qt.include("../../src/js/ApiAbstraction.js")

// Test framework
var testResults = {
    total: 0,
    passed: 0,
    failed: 0,
    failures: []
};

function assert(condition, message) {
    testResults.total++;
    if (condition) {
        testResults.passed++;
        console.log("✓ PASS: " + message);
        return true;
    } else {
        testResults.failed++;
        var failure = "✗ FAIL: " + message;
        testResults.failures.push(failure);
        console.log(failure);
        return false;
    }
}

function assertEqual(actual, expected, message) {
    return assert(actual === expected, message + " (Expected: " + expected + ", Actual: " + actual + ")");
}

function assertEqualStrings(actual, expected, message) {
    return assert(actual === expected, message + " (Expected: '" + expected + "', Actual: '" + actual + "')");
}

// Test Suite: Configuration Loading
function testConfigurationLoading() {
    console.log("=== Configuration Loading Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");
    assert(config !== null, "Configuration should load successfully");
    assert(config.api_endpoints, "Configuration should have api_endpoints property");

    var providerIds = getProviderIds(config);
    assert(Array.isArray(providerIds), "Provider IDs should be an array");
    assert(providerIds.length > 0, "Should have at least one provider");

    // Test specific expected providers
    assert(providerIds.indexOf("openai") !== -1, "Should include OpenAI provider");
    assert(providerIds.indexOf("anthropic") !== -1, "Should include Anthropic provider");
    assert(providerIds.indexOf("gemini") !== -1, "Should include Gemini provider");
    assert(providerIds.indexOf("ollama") !== -1, "Should include Ollama provider");
}

// Test Suite: Provider Configuration
function testProviderConfiguration() {
    console.log("=== Provider Configuration Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    for (var i = 0; i < getProviderIds(config).length; i++) {
        var providerId = getProviderIds(config)[i];
        var provider = getProvider(config, providerId);

        assert(provider !== null, "Provider '" + providerId + "' should be valid");

        assert(provider.name, "Provider should have name");
        assert(provider.base_url, "Provider should have base_url");
        assert(provider.endpoints, "Provider should have endpoints");
        assert(provider.authentication, "Provider should have authentication");
        assert(provider.features, "Provider should have features");
        assert(provider.defaultModels, "Provider should have defaultModels");
        assert(provider.headers, "Provider should have headers");

        // Test endpoints structure
        var endpoints = provider.endpoints;
        assert(endpoints.chat, "Provider should have chat endpoint");
        assert(endpoints.models, "Provider should have models endpoint");
        assert(endpoints.streaming, "Provider should have streaming endpoint");

        // Test authentication structure
        var auth = provider.authentication;
        assert(auth.header, "Provider should have auth header");
        assert(typeof auth.prefix === 'string', "Provider should have auth prefix");

        // Test features structure
        var features = provider.features;
        assert(typeof features.supportsStreaming === 'boolean', "Provider should have streaming feature flag");
        assert(typeof features.supportsImages === 'boolean', "Provider should have images feature flag");
        assert(typeof features.supportsThinking === 'boolean', "Provider should have thinking feature flag");
    }
}

// Test Suite: Endpoint Building
function testEndpointBuilding() {
    console.log("=== Endpoint Building Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    // Test OpenAI endpoints
    var openai = getProvider(config, "openai");
    var openaiChat = buildEndpointUrl(openai, "chat");
    assertEqualStrings(openaiChat, "https://api.openai.com/v1/chat/completions", "OpenAI chat URL should be correct");

    var openaiModels = buildEndpointUrl(openai, "models");
    assertEqualStrings(openaiModels, "https://api.openai.com/v1/models", "OpenAI models URL should be correct");

    // Test Gemini endpoints with variable substitution
    var gemini = getProvider(config, "gemini");
    var geminiChat = buildEndpointUrl(gemini, "chat", {model: "gemini-pro"});
    assertEqualStrings(geminiChat, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent", "Gemini chat URL should substitute model variable");

    var geminiModels = buildEndpointUrl(gemini, "models");
    assertEqualStrings(geminiModels, "https://generativelanguage.googleapis.com/v1beta/models", "Gemini models URL should use base URL for empty endpoint");

    // Test Anthropic endpoints
    var anthropic = getProvider(config, "anthropic");
    var anthropicChat = buildEndpointUrl(anthropic, "chat");
    assert(anthropicChat.indexOf("anthropic.com") !== -1, "Anthropic URL should contain anthropic.com");
}

// Test Suite: Authentication Headers
function testAuthenticationHeaders() {
    console.log("=== Authentication Header Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    // Test OpenAI authentication
    var openai = getProvider(config, "openai");
    var openaiAuth = buildAuthHeader(openai, "test-api-key");
    assertEqualStrings(openaiAuth.name, "Authorization", "OpenAI should use Authorization header");
    assertEqualStrings(openaiAuth.value, "Bearer test-api-key", "OpenAI should use Bearer prefix");

    // Test Gemini authentication
    var gemini = getProvider(config, "gemini");
    var geminiAuth = buildAuthHeader(gemini, "test-api-key");
    assertEqualStrings(geminiAuth.name, "x-goog-api-key", "Gemini should use x-goog-api-key header");
    assertEqualStrings(geminiAuth.value, "test-api-key", "Gemini should not use prefix");

    // Test header building
    var openaiHeaders = buildHeaders(openai, "test-api-key");
    assert(openaiHeaders["Content-Type"] === "application/json", "Should include Content-Type header");
    assert(openaiHeaders.Authorization === "Bearer test-api-key", "Should include Authorization header");
}

// Test Suite: Feature Detection
function testFeatureDetection() {
    console.log("=== Feature Detection Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    // Test specific features
    assert(supportsFeature(config, "openai", "supportsStreaming") === true, "OpenAI should support streaming");
    assert(supportsFeature(config, "openai", "supportsImages") === true, "OpenAI should support images");
    assert(supportsFeature(config, "anthropic", "supportsImages") === false, "Anthropic should not support images");
    assert(supportsFeature(config, "gemini", "supportsImages") === true, "Gemini should support images");
    assert(supportsFeature(config, "ollama", "supportsImages") === false, "Ollama should not support images");

    // Test provider-specific feature detection
    var openai = getProvider(config, "openai");
    assert(supportsStreaming(openai) === true, "Openai provider should support streaming");
    assert(supportsImages(openai) === true, "Openai provider should support images");
    assert(supportsThinking(openai) === false, "Openai provider should not support thinking");
}

// Test Suite: Request Building
function testRequestBuilding() {
    console.log("=== Request Building Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    // Test OpenAI request building
    var messages = [
        {role: "user", message: "Hello, world!"}
    ];

    var openaiRequest = api.buildRequest("openai", "gpt-4", messages, {
       apiKey: "test-key",
        streaming: true
    });

    assert(openaiRequest !== null, "OpenAI request should be built successfully");
    assert(openaiRequest.method === "POST", "Request method should be POST");
    assert(openaiRequest.url.indexOf("chat/completions") !== -1, "URL should include chat completions endpoint");
    assert(openaiRequest.headers.Authorization === "Bearer test-key", "Should include proper auth header");
    assert(openaiRequest.data.indexOf("\"model\":\"gpt-4\"") !== -1, "Should include model in request data");

    // Test Gemini request building
    var geminiRequest = api.buildRequest("gemini", "gemini-pro", messages, {
        apiKey: "test-key"
    });

    assert(geminiRequest !== null, "Gemini request should be built successfully");
    assert(geminiRequest.url.indexOf("gemini-pro:generateContent") !== -1, "URL should include model and endpoint");
    assert(geminiRequest.headers["x-goog-api-key"] === "test-key", "Should include Gemini auth header");
}

// Test Suite: Request Data
function testRequestData() {
    console.log("=== Request Data Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    // Test OpenAI request data
    var openai = getProvider(config, "openai");
    var messages = [
        {role: "user", message: "Hello!"},
        {role: "bot", message: "Hi there!"}
    ];

    var openaiData = buildRequestData(openai, "gpt-4", messages, {});
    assert(openaiData.model === "gpt-4", "Should include model");
    assert(Array.isArray(openaiData.messages), "Should include messages array");
    assert(openaiData.messages.length === 2, "Should include correct message count");
    assert(openaiData.messages[0].role === "user", "First message should be from user");
    assert(openaiData.messages[1].role === "assistant", "Bot messages should be converted to assistant");

    // Test Gemini request data
    var gemini = getProvider(config, "gemini");
    var geminiData = buildRequestData(gemini, "gemini-pro", messages, {});
    assert(geminiData.contents, "Should have contents for Gemini");
    assert(Array.isArray(geminiData.contents), "Contents should be array");
    assert(geminiData.contents[0].role === "user", "First content should be user");
    assert(geminiData.contents[1].role === "model", "Bot messages should be converted to model");
}

// Test Suite: Error Handling
function testErrorHandling() {
    console.log("=== Error Handling Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");
    var api = new ApiAbstraction(config);

    // Test invalid provider
    var invalidRequest = api.buildRequest("invalid_provider", "model", []);
    assert(invalidRequest === null, "Invalid provider should return null");

    // Test missing model
    var noModelRequest = api.buildRequest("openai", "", []);
    assert(noModelRequest !== null, "Should handle missing model gracefully");

    // Test invalid configuration
    var invalidConfig = validateConfig(null);
    assert(invalidConfig === false, "Should reject null configuration");

    var emptyConfig = validateConfig({});
    assert(emptyConfig === false, "Should reject empty configuration");

    var noEndpointsConfig = validateConfig({api_endpoints: {}});
    assert(noEndpointsConfig === true, "Should accept minimal valid configuration");
}

// Test Suite: Edge Cases
function testEdgeCases() {
    console.log("=== Edge Case Tests ===");

    var config = loadConfig("../../config/api_endpoints.json");

    // Test variable substitution
    var provider = getProvider(config, "gemini");
    var endpoint = provider.endpoints.chat;
    var substituted = substituteVariables(endpoint, {model: "test-model"});
    assertEqualStrings(substituted, "test-model:generateContent", "Variable substitution should work");

    // Test empty substitution
    var noSubs = substituteVariables(endpoint, {});
    assertEqualStrings(noSubs, endpoint, "No substitution should preserve original");

    // Test multiple substitutions
    var multiTemplate = "{model}/{action}/{version}";
    var multiSubs = substituteVariables(multiTemplate, {
        model: "test",
        action: "generate",
        version: "v1"
    });
    assertEqualStrings(multiSubs, "test/generate/v1", "Multiple substitutions should work");

    // Test default models
    var openaiModels = getDefaultModels(config, "openai");
    assert(Array.isArray(openaiModels), "Default models should be array");
    assert(openaiModels.length > 0, "OpenAI should have default models");

    var emptyModels = getDefaultModels(config, "invalid");
    assertEqual(emptyModels.length, 0, "Invalid provider should return empty models array");
}

// Test Suite: Cache Functionality
function testCacheFunctionality() {
    console.log("=== Cache Functionality Tests ===");

    var configPath = "../../config/api_endpoints.json";

    // Load configuration twice - second should come from cache
    var config1 = loadConfig(configPath);
    var config2 = loadConfig(configPath);

    assert(config1 !== null, "First load should succeed");
    assert(config2 !== null, "Second load should succeed");
    assert(config1 === config2, "Second load should return cached object");

    // Test cache clearing
    clearCache(configPath);
    var config3 = loadConfig(configPath);
    // Note: In actual testing environment, we can't easily test if cache was cleared
    assert(config3 !== null, "Load after cache clear should succeed");

    // Test reload
    var config4 = reloadConfig(configPath);
    assert(config4 !== null, "Reload should succeed");
}

// Test Suite: Configuration Validation
function testConfigurationValidation() {
    console.log("=== Configuration Validation Tests ===");

    var validConfig = {
        api_endpoints: {
            test_provider: {
                name: "Test Provider",
                base_url: "https://api.test.com",
                endpoints: {
                    chat: "/chat",
                    models: "/models",
                    streaming: "/stream"
                },
                authentication: {
                    header: "Authorization",
                    prefix: "Bearer "
                },
                features: {
                    supportsStreaming: true,
                    supportsImages: false,
                    supportsThinking: false
                },
                defaultModels: ["test-model"],
                headers: {
                    required: ["Content-Type"],
                    optional: {}
                }
            }
        }
    };

    assert(validateConfig(validConfig) === true, "Valid configuration should pass validation");

    // Test missing required properties
    var invalidConfig = {
        api_endpoints: {
            test_provider: {
                name: "Test Provider"
                // Missing other required properties
            }
        }
    };

    assert(validateConfig(invalidConfig) === false, "Invalid configuration should fail validation");
}

// Master test runner
function runAllTests() {
    console.log("Starting API Abstraction Layer JavaScript Tests");
    console.log("=================================================");

    // Reset test results
    testResults = {
        total: 0,
        passed: 0,
        failed: 0,
        failures: []
    };

    // Run all test suites
    try {
        testConfigurationLoading();
        testProviderConfiguration();
        testEndpointBuilding();
        testAuthenticationHeaders();
        testFeatureDetection();
        testRequestBuilding();
        testRequestData();
        testErrorHandling();
        testEdgeCases();
        testCacheFunctionality();
        testConfigurationValidation();
    } catch (e) {
        console.log("Test execution error: " + e.toString());
        testResults.failed++;
        testResults.failures.push("EXECUTION ERROR: " + e.toString());
    }

    // Print results
    console.log("=================================================");
    console.log("                  TEST SUMMARY");
    console.log("=================================================");
    console.log("Total tests: " + testResults.total);
    console.log("Passed: " + testResults.passed);
    console.log("Failed: " + testResults.failed);

    if (testResults.failures.length > 0) {
        console.log("");
        console.log("FAILURES:");
        for (var i = 0; i < testResults.failures.length; i++) {
            console.log("  " + testResults.failures[i]);
        }
    }

    console.log("=================================================");

    if (testResults.failed === 0) {
        console.log("All tests passed! ✓");
        return true;
    } else {
        console.log("Some tests failed! ✗");
        return false;
    }
}