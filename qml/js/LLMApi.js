// LLM REST API interface with alias-based provider system
.pragma library

// Import debug logger
Qt.include("DebugLogger.js")

// Provider alias storage
var providerAliases = {};

// Availability status for each alias
var aliasAvailability = {};

// Cached models for each alias
var aliasModels = {};

// Legacy storage removed - using alias-based configuration

// Provider type definitions
var providerTypes = {
    "openai": {
        "name": "OpenAI Compatible",
        "defaultUrl": "https://api.openai.com/v1",
        "defaultModels": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
        "authHeader": "Authorization",
        "authPrefix": "Bearer ",
        "supportsStreaming": true
    },
    "anthropic": {
        "name": "Anthropic Claude",
        "defaultUrl": "https://api.anthropic.com/v1",
        "defaultModels": ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"],
        "authHeader": "Authorization",
        "authPrefix": "Bearer ",
        "supportsStreaming": true
    },
    "gemini": {
        "name": "Google Gemini",
        "defaultUrl": "https://generativelanguage.googleapis.com/v1beta/models",
        "defaultModels": ["gemini-2.0-flash-exp", "gemini-1.5-flash", "gemini-1.5-pro"],
        "authHeader": "x-goog-api-key",
        "supportsStreaming": true
    },
    "ollama": {
        "name": "Ollama Local",
        "defaultUrl": "http://localhost:11434/v1",
        "defaultModels": ["llama3.2", "mistral", "codellama"],
        "authHeader": "Authorization",
        "authPrefix": "Bearer ",
        "supportsStreaming": true
    }
};

// Default provider initialization removed - users create aliases manually

// Expose provider types for external access
function getProviderTypes() {
    return providerTypes;
}

// Provider alias management
function addProviderAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking) {
    if (!providerTypes[type]) {
        logError("LLMApi", "Invalid provider type: " + type);
        return false;
    }
    
    var alias = {
        name: name,
        type: type,
        url: url || providerTypes[type].defaultUrl,
        api_key: apiKey || "",
        port: port || "",
        description: description || "",
        timeout: timeout || 10000,
        favoriteModel: favoriteModel || providerTypes[type].defaultModels[0],
        enableThinking: enableThinking || false,
        isDefault: false
    };
    
    providerAliases[aliasId] = alias;
    aliasAvailability[aliasId] = "unchecked";
    aliasModels[aliasId] = []; // Start with empty models - will be filled by API calls
    
    logInfo("LLMApi", "Added provider alias: " + aliasId + " (" + name + ") with favorite model: " + alias.favoriteModel);
    return true;
}

function removeProviderAlias(aliasId) {
    if (providerAliases[aliasId] && !providerAliases[aliasId].isDefault) {
        delete providerAliases[aliasId];
        delete aliasAvailability[aliasId];
        delete aliasModels[aliasId];
        logInfo("LLMApi", "Removed provider alias: " + aliasId);
        return true;
    }
    return false;
}

function getProviderAliases() {
    return Object.keys(providerAliases);
}

function getProviderAlias(aliasId) {
    return providerAliases[aliasId] || null;
}

function getAliasAvailability(aliasId) {
    return aliasAvailability[aliasId] || "unchecked";
}

function getAliasModels(aliasId) {
    return aliasModels[aliasId] || [];
}

function getAliasFavoriteModel(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? alias.favoriteModel : "";
}

function setAliasFavoriteModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (alias) {
        alias.favoriteModel = model;
        logVerbose("LLMApi", "Set favorite model for " + aliasId + ": " + model);
        return true;
    }
    return false;
}

function setAliasThinkingMode(aliasId, enabled) {
    var alias = providerAliases[aliasId];
    if (alias) {
        alias.enableThinking = enabled || false;
        logInfo("LLMApi", "Set thinking mode for " + aliasId + ": " + (enabled ? "enabled" : "disabled"));
        return true;
    }
    return false;
}

function getAliasThinkingMode(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? alias.enableThinking || false : false;
}

function updateProviderAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("LLMApi", "Alias not found for update: " + aliasId);
        return false;
    }
    
    if (!alias.isDefault) {
        alias.name = name || alias.name;
        alias.url = url || alias.url;
        alias.description = description || alias.description;
        alias.timeout = timeout || alias.timeout;
    }
    
    alias.api_key = apiKey || alias.api_key;
    alias.favoriteModel = favoriteModel || alias.favoriteModel;
    if (typeof enableThinking !== 'undefined') {
        alias.enableThinking = enableThinking;
    }
    
    logInfo("LLMApi", "Updated provider alias: " + aliasId);
    return true;
}

