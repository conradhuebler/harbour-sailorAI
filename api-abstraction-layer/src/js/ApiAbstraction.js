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
                    var errorMsg = errorResponse.error ? errorResponse.error.message : "HTTP " + xhr.status;
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
        } else {
            // Standard SSE format (OpenAI, Anthropic, Ollama)
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
ApiAbstraction.prototype.addAlias = function(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking) {
    return addAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking);
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
ApiAbstraction.prototype.updateAlias = function(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking) {
    return updateAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking);
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
ApiAbstraction.prototype.generate = function(aliasId, model, prompt, history, callback, errorCallback, streamCallback) {
    var resolved = resolveAlias(aliasId, this.config);
    if (!resolved) {
        errorCallback && errorCallback("Unknown provider alias: " + aliasId);
        return;
    }

    var apiKey = resolved._apiKey;
    var providerType = resolved.type || resolved._type || '';

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

    // Build options
    var options = {
        apiKey: apiKey,
        streaming: Boolean(streamCallback && supportsStreaming(resolved)),
        timeout: resolved._timeout * 3,  // Triple timeout for generation
        enableThinking: resolved._enableThinking,
        temperature: 0.7,
        maxTokens: 2048
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
                    var errorMsg = errorResponse.error ? errorResponse.error.message : "HTTP " + xhr.status;
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
ApiAbstraction.prototype.generateWithImages = function(aliasId, model, prompt, history, images, callback, errorCallback, streamCallback) {
    var resolved = resolveAlias(aliasId, this.config);
    if (!resolved) {
        errorCallback && errorCallback("Unknown provider alias: " + aliasId);
        return;
    }

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
    } else {
        // OpenAI/Ollama multimodal: content array with image_url
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
        customMessages: customMessages
    };

    // Build and send request (reuse the same XHR pattern as generate)
    var endpointType = options.streaming ? 'streaming' : 'chat';
    var url = buildEndpointUrl(resolved, endpointType, {model: model}, {apiKey: apiKey});
    if (!url) {
        errorCallback && errorCallback("Failed to build URL");
        return;
    }

    var headers = buildHeaders(resolved, apiKey);
    var requestData = buildRequestData(resolved, model, customMessages || [], options);

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
                    var errorMsg = errorResponse.error ? errorResponse.error.message : "HTTP " + xhr.status;
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