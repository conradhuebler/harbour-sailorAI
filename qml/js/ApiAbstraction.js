// Main API Abstraction Layer
// Claude Generated - Universal API abstraction for LLM providers

.pragma library

// Include dependencies
Qt.include("DebugLogger.js")
Qt.include("ConfigLoader.js")
Qt.include("EndpointBuilder.js")
Qt.include("AliasManager.js")

// Module-level state for Gemini streaming buffer
var geminiStreamBuffer = "";

/**
 * API Abstraction constructor
 * @param {object} config - Loaded API configuration
 */
function ApiAbstraction(config) {
    this.config = config;
    logInfo("ApiAbstraction", "Initialized with " + (config ? Object.keys(config.api_endpoints).length : 0) + " providers");
}

/**
 * Get provider configuration
 * @param {string} providerId - Provider identifier
 * @returns {object|null} Provider configuration
 */
ApiAbstraction.prototype.getProvider = function(providerId) {
    return getProvider(this.config, providerId);
};

/**
 * Get all available provider IDs
 * @returns {array} Array of provider identifiers
 */
ApiAbstraction.prototype.getProviderIds = function() {
    return getProviderIds(this.config);
};

/**
 * Build request object for API call
 * @param {string} providerId - Provider identifier
 * @param {string} model - Model name
 * @param {array} messages - Conversation messages
 * @param {object} [options] - Request options
 * @returns {object|null} Request object or null on error
 */
ApiAbstraction.prototype.buildRequest = function(providerId, model, messages, options) {
    options = options || {};

    var provider = this.getProvider(providerId);
    if (!provider) {
        logError("ApiAbstraction", "Provider '" + providerId + "' not found");
        return null;
    }

    // Build URL
    var endpointType = options.streaming ? 'streaming' : 'chat';
    var urlOptions = {apiKey: options.apiKey};
    var url = buildEndpointUrl(provider, endpointType, {model: model}, urlOptions);
    if (!url) {
        logError("ApiAbstraction", "Failed to build URL for " + endpointType);
        return null;
    }

    // Build headers
    var headers = buildHeaders(provider, options.apiKey);
    if (!headers) {
        logError("ApiAbstraction", "Failed to build headers");
        return null;
    }

    // Build request data
    var requestData = buildRequestData(provider, model, messages, options);

    // Assemble complete request object
    var request = {
        method: 'POST',
        url: url,
        headers: headers,
        data: JSON.stringify(requestData),
        responseType: options.streaming ? 'text' : 'json',
        provider: provider,
        options: options
    };

    logInfo("ApiAbstraction", "Built request for " + providerId + " to " + url);
    return request;
};

/**
 * Send API request with built-in error handling
 * @param {object} request - Request object from buildRequest()
 * @param {function} successCallback - Success callback function
 * @param {function} errorCallback - Error callback function
 * @param {function} [streamCallback] - Streaming callback for live responses
 */
ApiAbstraction.prototype.sendRequest = function(request, successCallback, errorCallback, streamCallback) {
    if (!request || !request.url) {
        logError("ApiAbstraction", "Invalid request object");
        errorCallback && errorCallback("Invalid request object");
        return;
    }

    var xhr = new XMLHttpRequest();
    var provider = request.provider;
    var providerType = provider.type || provider.id || '';
    var isStreaming = Boolean(streamCallback && supportsStreaming(provider) && request.options.streaming);

    // Reset Gemini stream buffer for new request
    if (providerType === 'gemini') {
        geminiStreamBuffer = "";
    }

    logInfo("ApiAbstraction", "Sending " + request.method + " request to " + request.url);
    logInfo("ApiAbstraction", "Streaming enabled: " + isStreaming);

    xhr.timeout = request.options.timeout || 30000;

    // Track processed length to avoid re-processing streaming chunks
    var processedLength = 0;

    xhr.ontimeout = function() {
        logError("ApiAbstraction", "Request timeout");
        errorCallback && errorCallback("Request timeout");
    };

    xhr.onreadystatechange = function() {
        if (isStreaming && xhr.readyState === XMLHttpRequest.LOADING && xhr.status === 200) {
            // Process only new data since last read
            var responseText = xhr.responseText;
            if (responseText && responseText.length > processedLength) {
                var newText = responseText.substring(processedLength);
                processedLength = responseText.length;
                processStreamingChunk(newText, streamCallback, providerType);
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            logInfo("ApiAbstraction", "Request completed - Status: " + xhr.status + ", Length: " + (xhr.responseText ? xhr.responseText.length : 0));

            if (xhr.status === 200) {
                try {
                    if (isStreaming) {
                        // Streaming completion
                        successCallback && successCallback('');
                    } else {
                        // Non-streaming response
                        var response = JSON.parse(xhr.responseText);
                        var content = extractContent(response, provider);
                        successCallback && successCallback(content);
                    }
                } catch (e) {
                    logError("ApiAbstraction", "Failed to parse response: " + e.toString());
                    errorCallback && errorCallback("Failed to parse response: " + e.toString());
                }
            } else {
                logError("ApiAbstraction", "HTTP error " + xhr.status + ": " + xhr.statusText);
                try {
                    var errorResponse = JSON.parse(xhr.responseText);
                    var errorMsg = "HTTP " + xhr.status;
                    if (errorResponse.error) {
                        errorMsg = typeof errorResponse.error === 'string' ? errorResponse.error : (errorResponse.error.message || errorMsg);
                    }
                    errorCallback && errorCallback(errorMsg);
                } catch (e) {
                    errorCallback && errorCallback("HTTP " + xhr.status + ": " + xhr.statusText);
                }
            }
        }
    };

    try {
        xhr.open(request.method, request.url, true);

        // Set headers
        for (var headerName in request.headers) {
            if (request.headers.hasOwnProperty(headerName)) {
                xhr.setRequestHeader(headerName, request.headers[headerName]);
            }
        }

        // Log request details for debugging
        logVerbose("ApiAbstraction", "Request details:");
        logVerbose("ApiAbstraction", "  Method: " + request.method);
        logVerbose("ApiAbstraction", "  URL: " + request.url);
        logVerbose("ApiAbstraction", "  Headers: " + Object.keys(request.headers).length + " headers set");
        logVerbose("ApiAbstraction", "  Body preview: " + request.data.substring(0, 200) + "...");

        xhr.send(request.data);
    } catch (e) {
        logError("ApiAbstraction", "Failed to send request: " + e.toString());
        errorCallback && errorCallback("Failed to send request: " + e.toString());
    }
};

/**
 * Check if provider supports specific feature
 * @param {string} providerId - Provider identifier
 * @param {string} feature - Feature name
 * @returns {boolean} True if feature is supported
 */
ApiAbstraction.prototype.supportsFeature = function(providerId, feature) {
    return supportsFeature(this.config, providerId, feature);
};

/**
 * Get models endpoint URL for provider
 * @param {string} providerId - Provider identifier
 * @returns {string|null} Models URL or null
 */
ApiAbstraction.prototype.getModelsUrl = function(providerId) {
    var provider = this.getProvider(providerId);
    if (!provider) {
        return null;
    }

    return buildEndpointUrl(provider, 'models');
};

/**
 * Fetch available models for provider
 * @param {string} providerId - Provider identifier
 * @param {string} apiKey - API key for authentication
 * @param {function} callback - Callback function with models array
 * @param {function} errorCallback - Error callback function
 */
ApiAbstraction.prototype.fetchModels = function(providerId, apiKey, callback, errorCallback) {
    var provider = this.getProvider(providerId);

    if (!provider) {
        errorCallback && errorCallback("Invalid provider configuration");
        return;
    }

    var providerType = provider.type || provider.id || '';

    // Anthropic has no public models endpoint - return defaultModels directly
    if (providerType === 'anthropic') {
        var defaultModels = provider.defaultModels || [];
        callback && callback(defaultModels);
        return;
    }

    var modelsUrl = this.getModelsUrl(providerId);

    if (!modelsUrl) {
        // No models endpoint - return defaultModels
        callback && callback(provider.defaultModels || []);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.timeout = 10000;

    xhr.ontimeout = function() {
        errorCallback && errorCallback("Models fetch timeout");
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var models = extractModels(response, provider);
                    callback && callback(models);
                } catch (e) {
                    errorCallback && errorCallback("Failed to parse models response");
                }
            } else {
                errorCallback && errorCallback("HTTP " + xhr.status);
            }
        }
    };

    try {
        xhr.open('GET', modelsUrl, true);
        var headers = buildHeaders(provider, apiKey);
        for (var headerName in headers) {
            if (headers.hasOwnProperty(headerName)) {
                xhr.setRequestHeader(headerName, headers[headerName]);
            }
        }

        xhr.send();
    } catch (e) {
        errorCallback && errorCallback("Failed to fetch models: " + e.toString());
    }
};

