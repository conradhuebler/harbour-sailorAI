/*
 * Test configuration loader for JavaScript/QML tests
 * Claude Generated - Configuration management
 */

// Load test configuration
function loadTestConfig() {
    try {
        // Try different possible locations for the configuration
        var configSources = [
            "config/test_providers.json",
            "../config/test_providers.json",
            "../../config/test_providers.json",
            "tests/config/test_providers.json"
        ];

        var config = null;

        // Try to load configuration from different sources
        for (var i = 0; i < configSources.length; i++) {
            try {
                // Different loading methods for different environments
                if (typeof XMLHttpRequest !== 'undefined' && typeof Qt !== 'undefined') {
                    // QML environment
                    var xhr = new XMLHttpRequest();
                    xhr.open("GET", configSources[i], false); // Synchronous for QML
                    xhr.send();

                    if (xhr.status === 200) {
                        config = JSON.parse(xhr.responseText);
                        break;
                    }
                } else if (typeof require !== 'undefined') {
                    // Node.js environment
                    var fs = require('fs');
                    var path = require('path');

                    var configPath = path.resolve(__dirname, configSources[i]);
                    if (fs.existsSync(configPath)) {
                        var configData = fs.readFileSync(configPath, 'utf8');
                        config = JSON.parse(configData);
                        break;
                    }
                } else if (typeof fetch !== 'undefined') {
                    // Browser environment
                    var response = fetch(configSources[i]);
                    if (response.ok) {
                        config = response.json();
                        break;
                    }
                }
            } catch (e) {
                // Keep trying next source
                continue;
            }
        }

        // Provide fallback configuration if loading fails
        if (!config) {
            console.warn("Failed to load test configuration, using fallback");
            config = {
                "api_endpoints": {
                    "gemini": {
                        "name": "Google Gemini",
                        "base_url": "https://generativelanguage.googleapis.com/v1beta/models",
                        "endpoints": {
                            "chat": "/{model}:generateContent",
                            "models": "",
                            "streaming": "/{model}:streamGenerateContent"
                        },
                        "authentication": {
                            "header": "x-goog-api-key",
                            "prefix": ""
                        },
                        "features": {
                            "supportsStreaming": true,
                            "supportsImages": true,
                            "supportsThinking": false
                        },
                        "defaultModels": ["gemini-2.0-flash"],
                        "headers": {
                            "required": ["Content-Type", "x-goog-api-key"],
                            "optional": {}
                        }
                    },
                    "chatai": {
                        "name": "GWDG Academic Cloud ChatAI",
                        "base_url": "https://chat-ai.academiccloud.de/v1",
                        "endpoints": {
                            "chat": "/chat/completions",
                            "models": "/models",
                            "streaming": "/chat/completions"
                        },
                        "authentication": {
                            "header": "Authorization",
                            "prefix": "Bearer "
                        },
                        "features": {
                            "supportsStreaming": true,
                            "supportsImages": false,
                            "supportsThinking": false
                        },
                        "defaultModels": ["gemma-3-27b-it"],
                        "headers": {
                            "required": ["Content-Type", "Authorization"],
                            "optional": {}
                        }
                    }
                },
                "test_providers": {
                    "gemini": {
                        "api_key": "YOUR_GEMINI_API_KEY",
                        "test_models": ["gemini-2.0-flash", "gemini-2.5-pro"],
                        "enabled": true
                    },
                    "chatai": {
                        "api_key": "24b579f8e208d098a1aa3321392429ad",
                        "test_models": ["gemma-3-27b-it", "meta-llama-3.1-8b-instruct"],
                        "enabled": true
                    }
                },
                "test_scenarios": {
                    "basic_chat": {
                        "messages": [
                            {"role": "user", "content": "Hello! Please respond with a simple greeting."}
                        ],
                        "expected_patterns": ["hello", "hi", "greeting"]
                    },
                    "streaming_test": {
                        "messages": [
                            {"role": "user", "content": "Count from 1 to 5 slowly."}
                        ],
                        "streaming_expected": true,
                        "min_chunks": 2
                    }
                }
            };
        }

        return config;

    } catch (error) {
        console.error("Failed to load test configuration:", error);
        return null;
    }
}

// Export for different environments
if (typeof module !== 'undefined' && module.exports) {
    // Node.js
    module.exports = {
        load: loadTestConfig
    };
} else if (typeof Qt !== 'undefined') {
    // QML
    this.TestConfig = {
        load: loadTestConfig
    };
} else {
    // Browser or other
    this.TestConfig = {
        load: loadTestConfig
    };
}