// Availability checking (simplified without timeout for QML JavaScript compatibility)
function checkAliasAvailability(aliasId, callback) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("LLMApi", "Alias not found: " + aliasId);
        callback(false, "Alias not found");
        return;
    }
    
    if (!alias.api_key && alias.type !== "ollama") {
        logInfo("LLMApi", "No API key for alias: " + aliasId);
        aliasAvailability[aliasId] = "no_key";
        callback(false, "No API key configured");
        return;
    }
    
    aliasAvailability[aliasId] = "checking";
    logVerbose("LLMApi", "Checking availability for alias: " + aliasId);
    
    var xhr = new XMLHttpRequest();
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 401 || xhr.status === 403) {
                // 200 = success, 401/403 = auth issue but server is reachable
                aliasAvailability[aliasId] = "available";
                logInfo("LLMApi", "Alias available: " + aliasId + " (status: " + xhr.status + ")");
                callback(true, "Available");
                
                // Fetch models in background
                fetchModelsForAlias(aliasId);
            } else if (xhr.status === 0) {
                // Network error or timeout
                aliasAvailability[aliasId] = "timeout";
                logInfo("LLMApi", "Alias timeout/network error: " + aliasId);
                callback(false, "Network error");
            } else {
                aliasAvailability[aliasId] = "error";
                logInfo("LLMApi", "Alias unavailable: " + aliasId + " (status: " + xhr.status + ")");
                callback(false, "HTTP " + xhr.status);
            }
        }
    };
    
    try {
        var pingUrl = alias.url;
        if (alias.type === "ollama") {
            pingUrl += "/models";
        } else if (alias.type === "openai" || alias.type === "anthropic") {
            pingUrl += "/models";
        } else if (alias.type === "gemini") {
            pingUrl = alias.url; // Already includes the models endpoint
        }
        
        xhr.open("GET", pingUrl, true);
        
        // Set a reasonable timeout (browser default is usually fine)
        xhr.timeout = alias.timeout || 10000;
        xhr.ontimeout = function() {
            aliasAvailability[aliasId] = "timeout";
            logInfo("LLMApi", "Availability check timeout for alias: " + aliasId);
            callback(false, "Timeout");
        };
        
        // Set authentication headers
        var typeInfo = providerTypes[alias.type];
        if (alias.api_key && typeInfo.authHeader) {
            var authValue = alias.api_key;
            if (typeInfo.authPrefix) {
                authValue = typeInfo.authPrefix + authValue;
            }
            xhr.setRequestHeader(typeInfo.authHeader, authValue);
        }
        
        logVerbose("LLMApi", "Sending availability check to: " + pingUrl);
        xhr.send();
    } catch (e) {
        aliasAvailability[aliasId] = "error";
        logError("LLMApi", "Failed to check availability for alias " + aliasId + ": " + e.toString());
        callback(false, e.toString());
    }
}

// Background model fetching (simplified without setTimeout)
function fetchModelsForAlias(aliasId) {
    var alias = providerAliases[aliasId];
    if (!alias || !alias.api_key) {
        logVerbose("LLMApi", "Skipping model fetch for alias without API key: " + aliasId);
        return;
    }
    
    logInfo("LLMApi", "Starting model fetch for alias: " + aliasId + " (type: " + alias.type + ")");
    
    // Construct URL first
    var modelsUrl = alias.url;
    if (alias.type === "gemini") {
        // Already the correct endpoint
        logInfo("LLMApi", "Using Gemini models URL: " + modelsUrl);
    } else {
        modelsUrl += "/models";
        logInfo("LLMApi", "Using OpenAI-compatible models URL: " + modelsUrl);
    }
    
    var xhr = new XMLHttpRequest();
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            // FORCE LOG - always visible
            console.log("=== MODEL FETCH RESPONSE DEBUG ===");
            console.log("Status: " + xhr.status + " (" + xhr.statusText + ")");
            console.log("URL: " + modelsUrl);
            console.log("Response length: " + (xhr.responseText ? xhr.responseText.length : 0));
            if (xhr.status !== 200) {
                console.log("ERROR Response: " + xhr.responseText);
            } else {
                console.log("SUCCESS Response (first 200 chars): " + (xhr.responseText ? xhr.responseText.substring(0, 200) : ""));
            }
            
            logInfo("LLMApi", "Model fetch HTTP Response - Status: " + xhr.status + ", URL: " + modelsUrl);
            if (xhr.status !== 200) {
                logError("LLMApi", "Model fetch HTTP Error Response: " + xhr.responseText);
            }
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    logVerbose("LLMApi", "Raw response for alias " + aliasId + ": " + xhr.responseText.substring(0, 200) + "...");
                    var models = [];
                    
                    if (alias.type === "gemini") {
                        if (response.models) {
                            for (var i = 0; i < response.models.length; i++) {
                                var model = response.models[i];
                                var modelName = null;
                                
                                // Handle different response formats
                                if (typeof model === "string") {
                                    modelName = model;
                                } else if (model && typeof model.name === "string") {
                                    modelName = model.name;
                                } else {
                                    logVerbose("LLMApi", "Skipping invalid model entry: " + JSON.stringify(model));
                                    continue;
                                }
                                
                                // Remove "models/" prefix if present
                                if (modelName && modelName.indexOf && modelName.indexOf("models/") === 0) {
                                    modelName = modelName.substring(7);
                                }
                                
                                if (modelName) {
                                    models.push(modelName);
                                }
                            }
                        }
                    } else {
                        // OpenAI-compatible format
                        if (response.data) {
                            for (var i = 0; i < response.data.length; i++) {
                                var model = response.data[i];
                                if (model && model.id) {
                                    models.push(model.id);
                                }
                            }
                        }
                    }
                    
                    if (models.length > 0) {
                        aliasModels[aliasId] = models;
                        logInfo("LLMApi", "Fetched " + models.length + " models for alias: " + aliasId);
                    } else {
                        logInfo("LLMApi", "No models found for alias: " + aliasId);
                    }
                } catch (e) {
                    logError("LLMApi", "Failed to parse models response for alias " + aliasId + ": " + e.toString());
                }
            } else if (xhr.status === 0) {
                logInfo("LLMApi", "Model fetch timeout/network error for alias: " + aliasId);
            } else {
                logInfo("LLMApi", "Failed to fetch models for alias " + aliasId + " (status: " + xhr.status + ")");
            }
        }
    };
    
    try {
        logInfo("LLMApi", "Opening XMLHttpRequest to: " + modelsUrl);
        xhr.open("GET", modelsUrl, true);
        
        // Set timeout
        xhr.timeout = alias.timeout || 10000;
        xhr.ontimeout = function() {
            logInfo("LLMApi", "Model fetch timeout for alias: " + aliasId);
        };
        
        var typeInfo = providerTypes[alias.type];
        var headers = [];
        if (typeInfo.authHeader) {
            var authValue = alias.api_key;
            if (typeInfo.authPrefix) {
                authValue = typeInfo.authPrefix + authValue;
            }
            xhr.setRequestHeader(typeInfo.authHeader, authValue);
            headers.push(typeInfo.authHeader + "=" + (typeInfo.authPrefix || "") + "***SET***");
        }
        
        // FORCE LOG - always visible regardless of debug level
        console.log("=== MODEL FETCH REQUEST DEBUG ===");
        console.log("Method: GET");
        console.log("Full URL: " + modelsUrl);
        console.log("Provider: " + alias.type);
        console.log("Base URL: " + alias.url);
        console.log("Headers: " + headers.join(", "));
        
        logVerbose("LLMApi", "=== COMPLETE MODEL FETCH REQUEST ===");
        logVerbose("LLMApi", "Method: GET");
        logVerbose("LLMApi", "URL: " + modelsUrl);
        logVerbose("LLMApi", "Provider Type: " + alias.type);
        logVerbose("LLMApi", "Headers: " + headers.join(", "));
        
        // Log curl equivalent
        var curlCmd = "curl -X GET '" + modelsUrl + "'";
        if (headers.length > 0) {
            for (var h = 0; h < headers.length; h++) {
                var headerParts = headers[h].split("=");
                curlCmd += " \\\n  -H '" + headerParts[0] + ": " + (headerParts[1] || "YOUR_API_KEY") + "'";
            }
        }
        logVerbose("LLMApi", "Curl equivalent: " + curlCmd);
        
        xhr.send();
    } catch (e) {
        logError("LLMApi", "Failed to fetch models for alias " + aliasId + ": " + e.toString());
    }
}