/**
 * Process streaming response chunks
 * @param {string} chunkText - New chunk text
 * @param {function} streamCallback - Streaming callback
 * @param {string} providerType - Provider type identifier
 */
function processStreamingChunk(chunkText, streamCallback, providerType) {
    if (!chunkText || chunkText.length === 0) {
        return;
    }

    try {
        if (providerType === 'gemini') {
            // Gemini streaming format - incremental brace-counting parser
            processGeminiStream(chunkText, streamCallback);
        } else if (providerType === 'ollama') {
            // Ollama native API uses NDJSON (one JSON per line, not SSE)
            processNDJSONStream(chunkText, streamCallback);
        } else {
            // Standard SSE format (OpenAI, Anthropic, Ollama OpenAI-compat)
            processSSEStream(chunkText, streamCallback, providerType);
        }
    } catch (e) {
        logError("ApiAbstraction", "Stream processing error: " + e.toString());
    }
}

/**
 * Process Server-Sent Events streaming
 * @param {string} chunkText - Chunk text
 * @param {function} streamCallback - Streaming callback
 * @param {string} providerType - Provider type for format detection
 */
function processSSEStream(chunkText, streamCallback, providerType) {
    var lines = chunkText.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf('data: ') === 0) {
            var jsonData = line.substring(6);
            if (jsonData !== '[DONE]' && jsonData) {
                try {
                    var data = JSON.parse(jsonData);
                    var content = '';

                    if (providerType === 'anthropic') {
                        // Anthropic streaming format
                        if (data.type === 'content_block_delta' && data.delta && data.delta.text) {
                            content = data.delta.text;
                        }
                    } else {
                        // OpenAI/Ollama streaming format
                        if (data.choices && data.choices[0] && data.choices[0].delta && data.choices[0].delta.content) {
                            content = data.choices[0].delta.content;
                        } else if (data.type === 'content_block_delta' && data.delta && data.delta.text) {
                            // Fallback: also handle Anthropic format
                            content = data.delta.text;
                        }
                    }

                    if (content) {
                        streamCallback && streamCallback(content);
                    }
                } catch (e) {
                    // Partial JSON - will be completed in next chunk
                }
            }
        }
    }
}

/**
 * Process NDJSON streaming format (Ollama native API)
 * Each line is a complete JSON object: {"message":{"role":"assistant","content":"chunk"},"done":false}
 * @param {string} chunkText - Chunk text
 * @param {function} streamCallback - Streaming callback
 */
function processNDJSONStream(chunkText, streamCallback) {
    var lines = chunkText.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;

        try {
            var data = JSON.parse(line);
            if (data.message && data.message.content) {
                streamCallback && streamCallback(data.message.content);
            }
        } catch (e) {
            // Partial JSON line - will be completed in next chunk
        }
    }
}

/**
 * Process Gemini streaming format with brace-counting incremental parser
 * Ported from LLMApi.js brace-counting algorithm
 * @param {string} chunkText - New chunk text
 * @param {function} streamCallback - Streaming callback
 */
function processGeminiStream(chunkText, streamCallback) {
    // Append new chunk to buffer
    geminiStreamBuffer += chunkText;

    // Brace-counting to find complete JSON objects
    var braceCount = 0;
    var inString = false;
    var escaped = false;
    var startIndex = 0;
    var i = 0;

    while (i < geminiStreamBuffer.length) {
        var ch = geminiStreamBuffer.charAt(i);

        if (escaped) {
            escaped = false;
            i++;
            continue;
        }

        if (ch === '\\' && inString) {
            escaped = true;
            i++;
            continue;
        }

        if (ch === '"') {
            inString = !inString;
            i++;
            continue;
        }

        if (!inString) {
            if (ch === '{') {
                if (braceCount === 0) {
                    startIndex = i;
                }
                braceCount++;
            } else if (ch === '}') {
                braceCount--;
                if (braceCount === 0) {
                    // Complete JSON object found
                    var jsonStr = geminiStreamBuffer.substring(startIndex, i + 1);
                    try {
                        var jsonObj = JSON.parse(jsonStr);
                        if (jsonObj.candidates && jsonObj.candidates[0] && jsonObj.candidates[0].content) {
                            var parts = jsonObj.candidates[0].content.parts;
                            if (parts && parts.length > 0 && parts[0].text) {
                                streamCallback && streamCallback(parts[0].text);
                            }
                        }
                    } catch (e) {
                        // Malformed JSON - skip
                    }
                    // Remove processed part from buffer
                    geminiStreamBuffer = geminiStreamBuffer.substring(i + 1);
                    i = 0;
                    startIndex = 0;
                    braceCount = 0;
                    inString = false;
                    escaped = false;
                    continue;
                }
            }
        }
        i++;
    }
}

