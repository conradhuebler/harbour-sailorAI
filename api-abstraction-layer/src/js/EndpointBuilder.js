// Endpoint URL Builder
// Claude Generated - Dynamic API endpoint construction with variable substitution

.pragma library

Qt.include("DebugLogger.js")

/**
 * Build complete endpoint URL for a provider
 * @param {object} provider - Provider configuration object
 * @param {string} endpointType - Type of endpoint ('chat', 'models', 'streaming')
 * @param {object} [variables] - Variables for substitution (e.g., {model: 'gpt-4'})
 * @param {object} [options] - Additional options (e.g., {apiKey: '...'} for URL param auth)
 * @returns {string} Complete endpoint URL or null on error
 */
function buildEndpointUrl(provider, endpointType, variables, options) {
    if (!provider || !provider.base_url || !provider.endpoints) {
        logError("EndpointBuilder", "Invalid provider configuration");
        return null;
    }

    var endpointPath = provider.endpoints[endpointType];
    if (endpointPath === undefined || endpointPath === null) {
        logError("EndpointBuilder", "Endpoint type '" + endpointType + "' not found for provider");
        return null;
    }

    // Start with base URL
    var baseUrl = provider.base_url;

    // Handle empty endpoint path (e.g., Anthropic/Gemini models endpoint)
    if (endpointPath === '') {
        logInfo("EndpointBuilder", "Using base URL directly for " + endpointType + " endpoint");
        // For models endpoint with empty path, return base URL for listing
        if (endpointType === 'models') {
            return baseUrl;
        }
        return baseUrl;
    }

    // Substitute variables in endpoint path
    var processedPath = substituteVariables(endpointPath, variables || {});

    // Combine base URL and endpoint path
    var fullUrl = baseUrl + processedPath;

    // Clean up double slashes
    fullUrl = fullUrl.replace(/([^:])\/+/g, '$1/');

    // Append URL parameter auth if configured (e.g., Gemini ?key=...)
    options = options || {};
    if (provider.authentication && provider.authentication.urlParam && options.apiKey) {
        var sep = fullUrl.indexOf('?') === -1 ? '?' : '&';
        fullUrl = fullUrl + sep + provider.authentication.urlParam + '=' + encodeURIComponent(options.apiKey);
    }

    logInfo("EndpointBuilder", "Built URL for " + endpointType + ": " + fullUrl);
    return fullUrl;
}

/**
 * Build authentication header value
 * @param {object} provider - Provider configuration object
 * @param {string} apiKey - API key or authentication token
 * @returns {object} Authentication header object {name: value}
 */
function buildAuthHeader(provider, apiKey) {
    if (!provider || !provider.authentication) {
        logError("EndpointBuilder", "Provider authentication configuration missing");
        return null;
    }

    var authConfig = provider.authentication;
    var headerName = authConfig.header;
    var headerValue = '';

    if (authConfig.prefix && apiKey) {
        headerValue = authConfig.prefix + apiKey;
    } else {
        headerValue = apiKey || '';
    }

    logVerbose("EndpointBuilder", "Built auth header: " + headerName + "=***SET***");
    return {
        name: headerName,
        value: headerValue
    };
}

/**
 * Build all required headers for a request
 * @param {object} provider - Provider configuration object
 * @param {string} [apiKey] - API key for authentication
 * @returns {object} Headers object {headerName: headerValue}
 */