// Check all aliases for availability
function checkAllAliasesAvailability(callback) {
    var aliases = getProviderAliases();
    var completed = 0;
    var results = {};
    
    if (aliases.length === 0) {
        callback(results);
        return;
    }
    
    logInfo("LLMApi", "Checking availability for " + aliases.length + " aliases");
    
    for (var i = 0; i < aliases.length; i++) {
        var aliasId = aliases[i];
        
        checkAliasAvailability(aliasId, function(available, status) {
            completed++;
            results[aliasId] = {available: available, status: status};
            
            if (completed === aliases.length) {
                logInfo("LLMApi", "Completed availability check for all aliases");
                callback(results);
            }
        });
    }
}

// Configuration persistence
function loadProviderAliases(aliasesJson) {
    try {
        var aliases = JSON.parse(aliasesJson);
        for (var aliasId in aliases) {
            if (aliases.hasOwnProperty(aliasId)) {
                providerAliases[aliasId] = aliases[aliasId];
                aliasAvailability[aliasId] = "unchecked";
                aliasModels[aliasId] = []; // Start with empty models - will be filled by API calls when needed
            }
        }
        logInfo("LLMApi", "Loaded " + Object.keys(aliases).length + " provider aliases");
    } catch (e) {
        logError("LLMApi", "Failed to load provider aliases: " + e.toString());
    }
}

function saveProviderAliases() {
    try {
        return JSON.stringify(providerAliases);
    } catch (e) {
        logError("LLMApi", "Failed to save provider aliases: " + e.toString());
        return "";
    }
}

// Legacy compatibility functions removed - use alias-based functions directly

// Global variable to accumulate Gemini streaming response
var geminiStreamBuffer = "";