/**
 * Extract content from API response
 * @param {object} response - API response object
 * @param {object} provider - Provider configuration
 * @returns {string} Extracted content
 */
function extractContent(response, provider) {
    if (!response) {
        return '';
    }

    var providerType = provider.type || provider.id || '';

    if (providerType === 'gemini') {
        // Gemini format
        var geminiResponse = Array.isArray(response) ? response[0] : response;
        if (geminiResponse.candidates && geminiResponse.candidates[0] && geminiResponse.candidates[0].content) {
            return geminiResponse.candidates[0].content.parts[0].text || '';
        }
    } else if (providerType === 'ollama') {
        // Ollama native format: {"message": {"role": "assistant", "content": "text"}, "done": true}
        if (response.message && response.message.content) {
            return response.message.content;
        }
    } else if (providerType === 'anthropic') {
        // Anthropic format
        if (response.content && Array.isArray(response.content)) {
            var textParts = [];
            for (var i = 0; i < response.content.length; i++) {
                var block = response.content[i];
                if (block.type === 'text' && block.text) {
                    textParts.push(block.text);
                }
            }
            return textParts.join('');
        }
    } else {
        // OpenAI-compatible format
        if (response.choices && response.choices[0] && response.choices[0].message) {
            return response.choices[0].message.content || '';
        }
    }

    return '';
}

/**
 * Extract models list from models API response
 * @param {object} response - Models API response
 * @param {object} provider - Provider configuration
 * @returns {array} Array of model names
 */
function extractModels(response, provider) {
    if (!response) {
        return [];
    }

    var providerType = provider.type || provider.id || '';
    var models = [];

    if (providerType === 'gemini') {
        // Gemini format
        if (response.models) {
            for (var i = 0; i < response.models.length; i++) {
                var model = response.models[i];
                if (typeof model === 'string') {
                    models.push(model);
                } else if (model.name) {
                    var modelName = model.name;
                    if (modelName.indexOf('models/') === 0) {
                        modelName = modelName.substring(7);
                    }
                    models.push(modelName);
                }
            }
        }
    } else if (providerType === 'ollama') {
        // Ollama native /api/tags format: {"models": [{"name": "llama3.3", ...}]}
        if (response.models) {
            for (var m = 0; m < response.models.length; m++) {
                var model = response.models[m];
                if (typeof model === 'string') {
                    models.push(model);
                } else if (model.name) {
                    models.push(model.name);
                }
            }
        }
    } else {
        // OpenAI-compatible format (also works for Ollama)
        if (response.data) {
            for (var j = 0; j < response.data.length; j++) {
                var model = response.data[j];
                if (model.id) {
                    models.push(model.id);
                }
            }
        }
    }

    return models;
}

// --- Alias-based API (primary interface) ---

/**
 * Add a provider alias
 */
ApiAbstraction.prototype.addAlias = function(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    return addAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey);
};

/**
 * Remove a provider alias
 */
ApiAbstraction.prototype.removeAlias = function(aliasId) {
    return removeAlias(aliasId);
};

/**
 * Get all alias IDs
 */
ApiAbstraction.prototype.getAliasIds = function() {
    return getAliasIds();
};

/**
 * Get alias object
 */
ApiAbstraction.prototype.getAlias = function(aliasId) {
    return getAlias(aliasId);
};

/**
 * Update alias
 */
ApiAbstraction.prototype.updateAlias = function(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    return updateAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey);
};

/**
 * Get availability status
 */
ApiAbstraction.prototype.getAvailability = function(aliasId) {
    return getAvailability(aliasId);
};

/**
 * Check alias availability
 */
ApiAbstraction.prototype.checkAvailability = function(aliasId, callback) {
    return checkAvailability(aliasId, this.config, callback);
};

/**
 * Get cached models for alias
 */
ApiAbstraction.prototype.getAliasModels = function(aliasId) {
    return getModels(aliasId);
};

/**
 * Fetch models for alias from provider API
 */
ApiAbstraction.prototype.fetchModelsForAlias = function(aliasId, callback, errorCallback) {
    return fetchModels(aliasId, this.config, callback, errorCallback);
};

/**
 * Get favorite model for alias
 */
ApiAbstraction.prototype.getFavoriteModel = function(aliasId) {
    return getFavoriteModel(aliasId);
};

/**
 * Set favorite model for alias
 */
ApiAbstraction.prototype.setFavoriteModel = function(aliasId, model) {
    return setFavoriteModel(aliasId, model);
};

/**
 * Get favorite models for alias
 */
ApiAbstraction.prototype.getFavoriteModels = function(aliasId) {
    return getFavoriteModels(aliasId);
};

/**
 * Set favorite models for alias
 */
ApiAbstraction.prototype.setFavoriteModels = function(aliasId, models) {
    return setFavoriteModels(aliasId, models);
};

/**
 * Add a model to favorites for alias
 */
ApiAbstraction.prototype.addFavoriteModel = function(aliasId, model) {
    return addFavoriteModel(aliasId, model);
};

/**
 * Remove a model from favorites for alias
 */
ApiAbstraction.prototype.removeFavoriteModel = function(aliasId, model) {
    return removeFavoriteModel(aliasId, model);
};

/**
 * Check if a model is a favorite for alias
 */
ApiAbstraction.prototype.isFavoriteModel = function(aliasId, model) {
    return isFavoriteModel(aliasId, model);
};

/**
 * Get thinking mode for alias
 */
ApiAbstraction.prototype.getThinkingMode = function(aliasId) {
    return getThinkingMode(aliasId);
};

/**
 * Set thinking mode for alias
 */
ApiAbstraction.prototype.setThinkingMode = function(aliasId, enabled) {
    return setThinkingMode(aliasId, enabled);
};

// --- Web tools ---

/**
 * Get whether web_search tool is enabled for alias
 */
ApiAbstraction.prototype.getAliasWebSearchMode = function(aliasId) {
    return getAliasWebSearchMode(aliasId);
};

/**
 * Enable/disable web_search tool for alias
 */
ApiAbstraction.prototype.setAliasWebSearchMode = function(aliasId, enabled) {
    return setAliasWebSearchMode(aliasId, enabled);
};

/**
 * Get whether web_fetch tool is enabled for alias
 */
ApiAbstraction.prototype.getAliasWebFetchMode = function(aliasId) {
    return getAliasWebFetchMode(aliasId);
};

