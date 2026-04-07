# API Abstraction Layer

## Project Overview

A flexible, provider-agnostic REST API abstraction layer that enables seamless switching between different LLM providers through interchangeable JSON configuration. Support for OpenAI, Anthropic, Google Gemini, Ollama and custom providers with comprehensive testing across Python, Bash, and QML/JavaScript environments.

## Architecture

### Core Components

- **config/api_endpoints.json**: Central configuration defining all supported providers
- **src/js/ApiAbstraction.js**: JavaScript implementation with QML compatibility
- **src/js/ConfigLoader.js**: Configuration loading and validation utilities
- **src/js/EndpointBuilder.js**: Dynamic endpoint construction with variable substitution
- **src/js/AuthenticationHandler.js**: Provider-agnostic authentication management

### Configuration Structure

```json
{
  "api_endpoints": {
    "provider_id": {
      "name": "Human Readable Name",
      "base_url": "https://api.example.com/v1",
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
      "defaultModels": ["model1", "model2"],
      "headers": {
        "required": ["Content-Type", "Authorization"],
        "optional": {"anthropic-version": "2023-06-01"}
      }
    }
  }
}
```

## Key Features

### Provider Abstraction
- **Dynamic endpoint construction**: URLs built from templates with variable substitution
- **Authentication handling**: Automatic header generation for different auth schemes
- **Feature detection**: Runtime capability detection (streaming, images, thinking)
- **Model management**: Default models and dynamic model fetching

### Multi-Platform Testing
- **Python tests**: pytest-based API endpoint validation
- **Bash tests**: curl-based integration tests
- **QML/JS tests**: Sailfish OS compatible JavaScript tests
- **Cross-platform validation**: Ensure consistent behavior across environments

### Extensibility
- **Easy provider addition**: New providers via JSON configuration only
- **Custom endpoints**: Support for provider-specific endpoint patterns
- **Header customization**: Required and optional headers per provider
- **Variable substitution**: Dynamic URL construction with model name interpolation

## File Structure

```
api-abstraction-layer/
├── CLAUDE.md                    # This file
├── config/                      # Configuration files
│   ├── api_endpoints.json      # Main provider configuration
│   ├── test_endpoints.json     # Test configuration with mocks
│   └── schema.json             # JSON schema validation
├── src/                        # Core implementation
│   └── js/
│       ├── ApiAbstraction.js   # Main abstraction layer
│       ├── ConfigLoader.js     # Configuration management
│       ├── EndpointBuilder.js  # URL construction
│       └── AuthenticationHandler.js
├── tests/                      # Multi-platform test suites
│   ├── python/
│   │   ├── test_api_abstraction.py
│   │   ├── test_endpoint_builder.py
│   │   └── test_config_validation.py
│   ├── bash/
│   │   ├── api_endpoint_test.sh
│   │   └── config_validation.sh
│   ├── qml/
│   │   └── ApiTestRunner.qml
│   └── js/
│       └── api_tests.js
├── examples/                   # Usage examples
│   ├── basic_integration.js
│   ├── custom_provider.json
│   └── migration_guide.md
└── docs/                       # Documentation
    ├── API_REFERENCE.md
    ├── PROVIDER_GUIDE.md
    └── TESTING_GUIDE.md
```

## Integration Guide

### JavaScript/QML Integration

```javascript
// Load configuration
Qt.include("src/js/ConfigLoader.js");
Qt.include("src/js/ApiAbstraction.js");

// Initialize API abstraction
var apiConfig = ConfigLoader.load("config/api_endpoints.json");
var api = new ApiAbstraction(apiConfig);

// Build request
var request = api.buildRequest("openai", "gpt-4", messages, {
    streaming: true,
    apiKey: "your-api-key"
});

// Send request with built-in authentication
api.sendRequest(request, function(response) {
    console.log("Success:", response);
}, function(error) {
    console.error("Error:", error);
});
```

### Python Integration

```python
from api_abstraction import ApiEndpointBuilder, ConfigLoader

# Load configuration
config = ConfigLoader.load("config/api_endpoints.json")

# Build endpoints
builder = ApiEndpointBuilder(config)
chat_url = builder.build_url("openai", "chat", model="gpt-4")
models_url = builder.build_url("openai", "models")

# Validate configuration
is_valid = ConfigLoader.validate(config)
```

### Bash Integration

```bash
# Load and validate configuration
./config_validation.sh config/api_endpoints.json

# Test endpoint availability
./api_endpoint_test.sh openai chat

# Build custom request
curl -X POST "$(./build_endpoint.sh gemini chat model=gemini-pro)" \
  -H "$(./auth_header.sh gemini YOUR_API_KEY)" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

## Testing Strategy

### Unit Tests (Python/Javascript)
- Configuration validation
- Endpoint URL construction
- Authentication header generation
- Feature detection

### Integration Tests (Bash)
- Real API endpoint connectivity
- Authentication flow validation
- Streaming functionality
- Error handling

### UI Tests (QML)
- Integration with Sailfish OS applications
- Real-time request handling
- Configuration UI validation

## Provider Support

### Currently Supported
- **OpenAI**: Complete feature support including streaming and images
- **Anthropic Claude**: Streaming support with claude-specific headers
- **Google Gemini**: Multimodal support with custom URL patterns
- **Ollama**: Local deployment support

### Adding New Providers

1. Add configuration to `api_endpoints.json`
2. Define endpoint patterns with variable substitution
3. Specify authentication requirements
4. List supported features
5. Add default models
6. Run test suite for validation

Example new provider:
```json
{
  "custom_provider": {
    "name": "Custom LLM Provider",
    "base_url": "https://api.custom.com/v2",
    "endpoints": {
      "chat": "/completions",
      "models": "/available-models",
      "streaming": "/completions/stream"
    },
    "authentication": {
      "header": "X-API-Key",
      "prefix": ""
    },
    "features": {
      "supportsStreaming": true,
      "supportsImages": false,
      "supportsThinking": true
    },
    "defaultModels": ["custom-model-1", "custom-model-2"],
    "headers": {
      "required": ["Content-Type", "X-API-Key"],
      "optional": {"X-Custom-Header": "custom-value"}
    }
  }
}
```

## Error Handling

### Configuration Errors
- Invalid JSON schema
- Missing required fields
- Invalid endpoint patterns
- Authentication misconfiguration

### Runtime Errors
- Network connectivity issues
- Authentication failures
- Rate limiting
- Invalid model names

### Testing Error Scenarios
- Mock servers for error simulation
- Timeout handling validation
- Authentication failure testing
- malformed response handling

## Performance Considerations

- Configuration caching for repeated access
- Endpoint URL construction optimization
- Authentication header reuse
- Connection pooling support (in future versions)

## Security Notes

- API key handling best practices
- Header injection prevention
- URL validation and sanitization
- Secure configuration storage recommendations

## Future Enhancements

- Async/await support for JavaScript
- Connection pooling and retry mechanisms
- Advanced rate limiting handling
- Provider-specific optimization
- GraphQL endpoint support
- Webhook integration capabilities

## Contributing

1. Add tests for new functionality
2. Ensure all platforms are supported
3. Update documentation
4. Validate configuration schema
5. Run full test suite before changes

---

**Target Use Case**: Universal API abstraction for LLM providers with comprehensive testing and platform compatibility.