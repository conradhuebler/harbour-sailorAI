// Embedded test configuration for desktop PoC
// Avoids XHR issues with qrc:// paths in QML

var testConfig = {
    "api_endpoints": {
        "openai": {
            "name": "OpenAI Compatible",
            "type": "openai",
            "base_url": "https://api.openai.com/v1",
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
                "supportsImages": true,
                "supportsThinking": false
            },
            "defaultModels": [],
            "headers": {
                "required": ["Content-Type", "Authorization"],
                "optional": {}
            }
        },
        "anthropic": {
            "name": "Anthropic Claude",
            "type": "anthropic",
            "base_url": "https://api.anthropic.com/v1",
            "endpoints": {
                "chat": "/messages",
                "models": "",
                "streaming": "/messages"
            },
            "authentication": {
                "header": "x-api-key",
                "prefix": ""
            },
            "features": {
                "supportsStreaming": true,
                "supportsImages": true,
                "supportsThinking": true
            },
            "defaultModels": [],
            "headers": {
                "required": ["Content-Type", "x-api-key"],
                "optional": {
                    "anthropic-version": "2023-06-01"
                }
            }
        },
        "gemini": {
            "name": "Google Gemini",
            "type": "gemini",
            "base_url": "https://generativelanguage.googleapis.com/v1beta/models",
            "endpoints": {
                "chat": "{model}:generateContent",
                "models": "",
                "streaming": "{model}:streamGenerateContent"
            },
            "authentication": {
                "header": "x-goog-api-key",
                "prefix": "",
                "urlParam": "key"
            },
            "features": {
                "supportsStreaming": true,
                "supportsImages": true,
                "supportsThinking": true
            },
            "defaultModels": [],
            "headers": {
                "required": ["Content-Type", "x-goog-api-key"],
                "optional": {}
            }
        },
        "ollama": {
            "name": "Ollama",
            "type": "ollama",
            "base_url": "http://127.0.0.1:11434",
            "endpoints": {
                "chat": "/api/chat",
                "models": "/api/tags",
                "streaming": "/api/chat"
            },
            "authentication": {
                "header": "Authorization",
                "prefix": "Bearer "
            },
            "features": {
                "supportsStreaming": true,
                "supportsImages": true,
                "supportsThinking": false
            },
            "defaultModels": [],
            "headers": {
                "required": ["Content-Type"],
                "optional": {}
            }
        }
    }
};