/**
 * Enable/disable web_fetch tool for alias
 */
ApiAbstraction.prototype.setAliasWebFetchMode = function(aliasId, enabled) {
    return setAliasWebFetchMode(aliasId, enabled);
};

/**
 * Get optional API key override for Ollama web tools
 */
ApiAbstraction.prototype.getAliasWebSearchApiKey = function(aliasId) {
    return getAliasWebSearchApiKey(aliasId);
};

/**
 * Set optional API key override for Ollama web tools
 */
ApiAbstraction.prototype.setAliasWebSearchApiKey = function(aliasId, key) {
    return setAliasWebSearchApiKey(aliasId, key);
};

/**
 * Load aliases from JSON string
 */
ApiAbstraction.prototype.loadAliases = function(jsonStr) {
    return loadAliases(jsonStr, this.config);
};

/**
 * Save aliases to JSON string
 */
ApiAbstraction.prototype.saveAliases = function() {
    return saveAliases();
};

/**
 * Generate content using an alias (primary API)
 * @param {string} aliasId - Alias identifier
 * @param {string} model - Model name
 * @param {string} prompt - User's text prompt
 * @param {array} history - Conversation history [{role: "user"|"bot", message: string}]
 * @param {function} callback - Success callback
 * @param {function} errorCallback - Error callback
 * @param {function} [streamCallback] - Streaming callback
 */
ApiAbstraction.prototype.generate = function(aliasId, model, prompt, history, callback, errorCallback, streamCallback, options) {
    var resolved = resolveAlias(aliasId, this.config);
    if (!resolved) {
        errorCallback && errorCallback("Unknown provider alias: " + aliasId);
        return;
    }

    var apiKey = resolved._apiKey;
    var providerType = resolved.type || resolved._type || '';

    // Capture caller options before the local `options` below shadows the parameter. Claude Generated
    var callerOptions = options || {};

    // Check API key (Ollama doesn't need one)
    if (!apiKey && providerType !== 'ollama') {
        errorCallback && errorCallback("No API key configured for alias: " + aliasId);
        return;
    }

    // Build messages array from prompt + history
    var messages = [];

    if (history && Array.isArray(history)) {
        for (var h = 0; h < history.length; h++) {
            messages.push({
                role: history[h].role,
                content: history[h].message || history[h].content
            });
        }
    }

    // Add the current prompt
    if (prompt) {
        messages.push({role: 'user', content: prompt});
    }

    // Apply role alternation filter
    messages = filterRoleAlternation(messages);

    // Ollama tool loop: dispatch to dedicated agent when tools are enabled.
    // Tool iterations are non-streaming (we need tool_calls before the final answer);
    // a live "search log" is streamed during the loop so the UI is not stuck on an
    // empty bubble. The optional `options` object carries localized tool labels and the
    // configurable iteration cap. Claude Generated
    if (providerType === 'ollama' && (resolved._enableWebSearch || resolved._enableWebFetch)) {
        this._generateWithTools(aliasId, resolved, model, messages, callback, errorCallback, streamCallback, options);
        return;
    }

    // Build options
    var options = {
        apiKey: apiKey,
        streaming: Boolean(streamCallback && supportsStreaming(resolved)),
        timeout: resolved._timeout * 3,  // Triple timeout for generation
        enableThinking: resolved._enableThinking,
        temperature: 0.7,
        maxTokens: 2048,
        systemPrompt: callerOptions.systemPrompt
    };

    // Build request
    var endpointType = options.streaming ? 'streaming' : 'chat';
    var url = buildEndpointUrl(resolved, endpointType, {model: model}, {apiKey: apiKey});
    if (!url) {
        errorCallback && errorCallback("Failed to build URL");
        return;
    }

    var headers = buildHeaders(resolved, apiKey);
    var requestData = buildRequestData(resolved, model, messages, options);

    // Send the request
    var xhr = new XMLHttpRequest();
    var isStreaming = options.streaming;

    // Reset Gemini stream buffer for new request
    if (providerType === 'gemini') {
        geminiStreamBuffer = "";
    }

    xhr.timeout = options.timeout;

    var processedLength = 0;

    xhr.ontimeout = function() {
        errorCallback && errorCallback("Request timeout");
    };

    xhr.onreadystatechange = function() {
        if (isStreaming && xhr.readyState === XMLHttpRequest.LOADING && xhr.status === 200) {
            var responseText = xhr.responseText;
            if (responseText && responseText.length > processedLength) {
                var newText = responseText.substring(processedLength);
                processedLength = responseText.length;
                processStreamingChunk(newText, streamCallback, providerType);
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    if (isStreaming) {
                        callback && callback('');
                    } else {
                        var response = JSON.parse(xhr.responseText);
                        var content = extractContent(response, resolved);
                        callback && callback(content);
                    }
                } catch (e) {
                    errorCallback && errorCallback("Failed to parse response: " + e.toString());
                }
            } else {
                    try {
                        var errorResponse = JSON.parse(xhr.responseText);
                        var errorMsg = "HTTP " + xhr.status;
                        if (errorResponse.error) {
                            errorMsg = typeof errorResponse.error === 'string' ? errorResponse.error : (errorResponse.error.message || errorMsg);
                        }
                        errorCallback && errorCallback(errorMsg);
                    } catch (e) {
                        errorCallback && errorCallback("HTTP " + xhr.status + ": " + xhr.statusText);
                    }
                }
            }
        };

        try {
            xhr.open('POST', url, true);
            for (var headerName in headers) {
                if (headers.hasOwnProperty(headerName)) {
                    xhr.setRequestHeader(headerName, headers[headerName]);
                }
            }
            xhr.send(JSON.stringify(requestData));
        } catch (e) {
            errorCallback && errorCallback("Failed to send request: " + e.toString());
        }
    };

    /**
     * Generate content with images using an alias
 * @param {string} aliasId - Alias identifier
 * @param {string} model - Model name
 * @param {string} prompt - User's text prompt
 * @param {array} history - Conversation history
 * @param {array} images - Array of image objects {data: base64string, mimeType: "image/jpeg"}
 * @param {function} callback - Success callback
 * @param {function} errorCallback - Error callback
 * @param {function} [streamCallback] - Streaming callback
 */