// Process streaming response chunks
function processStreamChunk(chunk, streamCallback, providerType) {
    try {
        if (providerType === "gemini") {
            // Gemini streaming: accumulate chunks to parse complete JSON objects
            logVerbose("LLMApi", "Processing Gemini streaming chunk: " + chunk.substring(0, 100) + "...");
            
            // Accumulate this chunk
            geminiStreamBuffer += chunk;
            logVerbose("LLMApi", "Gemini buffer length: " + geminiStreamBuffer.length);
            
            // Try to extract complete JSON objects from the buffer
            var remaining = geminiStreamBuffer;
            var objectStart = 0;
            var braceCount = 0;
            var inString = false;
            var escaped = false;
            
            for (var i = 0; i < remaining.length; i++) {
                var char = remaining.charAt(i);
                
                if (escaped) {
                    escaped = false;
                    continue;
                }
                
                if (char === '\\') {
                    escaped = true;
                    continue;
                }
                
                if (char === '"') {
                    inString = !inString;
                    continue;
                }
                
                if (inString) {
                    continue;
                }
                
                if (char === '{') {
                    if (braceCount === 0) {
                        objectStart = i;
                    }
                    braceCount++;
                } else if (char === '}') {
                    braceCount--;
                    if (braceCount === 0) {
                        // Found complete object
                        var jsonObject = remaining.substring(objectStart, i + 1);
                        try {
                            var response = JSON.parse(jsonObject);
                            
                            // Extract content from this complete object
                            var candidates = response.candidates;
                            if (candidates && candidates.length > 0) {
                                var candidate = candidates[0];
                                if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
                                    var content = candidate.content.parts[0].text || "";
                                    if (content) {
                                        logInfo("LLMApi", "=== GEMINI STREAM OBJECT ===");
                                        logInfo("LLMApi", "Gemini stream object content: " + content.substring(0, 50) + "...");
                                        streamCallback(content);
                                    }
                                }
                            }
                        } catch (e) {
                            logError("LLMApi", "Error parsing Gemini JSON object: " + e.toString());
                        }
                        
                        // Remove processed object from buffer (keep any remaining text)
                        remaining = remaining.substring(i + 1);
                        i = -1; // Reset loop
                        objectStart = 0;
                    }
                }
            }
            
            // Update buffer with remaining unparsed text
            geminiStreamBuffer = remaining;
        } else {
            // Standard SSE format for OpenAI/Anthropic
            var lines = chunk.split('\n');
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.indexOf('data: ') === 0) {
                    var jsonData = line.substring(6); // Remove "data: " prefix
                    
                    if (jsonData === '[DONE]') {
                        logVerbose("LLMApi", "Stream completed");
                        return;
                    }
                    
                    if (jsonData) {
                        var data = JSON.parse(jsonData);
                        var content = "";
                        
                        if (providerType === "anthropic") {
                            // Anthropic streaming format
                            if (data.type === "content_block_delta" && data.delta && data.delta.text) {
                                content = data.delta.text;
                            }
                        } else {
                            // OpenAI-compatible streaming format
                            if (data.choices && data.choices.length > 0 && data.choices[0].delta && data.choices[0].delta.content) {
                                content = data.choices[0].delta.content;
                            }
                        }
                        
                        if (content) {
                            logVerbose("LLMApi", "Streaming chunk: " + content.substring(0, 50) + "...");
                            streamCallback(content);
                        }
                    }
                }
            }
        }
    } catch (e) {
        logError("LLMApi", "Error processing stream chunk: " + e.toString());
    }
}

// Base64 encoding helper function
function encodeImageToBase64(imagePath) {
    logInfo("LLMApi", "Image conversion requested for: " + imagePath);
    logInfo("LLMApi", "Note: Real image loading not yet implemented - using test image");
    
    // TODO: Implement real image loading for Sailfish OS
    // Current challenge: File access restrictions in Sailfish OS QML environment
    // Potential solutions to explore:
    // 1. Native C++ FileIO component  
    // 2. PyOtherSide bridge for Python-based image processing
    // 3. Sailfish-specific file handling APIs
    
    logInfo("LLMApi", "Real image conversion not yet implemented");
    
    // Fallback: Use a test image that works
    logError("LLMApi", "Using fallback test image for: " + imagePath);
    
    // This is a simple red circle on white background - should be clearly visible
    var testJpegBase64 = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAgACADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9/KKKKAP/2Q==";
    
    return {
        data: testJpegBase64,
        mimeType: "image/jpeg"
    };
}

