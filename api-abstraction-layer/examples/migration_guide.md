# Migration Guide: From Direct API to Abstraction Layer

This guide helps you migrate from direct API calls to using the API abstraction layer.

## Overview

The API abstraction layer provides:
- **Configuration-driven** provider management
- **Unified interface** for all LLM providers
- **Automatic authentication** handling
- **Feature detection** capabilities
- **Testing framework** with multi-platform support

## Migration Steps

### Step 1: Add Configuration File

Replace hardcoded provider definitions with the JSON configuration:

**Before (JavaScript):**
```javascript
var providerTypes = {
    "openai": {
        "defaultUrl": "https://api.openai.com/v1",
        "authHeader": "Authorization",
        "authPrefix": "Bearer ",
        "supportsStreaming": true
    }
};
```

**After (JSON Configuration):**
```json
{
  "api_endpoints": {
    "openai": {
      "name": "OpenAI Compatible",
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
      }
    }
  }
}
```

### Step 2: Update Initialization

**Before:**
```javascript
// Direct provider type usage
var typeInfo = providerTypes[providerType];
```

**After:**
```javascript
// Initialize abstraction layer
Qt.include("src/js/ConfigLoader.js");
Qt.include("src/js/ApiAbstraction.js");

var config = loadConfig("config/api_endpoints.json");
var api = new ApiAbstraction(config);
```

### Step 3: Replace URL Construction

**Before:**
```javascript
var url = apiUrl + "/chat/completions";
if (providerType === "gemini") {
    url = apiUrl + "/" + model + ":generateContent";
}
```

**After:**
```javascript
var request = api.buildRequest(providerId, model, messages, options);
var url = request.url;
```

### Step 4: Replace Header Building

**Before:**
```javascript
xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
if (providerType === "anthropic") {
    xhr.setRequestHeader("anthropic-version", "2023-06-01");
}
```

**After:**
```javascript
// Headers are built automatically
api.sendRequest(request, successCallback, errorCallback);
```

### Step 5: Replace Request Building

**Before:**
```javascript
var requestData = {
    "model": model,
    "messages": messages,
    "temperature": 0.7
};

if (streaming) {
    requestData.stream = true;
}

xhr.send(JSON.stringify(requestData));
```

**After:**
```javascript
var request = api.buildRequest(providerId, model, messages, {
    streaming: streaming,
    temperature: 0.7
});

api.sendRequest(request, success, error, streamCallback);
```

## Complete Example Migration

### Original Code (Direct API)
```javascript
function generateContent(providerId, model, prompt, apiKey, history, callback, errorCallback, streamCallback) {
    var apiUrl = getProviderUrl(providerId);
    var url = apiUrl + "/chat/completions";

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", "Bearer " + apiKey);

    var requestData = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7
    };

    if (streamCallback) {
        requestData.stream = true;
    }

    xhr.onreadystatechange = function() {
        // Handle response...
    };

    xhr.send(JSON.stringify(requestData));
}
```

### Migrated Code (Abstraction Layer)
```javascript
function generateContent(providerId, model, prompt, apiKey, history, callback, errorCallback, streamCallback) {
    // Initialize API abstraction if not already done
    if (!this.api) {
        var config = loadConfig("config/api_endpoints.json");
        this.api = new ApiAbstraction(config);
    }

    var messages = [{"role": "user", "message": prompt}];

    var request = this.api.buildRequest(providerId, model, messages, {
        apiKey: apiKey,
        streaming: Boolean(streamCallback),
        temperature: 0.7
    });

    if (!request) {
        errorCallback("Failed to build request");
        return;
    }

    this.api.sendRequest(request, callback, errorCallback, streamCallback);
}
```

## Benefits of Migration

### 1. Configuration Management
- **Before**: Hard-coded providers in JavaScript
- **After**: JSON configuration with validation

### 2. Testing Support
- **Before**: No built-in testing
- **After**: Comprehensive test suite (Python, Bash, QML/JS)

### 3 Provider Addition
- **Before**: Modify JavaScript code
- **After**: Add JSON configuration only

### 4. Feature Detection
- **Before**: Manual feature checking
- **After**: Built-in feature API

### 5. Error Handling
- **Before**: Manual error handling
- **After**: Built-in error handling and validation

## Backward Compatibility

The abstraction layer can coexist with existing code:

```javascript
// Gradual migration approach
function generateContent(providerId, model, prompt, apiKey, history, callback, errorCallback, streamCallback) {
    // Check if provider is migrated to abstraction
    if (this.api && this.api.getProvider(providerId)) {
        // Use new abstraction layer
        var request = this.api.buildRequest(providerId, model, messages, options);
        this.api.sendRequest(request, callback, errorCallback, streamCallback);
    } else {
        // Fall back to original implementation
        callOriginalImplementation();
    }
}
```

## Testing Migration

### Run Tests Before Migration
```bash
cd tests
python run_tests.py
```

### Add Tests for Migrated Code
```javascript
// Add to existing test suite
function testMigratedFunctionality() {
    // Test that migrated code produces same results as original
    var originalResult = callOriginalImplementation();
    var migratedResult = callMigratedImplementation();

    assert(migratedResult === originalResult, "Migration should preserve functionality");
}
```

## Common Migration Issues

### Issue 1: Missing Configuration
**Error**: `Provider 'openai' not found in configuration`
**Solution**: Ensure configuration file includes all needed providers

### Issue 2: Different Response Format
**Error**: `Failed to parse response`
**Solution**: Update response parsing to use abstraction layer's content extraction

### Issue 3: Authentication Changes
**Error**: `HTTP 401 Unauthorized`
**Solution**: Check that authentication headers match expected format

### Issue 4: Endpoint URL Changes
**Error**: `HTTP 404 Not Found`
**Solution**: Verify endpoint patterns match actual API endpoints

## Performance Considerations

### Configuration Loading
- Load configuration once at startup
- Cache configuration for repeated use

```javascript
// Efficient initialization
var apiAbstraction = null;

function getApiAbstraction() {
    if (!apiAbstraction) {
        var config = loadConfig("config/api_endpoints.json");
        apiAbstraction = new ApiAbstraction(config);
    }
    return apiAbstraction;
}
```

### Request Building
- Reuse request objects where possible
- Avoid rebuilding identical requests

## Advanced Migration Techniques

### Custom Provider Support
```javascript
// Add custom provider at runtime
var customProvider = {
    // ... provider configuration
};

api.addProvider("custom", customProvider);
```

### Feature-Based Provider Selection
```javascript
function selectBestProvider(requireStreaming, requireImages) {
    var providers = api.getProviderIds();
    for (var i = 0; i < providers.length; i++) {
        var id = providers[i];
        if (api.supportsFeature(id, "supportsStreaming") === requireStreaming &&
            api.supportsFeature(id, "supportsImages") === requireImages) {
            return id;
        }
    }
    return "openai"; // Fallback
}
```

## Support During Migration

1. **Use the test configuration** (`examples/custom_provider.json`) to test without real APIs
2. **Run the test suite** regularly during migration
3. **Compare responses** between old and new implementations
4. **Gradual migration** - migrate one provider at a time

## Conclusion

The API abstraction layer provides a solid foundation for LLM integration with:
- ✅ **Better maintainability** through configuration
- ✅ **Comprehensive testing** across platforms
- ✅ **Easier provider addition**
- ✅ **Built-in feature detection**
- ✅ **Improved error handling**

Follow this guide step-by-step for a smooth migration process.