ApiAbstraction.prototype.generateWithImages = function(aliasId, model, prompt, history, images, callback, errorCallback, streamCallback, options) {
    var resolved = resolveAlias(aliasId, this.config);
    if (!resolved) {
        errorCallback && errorCallback("Unknown provider alias: " + aliasId);
        return;
    }

    // Capture caller options before the local `options` below shadows the parameter. Claude Generated
    var callerOptions = options || {};

    var apiKey = resolved._apiKey;
    var providerType = resolved.type || resolved._type || '';

    if (!apiKey && providerType !== 'ollama') {
        errorCallback && errorCallback("No API key configured for alias: " + aliasId);
        return;
    }

    if (!images || images.length === 0) {
        // No images - fall back to regular generate
        this.generate(aliasId, model, prompt, history, callback, errorCallback, streamCallback);
        return;
    }

    // Build messages with images based on provider type
    var messages = [];
    var customContents = null;
    var customMessages = null;
    var ollamaImageArray = null;

    if (providerType === 'gemini') {
        // Gemini multimodal: parts array with inline_data + text
        var parts = [];
        for (var img = 0; img < images.length; img++) {
            parts.push({
                inline_data: {
                    mime_type: images[img].mimeType || "image/jpeg",
                    data: images[img].data
                }
            });
        }
        if (prompt) {
            parts.push({text: prompt});
        }
        customContents = [{role: "user", parts: parts}];

        // Add history as additional contents
        if (history && Array.isArray(history)) {
            var historyContents = [];
            for (var h = 0; h < history.length; h++) {
                var geminiRole = history[h].role === 'user' ? 'user' : 'model';
                historyContents.push({
                    role: geminiRole,
                    parts: [{text: history[h].message || history[h].content}]
                });
            }
            customContents = historyContents.concat(customContents);
        }
    } else if (providerType === 'anthropic') {
        // Anthropic multimodal: content array with image blocks
        var contentArray = [];
        for (var img = 0; img < images.length; img++) {
            contentArray.push({
                type: "image",
                source: {
                    type: "base64",
                    media_type: images[img].mimeType || "image/jpeg",
                    data: images[img].data
                }
            });
        }
        if (prompt) {
            contentArray.push({type: "text", text: prompt});
        }
        customMessages = [{role: "user", content: contentArray}];

        // Add history
        if (history && Array.isArray(history)) {
            var historyMessages = [];
            for (var h = 0; h < history.length; h++) {
                var anthropicRole = history[h].role === 'bot' ? 'assistant' : history[h].role;
                if (anthropicRole !== 'system') {
                    historyMessages.push({
                        role: anthropicRole,
                        content: history[h].message || history[h].content
                    });
                }
            }
            customMessages = historyMessages.concat(customMessages);
        }
        customMessages = filterRoleAlternation(customMessages);
    } else if (providerType === 'ollama') {
        // Ollama native format: top-level images array with base64 strings
        var ollamaMessages = [];

        if (history && Array.isArray(history)) {
            for (var h = 0; h < history.length; h++) {
                var histRole = history[h].role === 'bot' ? 'assistant' : history[h].role;
                ollamaMessages.push({
                    role: histRole,
                    content: history[h].message || history[h].content
                });
            }
        }

        if (prompt) {
            ollamaMessages.push({role: "user", content: prompt});
        }

        customMessages = filterRoleAlternation(ollamaMessages);

        // Ollama native: collect base64 strings; EndpointBuilder places them
        // inside the last user message per /api/chat format.
        ollamaImageArray = [];
        for (var img = 0; img < images.length; img++) {
            ollamaImageArray.push(images[img].data);
        }
        logVerbose("ApiAbstraction", "Ollama multimodal: " + ollamaImageArray.length + " image(s) prepared");
    } else {
        // OpenAI multimodal: content array with image_url
        var contentArray = [];
        if (prompt) {
            contentArray.push({type: "text", text: prompt});
        }
        for (var img = 0; img < images.length; img++) {
            contentArray.push({
                type: "image_url",
                image_url: {
                    url: "data:" + (images[img].mimeType || "image/jpeg") + ";base64," + images[img].data
                }
            });
        }
        logVerbose("ApiAbstraction", "OpenAI multimodal: " + images.length + " image(s) prepared");
        customMessages = [{role: "user", content: contentArray}];

        // Add history
        if (history && Array.isArray(history)) {
            var historyMessages = [];
            for (var h = 0; h < history.length; h++) {
                var openaiRole = history[h].role === 'bot' ? 'assistant' : history[h].role;
                historyMessages.push({
                    role: openaiRole,
                    content: history[h].message || history[h].content
                });
            }
            customMessages = historyMessages.concat(customMessages);
        }
        customMessages = filterRoleAlternation(customMessages);
    }

    // Build options
    var options = {
        apiKey: apiKey,
        streaming: Boolean(streamCallback && supportsStreaming(resolved)),
        timeout: resolved._timeout * 3,
        enableThinking: resolved._enableThinking,
        temperature: 0.7,
        maxTokens: 2048,
        customContents: customContents,
        customMessages: customMessages,
        systemPrompt: callerOptions.systemPrompt
    };

    // Add Ollama images to options (set in ollama branch above)
    if (ollamaImageArray) {
        options.images = ollamaImageArray;
    }

    // Build and send request (reuse the same XHR pattern as generate)
    var endpointType = options.streaming ? 'streaming' : 'chat';
    var url = buildEndpointUrl(resolved, endpointType, {model: model}, {apiKey: apiKey});
    if (!url) {
        errorCallback && errorCallback("Failed to build URL");
        return;
    }

    var headers = buildHeaders(resolved, apiKey);
    var requestData = buildRequestData(resolved, model, customMessages || [], options);

    logInfo("ApiAbstraction", "Sending multimodal request to " + providerType + " (" + images.length + " image(s), stream=" + options.streaming + ")");

    var xhr = new XMLHttpRequest();
    var isStreaming = options.streaming;

    if (providerType === 'gemini') {
        geminiStreamBuffer = "";
    }

    xhr.timeout = options.timeout;
    var processedLength = 0;

    xhr.ontimeout = function() {
        errorCallback && errorCallback("Request timeout");
    };

    xhr.onreadystatechange = function() {
        if (isStreaming && xhr.readyState === XMLHttpRequest.LOADING && xhr.status === 200) {
            var responseText = xhr.responseText;
            if (responseText && responseText.length > processedLength) {
                var newText = responseText.substring(processedLength);
                processedLength = responseText.length;
                processStreamingChunk(newText, streamCallback, providerType);
            }
        }

        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    if (isStreaming) {
                        callback && callback('');
                    } else {
                        logInfo("generateWithImages", "Response length: " + xhr.responseText.length + ", status: " + xhr.status);
                        var response = JSON.parse(xhr.responseText);
                        var content = extractContent(response, resolved);
                        callback && callback(content);
                    }
                } catch (e) {
                    logError("generateWithImages", "Parse error: " + e.toString() + ", response length: " + xhr.responseText.length + ", first 200: " + (xhr.responseText ? xhr.responseText.substring(0, 200) : "empty"));
                    errorCallback && errorCallback("Failed to parse response: " + e.toString());
                }
            } else {
                    try {
                        var errorResponse = JSON.parse(xhr.responseText);
                        var errorMsg = "HTTP " + xhr.status;
                        if (errorResponse.error) {
                            errorMsg = typeof errorResponse.error === 'string' ? errorResponse.error : (errorResponse.error.message || errorMsg);
                        }
                        errorCallback && errorCallback(errorMsg);
                    } catch (e) {
                        errorCallback && errorCallback("HTTP " + xhr.status + ": " + xhr.statusText);
                    }
                }
            }
        };

        try {
            xhr.open('POST', url, true);
            for (var headerName in headers) {
            if (headers.hasOwnProperty(headerName)) {
                xhr.setRequestHeader(headerName, headers[headerName]);
            }
        }
        xhr.send(JSON.stringify(requestData));
    } catch (e) {
        errorCallback && errorCallback("Failed to send request: " + e.toString());
    }
};