function buildHeaders(provider, apiKey) {
    if (!provider || !provider.headers) {
        logError("EndpointBuilder", "Provider headers configuration missing");
        return {};
    }

    var headers = {};
    var headersConfig = provider.headers;

    // Add required headers
    if (headersConfig.required && Array.isArray(headersConfig.required)) {
        for (var i = 0; i < headersConfig.required.length; i++) {
            var headerName = headersConfig.required[i];

            // Handle Content-Type specially
            if (headerName.toLowerCase() === 'content-type') {
                headers[headerName] = 'application/json';
            } else if (headerName.toLowerCase() === 'authorization' || headerName === provider.authentication.header) {
                // Skip auth headers here, will be added separately
                continue;
            } else {
                logError("EndpointBuilder", "Required header '" + headerName + "' needs value");
                return {};
            }
        }
    }

    // Add optional headers
    if (headersConfig.optional) {
        for (var optHeader in headersConfig.optional) {
            if (headersConfig.optional.hasOwnProperty(optHeader)) {
                headers[optHeader] = headersConfig.optional[optHeader];
            }
        }
    }

    // Add authentication header if API key provided (skip for URL param auth)
    var useUrlParamAuth = provider.authentication && provider.authentication.urlParam;
    if (!useUrlParamAuth && (apiKey || provider.requiredApiKey !== false)) {
        var authHeader = buildAuthHeader(provider, apiKey || '');
        if (authHeader) {
            headers[authHeader.name] = authHeader.value;
        }
    }

    logInfo("EndpointBuilder", "Built " + Object.keys(headers).length + " headers");
    return headers;
}

/**
 * Check if provider supports streaming
 * @param {object} provider - Provider configuration object
 * @returns {boolean} True if streaming is supported
 */
function supportsStreaming(provider) {
    return Boolean(provider && provider.features && provider.features.supportsStreaming);
}

/**
 * Check if provider supports images
 * @param {object} provider - Provider configuration object
 * @returns {boolean} True if images are supported
 */
function supportsImages(provider) {
    return Boolean(provider && provider.features && provider.features.supportsImages);
}

/**
 * Check if provider supports thinking mode
 * @param {object} provider - Provider configuration object
 * @returns {boolean} True if thinking mode is supported
 */
function supportsThinking(provider) {
    return Boolean(provider && provider.features && provider.features.supportsThinking);
}

/**
 * Get provider name
 * @param {object} provider - Provider configuration object
 * @returns {string} Human-readable provider name
 */
function getProviderName(provider) {
    return provider ? provider.name || 'Unknown' : 'Unknown';
}

/**
 * Get default models for provider
 * @param {object} provider - Provider configuration object
 * @returns {array} Array of default model names
 */
function getDefaultModels(provider) {
    return (provider && provider.defaultModels) ? provider.defaultModels.slice() : [];
}

/**
 * Substitute variables in endpoint path
 * @param {string} path - Endpoint path template
 * @param {object} variables - Variables to substitute
 * @returns {string} Path with variables substituted
 */
function substituteVariables(path, variables) {
    if (!path || typeof path !== 'string') {
        return path;
    }

    var result = path;

    if (variables && typeof variables === 'object') {
        for (var variable in variables) {
            if (variables.hasOwnProperty(variable)) {
                var placeholder = '{' + variable + '}';
                var value = variables[variable] || '';
                result = result.replace(new RegExp(placeholder, 'g'), value);
            }
        }
    }

    return result;
}

/**
 * Build request data object for API calls
 * @param {object} provider - Provider configuration object
 * @param {string} model - Model name
 * @param {array} messages - Array of conversation messages
 * @param {object} [options] - Additional options (streaming, temperature, etc.)
 * @returns {object} Request data object
 */