// Enhanced content generation with image support
function generateContentWithImages(aliasId, model, prompt, apiKey, history, images, callback, errorCallback, streamCallback) {
    logInfo("LLMApi", "=== generateContentWithImages START ===");
    logInfo("LLMApi", "Parameters - aliasId: " + aliasId + ", model: " + model + ", images: " + (images ? images.length : 0));
    
    // Support multimodal for Gemini and OpenAI
    var alias = providerAliases[aliasId];
    if (!alias || (alias.type !== "gemini" && alias.type !== "openai")) {
        errorCallback("Multimodal support currently available for Gemini and OpenAI providers only");
        return;
    }
    
    var customContents = null;
    
    if (alias.type === "gemini") {
        // Build Gemini multimodal request - images first, then text
        var parts = [];
        
        // Add image parts first (as per Google example)
        if (images && images.length > 0) {
            for (var i = 0; i < images.length; i++) {
                var imagePath = images[i];
                logInfo("LLMApi", "Processing Gemini image: " + imagePath);
                
                // Convert image to base64
                var imageInfo = encodeImageToBase64(imagePath);
                parts.push({
                    "inline_data": {
                        "mime_type": imageInfo.mimeType,
                        "data": imageInfo.data
                    }
                });
            }
        }
        
        // Add text part after images
        if (prompt && prompt.trim() !== "") {
            parts.push({"text": prompt});
        }
        
        // Build Gemini multimodal contents
        customContents = [];
        
        // Add history
        if (history && history.length > 0) {
            for (var i = 0; i < history.length; i++) {
                var msg = history[i];
                if (msg.role === "user") {
                    customContents.push({
                        "role": "user",
                        "parts": [{"text": msg.message}]
                    });
                } else if (msg.role === "bot") {
                    customContents.push({
                        "role": "model",
                        "parts": [{"text": msg.message}]
                    });
                }
            }
        }
        
        // Add current multimodal message (without role for multimodal)
        customContents.push({
            "parts": parts
        });
        
        // Call internal function with pre-built Gemini contents (disable streaming for multimodal)
        generateContentInternal(aliasId, model, null, apiKey, null, callback, errorCallback, null, customContents, null);
        
    } else if (alias.type === "openai") {
        // Build OpenAI multimodal request
        var messages = [];
        
        // Add history
        if (history && history.length > 0) {
            for (var i = 0; i < history.length; i++) {
                var msg = history[i];
                if (msg.role === "user") {
                    messages.push({
                        "role": "user",
                        "content": msg.message
                    });
                } else if (msg.role === "bot") {
                    messages.push({
                        "role": "assistant",
                        "content": msg.message
                    });
                }
            }
        }
        
        // Build multimodal content array for current message
        var content = [];
        
        // Add text part
        if (prompt && prompt.trim() !== "") {
            content.push({
                "type": "text",
                "text": prompt
            });
        }
        
        // Add image parts
        if (images && images.length > 0) {
            for (var i = 0; i < images.length; i++) {
                var imagePath = images[i];
                logInfo("LLMApi", "Processing OpenAI image: " + imagePath);
                
                // Convert image to base64
                var imageInfo = encodeImageToBase64(imagePath);
                content.push({
                    "type": "image_url",
                    "image_url": {
                        "url": "data:" + imageInfo.mimeType + ";base64," + imageInfo.data
                    }
                });
            }
        }
        
        // Add current multimodal message
        messages.push({
            "role": "user",
            "content": content
        });
        
        // Call internal function with pre-built OpenAI messages (disable streaming for multimodal)
        generateContentInternal(aliasId, model, null, apiKey, null, callback, errorCallback, null, null, messages);
    }
}

// Content generation (updated to work with aliases)
function generateContent(aliasId, model, prompt, apiKey, history, callback, errorCallback, streamCallback) {
    generateContentInternal(aliasId, model, prompt, apiKey, history, callback, errorCallback, streamCallback, null, null);
}