// Export constructor for external use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ApiAbstraction;
}

// --- Ollama web tools (tool loop) ---
// Claude Generated - implements the agent loop for Ollama Cloud web_search / web_fetch
// Docs: https://docs.ollama.com/capabilities/web-search

/**
 * Execute a single Ollama tool call (web_search or web_fetch).
 * Returns a compact text representation suitable for appending as a tool message.
 * @param {string} aliasId - Alias identifier (for key resolution)
 * @param {object} resolved - Resolved provider object (for key resolution)
 * @param {string} name - Tool name ('web_search' or 'web_fetch')
 * @param {object} args - Tool arguments
 * @param {function} callback - Called with (text, isError, sources) where sources is an
 *                              array of { title, url } collected from this call (may be []).
 */
ApiAbstraction.prototype.executeToolCall = function(aliasId, resolved, name, args, callback) {
    var alias = getAlias(aliasId);
    var webKey = (alias && alias.webSearchApiKey) ? alias.webSearchApiKey : (resolved._apiKey || "");

    if (!webKey) {
        callback("Ollama API key required for " + name + ". Set it in the provider's Web tools section or as the provider API key.", true, []);
        return;
    }

    if (name === 'web_search') {
        var query = (args && args.query) ? String(args.query) : "";
        if (!query) {
            callback("web_search called without a query", true, []);
            return;
        }
        var maxResults = (args && typeof args.max_results === 'number') ? args.max_results : 5;
        if (maxResults < 1) maxResults = 1;
        if (maxResults > 10) maxResults = 10;

        this._ollamaWebCall("/api/web_search", webKey, { query: query, max_results: maxResults }, function(err, response) {
            if (err) {
                callback("web_search failed: " + err, true, []);
                return;
            }
            var results = (response && response.results) ? response.results : [];
            if (!results.length) {
                callback("No web search results for query: " + query, false, []);
                return;
            }
            var lines = ["Web search results for: " + query];
            var srcs = [];
            for (var i = 0; i < results.length; i++) {
                var r = results[i] || {};
                var content = r.content ? String(r.content) : "";
                if (content.length > 600) content = content.substring(0, 600) + "...";
                lines.push("[" + (i + 1) + "] " + (r.title || r.url || "untitled"));
                if (r.url) lines.push("    URL: " + r.url);
                if (content) lines.push("    " + content);
                if (r.url) srcs.push({ title: r.title || r.url, url: r.url });
            }
            callback(lines.join("\n"), false, srcs);
        });
    } else if (name === 'web_fetch') {
        var url = (args && args.url) ? String(args.url) : "";
        if (!url) {
            callback("web_fetch called without a url", true, []);
            return;
        }
        this._ollamaWebCall("/api/web_fetch", webKey, { url: url }, function(err, response) {
            if (err) {
                callback("web_fetch failed: " + err, true, []);
                return;
            }
            var content = (response && response.content) ? String(response.content) : "";
            if (content.length > 4000) content = content.substring(0, 4000) + "...";
            var lines = [];
            var fetchTitle = (response && response.title) ? response.title : "";
            if (fetchTitle) lines.push("Title: " + fetchTitle);
            if (url) lines.push("URL: " + url);
            if (content) lines.push(content);
            if (!lines.length) lines.push("(empty response)");
            callback(lines.join("\n"), false, [{ title: fetchTitle || url, url: url }]);
        });
    } else {
        callback("Unknown tool: " + name, true, []);
    }
};

/**
 * POST to an Ollama Cloud tool endpoint with bearer auth.
 * @param {string} path - Path (e.g. '/api/web_search')
 * @param {string} apiKey - Bearer token
 * @param {object} body - JSON body
 * @param {function} callback - (error, responseJson)
 */
ApiAbstraction.prototype._ollamaWebCall = function(path, apiKey, body, callback) {
    var url = "https://ollama.com" + path;
    logInfo("ApiAbstraction", "Ollama tool call: POST " + url);
    logVerbose("ApiAbstraction", "Ollama tool body: " + JSON.stringify(body));

    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 30000;

    xhr.ontimeout = function() {
        callback("timeout", null);
    };
    xhr.onerror = function() {
        callback("network error", null);
    };
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    callback(null, JSON.parse(xhr.responseText));
                } catch (e) {
                    callback("invalid JSON response: " + e.toString(), null);
                }
            } else {
                var msg = "HTTP " + xhr.status;
                try {
                    var err = JSON.parse(xhr.responseText);
                    if (err && err.error) {
                        msg = typeof err.error === 'string' ? err.error : (err.error.message || msg);
                    }
                } catch (e) { /* keep msg */ }
                callback(msg, null);
            }
        }
    };
    try {
        xhr.send(JSON.stringify(body));
    } catch (e) {
        callback("send failed: " + e.toString(), null);
    }
};

/**
 * Build the tool list an alias should expose to the LLM.
 * Only Ollama with web tools enabled gets any tools.
 * @param {object} resolved - Resolved provider object
 * @returns {array} Array of tool definitions
 */
ApiAbstraction.prototype._buildOllamaTools = function(resolved) {
    var tools = [];
    if (!resolved) return tools;
    if (resolved._type && resolved._type !== 'ollama') return tools;
    if (resolved._enableWebSearch) tools.push(OLLAMA_WEB_SEARCH_TOOL);
    if (resolved._enableWebFetch) tools.push(OLLAMA_WEB_FETCH_TOOL);
    return tools;
};