function buildRequestData(provider, model, messages, options) {
    options = options || {};

    var requestData = {};
    var providerType = provider.type || provider.id || '';

    // If custom contents/messages provided (for multimodal), use them directly
    if (providerType === 'gemini' && options.customContents) {
        requestData.contents = options.customContents;
        requestData.generationConfig = {
            temperature: options.temperature || 0.7,
            maxOutputTokens: options.maxTokens || 2048
        };
        if (supportsThinking(provider) && options.enableThinking) {
            requestData.systemInstruction = {
                parts: [{text: "Think step by step and show your reasoning process."}]
            };
        }
        logInfo("EndpointBuilder", "Built request data with custom contents (multimodal)");
        return requestData;
    }

    if (options.customMessages) {
        // Anthropic format with custom messages
        if (providerType === 'anthropic') {
            requestData.model = model;
            requestData.messages = options.customMessages;
            requestData.max_tokens = options.maxTokens || 2048;
            requestData.temperature = options.temperature || 0.7;
            if (supportsStreaming(provider) && options.streaming) {
                requestData.stream = true;
            }
        } else {
            // OpenAI-compatible with custom messages
            requestData.model = model;
            requestData.messages = options.customMessages;
            requestData.temperature = options.temperature || 0.7;
            requestData.max_tokens = options.maxTokens || 2048;
            if (supportsStreaming(provider) && options.streaming) {
                requestData.stream = true;
            }
        }
        logInfo("EndpointBuilder", "Built request data with custom messages (multimodal)");
        return requestData;
    }

    if (providerType === 'gemini') {
        // Gemini format
        requestData.contents = [];

        // Convert messages to Gemini format
        if (messages && Array.isArray(messages)) {
            for (var i = 0; i < messages.length; i++) {
                var msg = messages[i];
                var geminiRole = msg.role === 'user' ? 'user' : 'model';
                requestData.contents.push({
                    role: geminiRole,
                    parts: [{text: msg.message || msg.content}]
                });
            }
        }

        requestData.generationConfig = {
            temperature: options.temperature || 0.7,
            maxOutputTokens: options.maxTokens || 2048
        };

        // Add thinking mode if supported
        if (supportsThinking(provider) && options.enableThinking) {
            requestData.systemInstruction = {
                parts: [{text: "Think step by step and show your reasoning process."}]
            };
        }
    } else if (providerType === 'anthropic') {
        // Anthropic format
        requestData.model = model;
        requestData.messages = [];
        requestData.max_tokens = options.maxTokens || 2048;

        // Convert messages to Anthropic format
        if (messages && Array.isArray(messages)) {
            for (var k = 0; k < messages.length; k++) {
                var msg = messages[k];
                var anthropicRole = msg.role === 'bot' ? 'assistant' : msg.role;

                // Skip system messages - they go in the top-level system field
                if (anthropicRole === 'system') {
                    continue;
                }

                requestData.messages.push({
                    role: anthropicRole,
                    content: msg.message || msg.content
                });
            }
        }

        // Add system prompt if provided
        if (options.systemPrompt) {
            requestData.system = options.systemPrompt;
        }

        requestData.temperature = options.temperature || 0.7;

        // Add streaming flag if supported and requested
        if (supportsStreaming(provider) && options.streaming) {
            requestData.stream = true;
        }

        // Add thinking mode if supported
        if (supportsThinking(provider) && options.enableThinking) {
            requestData.thinking = {
                type: "enabled",
                budget_tokens: options.thinkingBudget || 10000
            };
        }
    } else {
        // OpenAI-compatible format
        requestData.model = model;
        requestData.messages = [];

        // Convert messages to OpenAI format
        if (messages && Array.isArray(messages)) {
            for (var j = 0; j < messages.length; j++) {
                var msg = messages[j];
                var openaiRole = msg.role === 'bot' ? 'assistant' : msg.role;
                requestData.messages.push({
                    role: openaiRole,
                    content: msg.message || msg.content
                });
            }
        }

        requestData.temperature = options.temperature || 0.7;
        requestData.max_tokens = options.maxTokens || 2048;

        // Add streaming flag if supported and requested
        if (supportsStreaming(provider) && options.streaming) {
            requestData.stream = true;
        }

        // Add thinking mode if supported
        if (supportsThinking(provider) && options.enableThinking) {
            requestData.thinking = true;
        }
    }

    logInfo("EndpointBuilder", "Built request data with " + (requestData.messages ? requestData.messages.length : (requestData.contents ? requestData.contents.length : 0)) + " messages");
    return requestData;
}

/**
 * Filter messages to ensure role alternation (no consecutive same-role messages)
 * Required for Anthropic, good practice for all providers
 * @param {array} messages - Array of message objects with 'role' property
 * @returns {array} Filtered messages with alternating roles
 */
function filterRoleAlternation(messages) {
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
        return messages;
    }

    var filtered = [];
    var lastRole = '';

    for (var i = 0; i < messages.length; i++) {
        var currentRole = messages[i].role;
        if (currentRole !== lastRole) {
            filtered.push(messages[i]);
            lastRole = currentRole;
        }
    }

    return filtered;
}