// Internal content generation function
function generateContentInternal(aliasId, model, prompt, apiKey, history, callback, errorCallback, streamCallback, customContents, customMessages) {
    logInfo("LLMApi", "=== generateContentInternal START ===");
    logInfo("LLMApi", "Parameters - aliasId: " + aliasId + ", model: " + model + ", prompt length: " + (prompt ? prompt.length : 0));
    logInfo("LLMApi", "Available aliases: " + Object.keys(providerAliases).join(", "));
    logInfo("LLMApi", "Custom contents provided: " + (customContents ? "YES" : "NO"));
    
    // Reset Gemini stream buffer for new request
    geminiStreamBuffer = "";
    
    var alias = providerAliases[aliasId];
    logInfo("LLMApi", "Alias lookup result: " + (alias ? "FOUND" : "NOT FOUND"));
    if (alias) {
        logInfo("LLMApi", "Alias details - name: " + alias.name + ", type: " + alias.type + ", url: " + alias.url);
    }
    
    if (!alias) {
        // Fallback to legacy provider lookup for non-multimodal requests
        if (!customContents) {
            var legacyConfig = global_config[aliasId];
            if (legacyConfig) {
                logInfo("LLMApi", "Using legacy config for: " + aliasId);
                generateContentLegacy(aliasId, model, prompt, apiKey, history, callback, errorCallback);
                return;
            }
        }
        
        errorCallback("Unknown provider alias: " + aliasId);
        return;
    }
    
    logInfo("LLMApi", "Generating content with alias: " + aliasId + ", model: " + model);
    logInfo("LLMApi", "Alias details - Type: " + alias.type + ", URL: " + alias.url + ", API Key: " + (alias.api_key ? "***set***" : "empty"));
    
    var xhr = new XMLHttpRequest();
    var url, requestData;
    var actualApiKey = alias.api_key || apiKey;
    var typeInfo = providerTypes[alias.type]; // Define typeInfo early for all providers
    
    if (!actualApiKey && alias.type !== "ollama") {
        errorCallback("No API key configured for alias: " + aliasId);
        return;
    }
    
    if (alias.type === "gemini") {
        // For Gemini, remove any models/ prefix from model name since base URL already includes /models
        var geminiModel = model;
        logInfo("LLMApi", "Original Gemini model: " + model);
        
        // Remove models/ prefix if present - base URL already includes /models
        if (geminiModel.indexOf("models/") === 0) {
            geminiModel = geminiModel.substring(7);
            logInfo("LLMApi", "Removed models/ prefix, clean model: " + geminiModel);
        }
        
        // Construct URL: check if streaming is enabled
        var isGeminiStreaming = streamCallback && typeInfo.supportsStreaming;
        if (isGeminiStreaming) {
            url = alias.url + "/" + geminiModel + ":streamGenerateContent";
            logInfo("LLMApi", "Gemini streaming URL constructed: " + url);
        } else {
            url = alias.url + "/" + geminiModel + ":generateContent";
            logInfo("LLMApi", "Gemini non-streaming URL constructed: " + url);
        }
        logInfo("LLMApi", "Gemini base URL: " + alias.url);
        
        // Build conversation history for Gemini
        var contents = [];
        
        if (customContents) {
            // Use pre-built contents for multimodal requests
            contents = customContents;
            logInfo("LLMApi", "Using custom multimodal contents with " + contents.length + " messages");
        } else {
            // Build standard text-only contents
            if (history && history.length > 0) {
                for (var i = 0; i < history.length; i++) {
                    var msg = history[i];
                    if (msg.role === "user") {
                        contents.push({
                            "role": "user",
                            "parts": [{"text": msg.message}]
                        });
                    } else if (msg.role === "bot") {
                        contents.push({
                            "role": "model",
                            "parts": [{"text": msg.message}]
                        });
                    }
                }
            }
            
            contents.push({
                "role": "user", 
                "parts": [{"text": prompt}]
            });
        }
        
        var generationConfig = {
            "temperature": 0.7,
            "maxOutputTokens": 2048
        };
        
        // Check if thinking mode is enabled for this alias
        var enableThinking = alias.enableThinking || false;
        if (enableThinking) {
            // Add thinking-specific configuration for Gemini
            generationConfig.candidateCount = 1;
            generationConfig.stopSequences = [];
            // Note: Thinking mode in Gemini may require specific system instructions
            logInfo("LLMApi", "Thinking mode enabled for Gemini alias: " + aliasId);
        }
        
        requestData = {
            "contents": contents,
            "generationConfig": generationConfig
        };
        
        // Add thinking mode system instruction if enabled
        if (enableThinking) {
            requestData.systemInstruction = {
                "parts": [{"text": "Think step by step and show your reasoning process before providing the final answer. Use <thinking> tags to show your thought process."}]
            };
        }
        
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("x-goog-api-key", actualApiKey);
        
        logVerbose("LLMApi", "Gemini Headers: Content-Type=application/json, x-goog-api-key=" + (actualApiKey ? "***SET***" : "EMPTY"));
        
    } else {
        // OpenAI-compatible format
        url = alias.url + "/chat/completions";
        logInfo("LLMApi", "OpenAI-compatible base URL: " + alias.url);
        logInfo("LLMApi", "OpenAI-compatible full URL constructed: " + url);
        
        var messages = [];
        
        if (customMessages) {
            // Use pre-built messages for multimodal requests
            messages = customMessages;
            logInfo("LLMApi", "Using custom multimodal messages with " + messages.length + " entries");
        } else {
            // Build standard text-only messages
            if (history && history.length > 0) {
                logInfo("LLMApi", "Processing conversation history with " + history.length + " messages");
                for (var i = 0; i < history.length; i++) {
                    var msg = history[i];
                    logVerbose("LLMApi", "History[" + i + "]: role=" + msg.role + ", message length=" + (msg.message ? msg.message.length : 0));
                    if (msg.role === "user") {
                        messages.push({
                            "role": "user",
                            "content": msg.message
                        });
                    } else if (msg.role === "bot") {
                        messages.push({
                            "role": "assistant",
                            "content": msg.message
                        });
                    } else {
                        logInfo("LLMApi", "Skipping message with unknown role: " + msg.role);
                    }
                }
            }
            
            // Check for role alternation to prevent "roles must alternate" error
            var lastRole = "";
            var validMessages = [];
            for (var j = 0; j < messages.length; j++) {
                var currentRole = messages[j].role;
                if (currentRole !== lastRole) {
                    validMessages.push(messages[j]);
                    lastRole = currentRole;
                } else {
                    logInfo("LLMApi", "Skipping duplicate role: " + currentRole + " at position " + j);
                }
            }
            messages = validMessages;
            logInfo("LLMApi", "Processed history into " + messages.length + " valid alternating messages");
            
            messages.push({
                "role": "user",
                "content": prompt
            });
        }
        
        requestData = {
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        };
        
        // Add streaming if supported and streamCallback is provided
        if (typeInfo && typeInfo.supportsStreaming && streamCallback) {
            // Only add stream parameter for non-Gemini providers
            if (alias.type !== "gemini") {
                requestData.stream = true;
                logInfo("LLMApi", "Enabled streaming for " + alias.type);
            } else {
                logInfo("LLMApi", "Gemini streaming enabled via URL endpoint (no stream parameter needed)");
            }
        }
        
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        
        var headers = ["Content-Type=application/json"];
        
        if (actualApiKey) {
            xhr.setRequestHeader("Authorization", "Bearer " + actualApiKey);
            headers.push("Authorization=Bearer ***SET***");
        }
        
        if (alias.type === "anthropic") {
            xhr.setRequestHeader("anthropic-version", "2023-06-01");
            headers.push("anthropic-version=2023-06-01");
        }
        
        logVerbose("LLMApi", "OpenAI-compatible Headers: " + headers.join(", "));
    }
    
    // Set timeout for generation request
    xhr.timeout = alias.timeout ? alias.timeout * 3 : 30000; // Longer timeout for generation
    xhr.ontimeout = function() {
        errorCallback("Request timeout");
    };
    
    var isStreamingEnabled = !!(typeInfo && typeInfo.supportsStreaming && streamCallback && (requestData.stream || alias.type === "gemini"));
    var processedLength = 0;
    
    xhr.onreadystatechange = function() {
        logVerbose("LLMApi", "XHR state change - readyState: " + xhr.readyState + ", status: " + xhr.status + ", isStreaming: " + isStreamingEnabled);
        
        // Handle streaming responses during LOADING state
        if (isStreamingEnabled && xhr.readyState === XMLHttpRequest.LOADING && xhr.status === 200) {
            var newText = xhr.responseText.substring(processedLength);
            logInfo("LLMApi", "=== STREAMING CHUNK DEBUG ===");
            logInfo("LLMApi", "ReadyState: " + xhr.readyState + ", Status: " + xhr.status);
            logInfo("LLMApi", "Total response length: " + xhr.responseText.length);
            logInfo("LLMApi", "Processed length: " + processedLength);
            logInfo("LLMApi", "New text length: " + newText.length);
            logInfo("LLMApi", "New text preview: " + newText.substring(0, 100) + "...");
            
            if (newText.length > 0) {
                processedLength = xhr.responseText.length;
                processStreamChunk(newText, streamCallback, alias.type);
            }
        }
        
        if (xhr.readyState === XMLHttpRequest.DONE) {
            // FORCE LOG - always visible
            console.log("=== GENERATION RESPONSE DEBUG ===");
            console.log("Status: " + xhr.status + " (" + xhr.statusText + ")");
            console.log("URL: " + url);
            console.log("Response length: " + (xhr.responseText ? xhr.responseText.length : 0));
            console.log("Streaming enabled: " + isStreamingEnabled);
            if (xhr.status !== 200) {
                console.log("ERROR Response: " + xhr.responseText);
            } else {
                console.log("SUCCESS Response (first 200 chars): " + (xhr.responseText ? xhr.responseText.substring(0, 200) : ""));
            }
            
            logInfo("LLMApi", "=== Generation HTTP Response ===");
            logInfo("LLMApi", "Status: " + xhr.status + " (" + xhr.statusText + ")");
            logInfo("LLMApi", "URL: " + url);
            logInfo("LLMApi", "Response length: " + (xhr.responseText ? xhr.responseText.length : 0));
            if (xhr.status !== 200) {
                logError("LLMApi", "Generation HTTP Error Response: " + xhr.responseText);
                logError("LLMApi", "Request headers were set for " + alias.type + " authentication");
            }
            
            if (xhr.status === 200) {
                if (isStreamingEnabled) {
                    // For streaming, we've already processed chunks, signal completion
                    logInfo("LLMApi", "Streaming response completed");
                    
                    // Gemini doesn't do real streaming - parse complete response
                    if (processedLength === 0 && alias.type === "gemini") {
                        logInfo("LLMApi", "Gemini pseudo-streaming: parsing complete response");
                        try {
                            var response = JSON.parse(xhr.responseText);
                            var content = "";
                            
                            // Handle both array and object response formats from Gemini
                            var geminiResponse = response;
                            if (Array.isArray(response) && response.length > 0) {
                                geminiResponse = response[0];
                                logInfo("LLMApi", "Using array[0] for Gemini response");
                            }
                            
                            if (geminiResponse.candidates && geminiResponse.candidates.length > 0) {
                                var candidate = geminiResponse.candidates[0];
                                if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
                                    content = candidate.content.parts[0].text;
                                    logInfo("LLMApi", "Successfully extracted Gemini content: " + content.length + " chars");
                                    
                                    // Simulate streaming by calling streamCallback with complete content
                                    if (streamCallback) {
                                        streamCallback(content);
                                    }
                                    
                                    // Signal completion without additional content
                                    callback("");
                                    return;
                                } else {
                                    logError("LLMApi", "Invalid Gemini candidate structure");
                                }
                            } else {
                                logError("LLMApi", "No candidates in Gemini response");
                            }
                            
                            // If we get here, parsing failed
                            logError("LLMApi", "Failed to extract content from Gemini response");
                            callback("");
                            
                        } catch (e) {
                            logError("LLMApi", "Failed to parse Gemini response: " + e.toString());
                            callback("");
                        }
                    } else {
                        // Normal streaming completion for other providers
                        logInfo("LLMApi", "Normal streaming completion");
                        callback("");
                    }
                } else {
                    // Non-streaming response handling
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var content = "";
                        
                        // Debug logging for response structure
                        logInfo("LLMApi", "=== RESPONSE PARSING DEBUG ===");
                        logInfo("LLMApi", "Response type: " + typeof response);
                        logInfo("LLMApi", "Is array: " + Array.isArray(response));
                        logInfo("LLMApi", "Response keys: " + Object.keys(response));
                        
                        if (alias.type === "gemini") {
                            // Handle both array and object response formats from Gemini
                            var geminiResponse = response;
                            if (Array.isArray(response) && response.length > 0) {
                                geminiResponse = response[0]; // Take first element if it's an array
                                logInfo("LLMApi", "Using array[0], keys: " + Object.keys(geminiResponse));
                            }
                            
                            logInfo("LLMApi", "Gemini response candidates: " + (geminiResponse.candidates ? geminiResponse.candidates.length : "undefined"));
                            
                            if (geminiResponse.candidates && geminiResponse.candidates.length > 0) {
                                var candidate = geminiResponse.candidates[0];
                                logInfo("LLMApi", "Candidate keys: " + Object.keys(candidate));
                                logInfo("LLMApi", "Has content: " + !!candidate.content);
                                
                                if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
                                    content = candidate.content.parts[0].text;
                                    logInfo("LLMApi", "Extracted content length: " + content.length);
                                } else {
                                    logError("LLMApi", "Invalid content structure in candidate");
                                }
                            } else {
                                logError("LLMApi", "No candidates found in gemini response");
                            }
                        } else {
                            if (response.choices && response.choices.length > 0) {
                                content = response.choices[0].message.content;
                            }
                        }
                        
                        if (content) {
                            logVerbose("LLMApi", "Generated content with alias: " + aliasId);
                            callback(content);
                        } else {
                            errorCallback("No content in response");
                        }
                    } catch (e) {
                        logError("LLMApi", "Failed to parse response: " + e.toString());
                        errorCallback("Failed to parse response: " + e.toString());
                    }
                }
            } else {
                logError("LLMApi", "Generation failed for alias " + aliasId + " (status: " + xhr.status + ")");
                try {
                    var errorResponse = JSON.parse(xhr.responseText);
                    var errorMsg = errorResponse.error ? errorResponse.error.message : "HTTP " + xhr.status;
                    errorCallback(errorMsg);
                } catch (e) {
                    errorCallback("HTTP " + xhr.status + ": " + xhr.statusText);
                }
            }
        }
    };
    
    try {
        var requestBody = JSON.stringify(requestData);
        
        // FORCE LOG - always visible regardless of debug level
        console.log("=== GENERATION REQUEST DEBUG ===");
        console.log("Method: POST");
        console.log("Full URL: " + url);
        console.log("Provider: " + alias.type);
        console.log("Base URL: " + alias.url);
        console.log("Model: " + model);
        console.log("API Key length: " + (actualApiKey ? actualApiKey.length : 0));
        console.log("Request Body: " + requestBody);
        
        logInfo("LLMApi", "=== COMPLETE REST REQUEST ===");
        logInfo("LLMApi", "Method: POST");
        logInfo("LLMApi", "URL: " + url);
        logInfo("LLMApi", "Provider Type: " + alias.type);
        logInfo("LLMApi", "API Key length: " + (actualApiKey ? actualApiKey.length : 0));
        logVerbose("LLMApi", "Full Request Body: " + requestBody);
        
        // Log curl equivalent for debugging
        var curlCommand = "curl -X POST '" + url + "' \\\n";
        curlCommand += "  -H 'Content-Type: application/json' \\\n";
        if (alias.type === "gemini") {
            curlCommand += "  -H 'x-goog-api-key: " + (actualApiKey ? "YOUR_API_KEY" : "MISSING") + "' \\\n";
        } else {
            if (actualApiKey) {
                curlCommand += "  -H 'Authorization: Bearer YOUR_API_KEY' \\\n";
            }
            if (alias.type === "anthropic") {
                curlCommand += "  -H 'anthropic-version: 2023-06-01' \\\n";
            }
        }
        curlCommand += "  -d '" + requestBody + "'";
        logVerbose("LLMApi", "Equivalent curl command:\n" + curlCommand);
        
        xhr.send(requestBody);
        logInfo("LLMApi", "Request sent successfully");
    } catch (e) {
        logError("LLMApi", "Failed to send generation request: " + e.toString());
        errorCallback("Failed to send request: " + e.toString());
    }
}

// Legacy generation function for backward compatibility
function generateContentLegacy(provider, model, prompt, apiKey, history, callback, errorCallback) {
    logInfo("LLMApi", "Using legacy generation for provider: " + provider);
    
    // Create temporary alias for legacy call
    var tempAliasId = "legacy_" + provider;
    var typeInfo = providerTypes[provider];
    
    if (!typeInfo) {
        errorCallback("Unknown legacy provider type: " + provider);
        return;
    }
    
    var legacyConfig = global_config[provider] || {};
    var tempAlias = {
        name: "Legacy " + provider,
        type: provider,
        url: legacyConfig.base_url || typeInfo.defaultUrl,
        api_key: apiKey || legacyConfig.api_key || "",
        timeout: 30000
    };
    
    providerAliases[tempAliasId] = tempAlias;
    
    generateContent(tempAliasId, model, prompt, apiKey, history, callback, errorCallback);
    
    // Clean up temporary alias
    delete providerAliases[tempAliasId];
}

// Initialize the system
logNormal("LLMApi", "LLM API system initialized with alias support");