/**
 * Agent loop for Ollama web tools. Runs blocking tool iterations while streaming a live
 * "search log" (so the UI is not stuck on an empty bubble), collects the sources used and
 * appends a localized "Sources" block to the streamed answer. On the final allowed iteration
 * the tools are withheld, forcing the model to produce a textual answer instead of looping
 * forever - this replaces the previous "tool loop exceeded" error. Claude Generated.
 *
 * @param {string} aliasId - Alias identifier
 * @param {object} resolved - Resolved provider
 * @param {string} model - Model name
 * @param {array} messages - Conversation messages
 * @param {function} callback - Final success callback
 * @param {function} errorCallback - Error callback
 * @param {function} [streamCallback] - Receives incremental text (search log + answer + sources)
 * @param {object} [options] - { toolLabels: {searching, reading, sourcesHeader}, maxToolIterations }
 */
ApiAbstraction.prototype._generateWithTools = function(aliasId, resolved, model, messages, callback, errorCallback, streamCallback, options) {
    var self = this;
    var tools = this._buildOllamaTools(resolved);
    if (!tools.length) {
        // Should not happen - generate() only routes here when tools exist
        errorCallback && errorCallback("No Ollama tools enabled for alias " + aliasId);
        return;
    }

    options = options || {};
    var labels = options.toolLabels || {};
    var labelSearching = labels.searching || "Searching the web: %1";
    var labelReading = labels.reading || "Reading page: %1";
    var labelSources = labels.sourcesHeader || "Sources";

    var apiKey = resolved._apiKey;
    var maxIterations = (typeof options.maxToolIterations === 'number' && options.maxToolIterations > 0)
                        ? Math.floor(options.maxToolIterations) : 8;
    // Opt-in: deterministically fetch URLs the user pasted (off by default - many models
    // already call web_fetch themselves, and not everyone wants automatic fetching). Claude Generated
    var autoFetchUrls = !!options.autoFetchUrls;
    var iteration = 0;

    // Collected sources (deduplicated by URL) for the final "Sources" block
    var sources = [];
    var seenUrls = {};
    // URLs already auto-fetched (user-pasted prefetch + top search results), to avoid re-fetching
    var fetchedUrls = {};
    function addSources(list) {
        if (!list) return;
        for (var i = 0; i < list.length; i++) {
            var s = list[i];
            if (s && s.url && !seenUrls[s.url]) { seenUrls[s.url] = true; sources.push(s); }
        }
    }

    // Unified output sink: stream when possible, otherwise buffer for the non-streaming callback
    var streamedAnything = false;
    var nonStreamBuffer = "";
    function emit(text) {
        if (!text) return;
        if (streamCallback) {
            try { streamCallback(text); } catch (e) { logError("ApiAbstraction", "streamCallback error: " + e); }
        } else {
            nonStreamBuffer += text;
        }
        streamedAnything = true;
    }

    // The mutable messages array we'll keep appending to
    var workingMessages = [];
    for (var m = 0; m < messages.length; m++) {
        var src = messages[m];
        workingMessages.push({ role: src.role, content: src.message || src.content });
    }

    function finish(finalContent) {
        var prefix = (streamedAnything && finalContent) ? "\n" : "";
        emit(prefix + (finalContent || ""));
        if (sources.length) {
            var block = "\n\n―――――――――\n" + labelSources + ":\n";
            for (var i = 0; i < sources.length; i++) {
                block += (i + 1) + ". " + sources[i].title + " — " + sources[i].url + "\n";
            }
            emit(block);
        }
        if (streamCallback) {
            callback && callback("");
        } else {
            callback && callback(nonStreamBuffer);
        }
    }

    function runIteration() {
        iteration++;
        // On the final allowed iteration we withhold the tools so the model must answer
        // with what it has gathered instead of requesting yet another tool call.
        var isLastIteration = (iteration >= maxIterations);
        var toolsThisRound = isLastIteration ? [] : tools;

        var reqOptions = {
            apiKey: apiKey,
            streaming: false,
            tools: toolsThisRound,
            timeout: resolved._timeout * 3,
            enableThinking: resolved._enableThinking,
            temperature: 0.7,
            maxTokens: 2048,
            systemPrompt: options.systemPrompt
        };

        var url = buildEndpointUrl(resolved, 'chat', { model: model }, { apiKey: apiKey });
        if (!url) {
            errorCallback && errorCallback("Failed to build URL");
            return;
        }
        var headers = buildHeaders(resolved, apiKey);
        var requestData = buildRequestData(resolved, model, workingMessages, reqOptions);

        logInfo("ApiAbstraction", "Ollama tool loop iteration " + iteration + "/" + maxIterations
                + (isLastIteration ? " (final, tools withheld)" : " (tools: " + toolsThisRound.length + ")"));
        logVerbose("ApiAbstraction", "Ollama tool loop body: " + JSON.stringify(requestData).substring(0, 500));

        var xhr = new XMLHttpRequest();
        xhr.open("POST", url, true);
        for (var hn in headers) {
            if (headers.hasOwnProperty(hn)) xhr.setRequestHeader(hn, headers[hn]);
        }
        xhr.timeout = reqOptions.timeout;

        xhr.ontimeout = function() {
            errorCallback && errorCallback("Ollama tool loop: request timeout (iteration " + iteration + ")");
        };
        xhr.onerror = function() {
            errorCallback && errorCallback("Ollama tool loop: network error (iteration " + iteration + ")");
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;

            if (xhr.status !== 200) {
                var msg = "HTTP " + xhr.status;
                try {
                    var err = JSON.parse(xhr.responseText);
                    if (err && err.error) {
                        msg = typeof err.error === 'string' ? err.error : (err.error.message || msg);
                    }
                } catch (e) { /* keep msg */ }
                errorCallback && errorCallback("Ollama tool loop: " + msg);
                return;
            }

            var response;
            try {
                response = JSON.parse(xhr.responseText);
            } catch (e) {
                errorCallback && errorCallback("Ollama tool loop: invalid JSON response");
                return;
            }

            var assistantMessage = response && response.message ? response.message : null;
            if (!assistantMessage) {
                errorCallback && errorCallback("Ollama tool loop: response missing message");
                return;
            }

            // Append the assistant's reply (may include content and/or tool_calls)
            workingMessages.push({
                role: "assistant",
                content: assistantMessage.content || "",
                tool_calls: assistantMessage.tool_calls || undefined
            });

            var toolCalls = assistantMessage.tool_calls;
            var willCallTools = toolCalls && toolCalls.length > 0 && !isLastIteration;

            if (willCallTools) {
                // Stream any commentary the model produced alongside its tool calls
                if (assistantMessage.content) emit(assistantMessage.content + "\n");
                executeToolCallsSequentially(toolCalls, 0, function(err) {
                    if (err) {
                        errorCallback && errorCallback("Ollama tool: " + err);
                        return;
                    }
                    runIteration();
                });
                return;
            }

            // No (further) tool calls - this is the final answer
            finish(assistantMessage.content || "");
        };
        try {
            xhr.send(JSON.stringify(requestData));
        } catch (e) {
            errorCallback && errorCallback("Ollama tool loop: send failed: " + e.toString());
        }
    }

    // Emit a live "search log" line so the user sees activity during the blocking iterations.
    // The function form of replace() avoids '$' in the value being treated as a backreference.
    // Identical lines are shown only once - models often repeat the same query/url across
    // iterations and we do not want to spam the bubble with duplicates. Claude Generated.
    var loggedLines = {};
    function fmt(template, value) {
        return template.replace("%1", function() { return value; });
    }
    function logToolStart(name, args) {
        var line;
        if (name === 'web_search') {
            var q = (args && args.query) ? String(args.query) : "";
            line = fmt(labelSearching, '"' + q + '"');
        } else if (name === 'web_fetch') {
            var u = (args && args.url) ? String(args.url) : "";
            line = fmt(labelReading, u);
        } else {
            return;
        }
        if (loggedLines[line]) return;
        loggedLines[line] = true;
        emit(line + "\n");
    }

    function executeToolCallsSequentially(calls, idx, done) {
        if (idx >= calls.length) {
            done(null);
            return;
        }
        var call = calls[idx] || {};
        // Ollama tool_calls: { function: { name, arguments } }; arguments may be string or object
        var fn = call.function || {};
        var name = fn.name || "";
        var rawArgs = fn.arguments;
        var args = {};
        if (rawArgs !== undefined && rawArgs !== null) {
            if (typeof rawArgs === 'string') {
                try { args = JSON.parse(rawArgs); } catch (e) { args = { _raw: rawArgs }; }
            } else if (typeof rawArgs === 'object') {
                args = rawArgs;
            }
        }

        logInfo("ApiAbstraction", "Ollama tool call: " + name + " args=" + JSON.stringify(args).substring(0, 200));
        logToolStart(name, args);

        self.executeToolCall(aliasId, resolved, name, args, function(result, isError, resultSources) {
            // Append tool result message.
            // Ollama expects role:"tool" with content + tool_name (NOT tool_call_id like OpenAI).
            // See https://docs.ollama.com/capabilities/web-search - Claude Generated
            var toolMsg = {
                role: "tool",
                content: result || "",
                tool_name: name
            };
            workingMessages.push(toolMsg);
            if (!isError) {
                addSources(resultSources);
            } else {
                logError("ApiAbstraction", "Ollama tool " + name + " returned error: " + result);
                // Continue the loop even on tool error so the LLM can react
            }

            // Opt-in: after a web_search, automatically read the top result pages in full and
            // append their content to this same tool message (so there is no orphan tool reply).
            if (!isError && autoFetchUrls && name === 'web_search' && resultSources && resultSources.length) {
                autoReadTopResults(resultSources, toolMsg, function() {
                    executeToolCallsSequentially(calls, idx + 1, done);
                });
                return;
            }

            executeToolCallsSequentially(calls, idx + 1, done);
        });
    }

    // --- Deterministic auto web_fetch (opt-in) ---
    // When the user enabled "auto-fetch URLs" AND web_fetch is enabled, we (a) fetch any http(s)
    // URL in the latest user message before the model runs, and (b) read the top result pages of
    // each web_search in full. Both inject page content the model can use and add to Sources.
    // Disabled by default - capable models call web_fetch themselves. Claude Generated.
    function extractUrls(text) {
        if (!text) return [];
        var re = /https?:\/\/[^\s<>"')]+/g;
        var out = [], seen = {}, mt;
        while ((mt = re.exec(text)) !== null) {
            var u = mt[0].replace(/[.,;:!?)\]}'"]+$/, "");  // drop trailing punctuation
            if (u && !seen[u]) { seen[u] = true; out.push(u); }
        }
        return out;
    }

    // Fetch a single URL once (deduped via fetchedUrls), showing the live "reading" log line.
    // Calls back with the page text on success, or null on error / skip.
    function doWebFetch(url, cb) {
        if (!url || fetchedUrls[url]) { cb(null); return; }
        fetchedUrls[url] = true;
        logToolStart('web_fetch', { url: url });
        self.executeToolCall(aliasId, resolved, 'web_fetch', { url: url }, function(result, isError, resultSources) {
            if (!isError) {
                addSources(resultSources);
                cb(result || "");
            } else {
                logError("ApiAbstraction", "Auto web_fetch failed for " + url + ": " + result);
                cb(null);
            }
        });
    }

    // Read the top result pages of a web_search in full and append them to its tool message,
    // so there is no orphan tool reply (the API expects one tool message per model tool_call).
    function autoReadTopResults(resultSources, toolMsg, done) {
        var topN = 2;
        var urls = [];
        for (var i = 0; i < resultSources.length && urls.length < topN; i++) {
            var u = resultSources[i] && resultSources[i].url;
            if (u && !fetchedUrls[u]) urls.push(u);
        }
        if (!urls.length) { done(); return; }
        var k = 0;
        function nextTop() {
            if (k >= urls.length) { done(); return; }
            var url = urls[k++];
            doWebFetch(url, function(text) {
                if (text) toolMsg.content += "\n\n[Full page " + url + "]\n" + text;
                nextTop();
            });
        }
        nextTop();
    }

    // Auto-fetch the URLs the user pasted into their latest message (injected as context).
    function prefetchUserUrls(doneFetching) {
        if (!autoFetchUrls || !resolved._enableWebFetch) { doneFetching(); return; }

        var lastUserIdx = -1;
        for (var i = workingMessages.length - 1; i >= 0; i--) {
            if (workingMessages[i].role === 'user') { lastUserIdx = i; break; }
        }
        if (lastUserIdx === -1) { doneFetching(); return; }

        var urls = extractUrls(workingMessages[lastUserIdx].content);
        if (!urls.length) { doneFetching(); return; }
        var maxFetch = 3;
        if (urls.length > maxFetch) urls = urls.slice(0, maxFetch);

        logInfo("ApiAbstraction", "Auto web_fetch: " + urls.length + " URL(s) from user message");

        var fi = 0;
        function nextUrl() {
            if (fi >= urls.length) { doneFetching(); return; }
            var url = urls[fi++];
            doWebFetch(url, function(text) {
                if (text) {
                    // model-facing only (not shown in the chat bubble), so no qsTr needed
                    workingMessages[lastUserIdx].content += "\n\n[Auto-fetched page " + url + "]\n" + text;
                }
                nextUrl();
            });
        }
        nextUrl();
    }

    prefetchUserUrls(function() { runIteration(); });
};