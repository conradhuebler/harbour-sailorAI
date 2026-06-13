// LLM API Compatibility Shim
// Delegates to ApiAbstraction layer - provides backward-compatible function names
// Claude Generated - Copyright (C) 2024-2025 Conrad Hübler <Conrad.Huebler@gmx.net>

.pragma library

// Include dependencies (all in same directory)
Qt.include("DebugLogger.js")
Qt.include("ConfigLoader.js")
Qt.include("EndpointBuilder.js")
Qt.include("AliasManager.js")
Qt.include("ApiAbstraction.js")

// Embedded API configuration (avoids XHR on qrc://)
var _apiConfig = {
    "api_endpoints": {
        "openai": {
            "name": "OpenAI Compatible",
            "type": "openai",
            "description": "OpenAI API (GPT-4o, GPT-4o-mini, o3, …)",
            "signupUrl": "https://platform.openai.com/",
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
            "description": "Anthropic Claude API (Claude 3.5/4 Sonnet, Opus, Haiku, …)",
            "signupUrl": "https://platform.claude.com/",
            "base_url": "https://api.anthropic.com/v1",
            "endpoints": {
                "chat": "/messages",
                "models": "/models",
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
            "description": "Google Gemini API (Gemini 1.5/2.0 Pro/Flash, …)",
            "signupUrl": "https://aistudio.google.com/app/apikey",
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
            "description": "Ollama local server or ollama.com remote endpoint",
            "signupUrl": "https://ollama.com/signup",
            "base_url": "https://ollama.com",
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

// Singleton API instance
var _api = new ApiAbstraction(_apiConfig);

// --- Provider type info (backward compatibility) ---

function getProviderTypes() {
    var types = {};
    var ids = _api.getProviderIds();
    for (var i = 0; i < ids.length; i++) {
        var p = _api.getProvider(ids[i]);
        if (p) {
            types[ids[i]] = {
                name: p.name,
                description: p.description || "",
                signupUrl: p.signupUrl || "",
                defaultUrl: p.base_url,
                defaultModels: p.defaultModels || [],
                authHeader: p.authentication ? p.authentication.header : "",
                authPrefix: p.authentication ? p.authentication.prefix : "",
                supportsStreaming: p.features ? p.features.supportsStreaming : false
            };
        }
    }
    return types;
}

// --- Helper: enrich alias with backward-compat properties ---

function _enrichAlias(aliasId) {
    var alias = _api.getAlias(aliasId);
    if (!alias) return;
    var provider = _api.getProvider(alias.type);
    if (provider) {
        alias.supportsStreaming = provider.features.supportsStreaming;
        alias.defaultModels = provider.defaultModels || [];
        alias.authHeader = provider.authentication.header;
        alias.authPrefix = provider.authentication.prefix;
    }
    // Web tool flags - mirror AliasManager state onto the alias object so QML can bind to them
    alias.enableWebSearch = _api.getAliasWebSearchMode(aliasId);
    alias.enableWebFetch = _api.getAliasWebFetchMode(aliasId);
    alias.webSearchApiKey = _api.getAliasWebSearchApiKey(aliasId);
}

// --- Alias CRUD ---

function addProviderAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    var result = _api.addAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey);
    if (result) {
        _enrichAlias(aliasId);
    }
    return result;
}

function removeProviderAlias(aliasId) {
    return _api.removeAlias(aliasId);
}

function getProviderAliases() {
    return _api.getAliasIds();
}

function getProviderAlias(aliasId) {
    return _api.getAlias(aliasId);
}

function updateProviderAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    return _api.updateAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey);
}

// --- Availability ---

function getAliasAvailability(aliasId) {
    return _api.getAvailability(aliasId);
}

function checkAliasAvailability(aliasId, callback) {
    return _api.checkAvailability(aliasId, callback);
}

function checkAllAliasesAvailability(callback) {
    var aliases = getProviderAliases();
    var completed = 0;
    var results = {};

    if (aliases.length === 0) {
        callback(results);
        return;
    }

    for (var i = 0; i < aliases.length; i++) {
        (function(id) {
            checkAliasAvailability(id, function(available, status) {
                completed++;
                results[id] = {available: available, status: status};
                if (completed === aliases.length) {
                    callback(results);
                }
            });
        })(aliases[i]);
    }
}

// --- Models ---

function getAliasModels(aliasId) {
    return _api.getAliasModels(aliasId);
}

function getModelInfo(aliasId, modelName) {
    return "";
}

// Vision capability helpers (isModelVisionCapable, isModelVisionKnown,
// checkOllamaModelVision) come directly from AliasManager.js, which is loaded via
// Qt.include above. Qt.include merges those functions into this library's scope, so
// QML can call them as LLMApi.isModelVisionCapable(...) etc. without a wrapper here.
// NOTE: Do NOT redeclare them with the same name in this file - a same-name wrapper
// would shadow the AliasManager version and recurse into itself. - Claude Generated

function fetchModelsForAlias(aliasId, callback) {
    _api.fetchModelsForAlias(aliasId, callback || null, null);
}

/**
 * Fetch models for a provider type without creating an alias.
 * Creates a temporary alias, fetches models, then removes it.
 */
function fetchModelsForType(type, url, apiKey, callback, errorCallback) {
    var tempId = "__temp_fetch_" + Date.now();
    _api.addAlias(tempId, "Temp", type, url, apiKey, "", "", 10000, "", false, undefined, undefined, "");
    _api.fetchModelsForAlias(tempId, function(models) {
        _api.removeAlias(tempId);
        callback && callback(models);
    }, function(error) {
        _api.removeAlias(tempId);
        errorCallback && errorCallback(error);
    });
}

// --- Favorites ---

function getAliasFavoriteModel(aliasId) {
    return _api.getFavoriteModel(aliasId);
}

function setAliasFavoriteModel(aliasId, model) {
    return _api.setFavoriteModel(aliasId, model);
}

function getAliasFavoriteModels(aliasId) {
    return _api.getFavoriteModels(aliasId);
}

function setAliasFavoriteModels(aliasId, models) {
    return _api.setFavoriteModels(aliasId, models);
}

function addAliasFavoriteModel(aliasId, model) {
    return _api.addFavoriteModel(aliasId, model);
}

function removeAliasFavoriteModel(aliasId, model) {
    return _api.removeFavoriteModel(aliasId, model);
}

function isAliasFavoriteModel(aliasId, model) {
    return _api.isFavoriteModel(aliasId, model);
}

// --- Manual vision tags ---

function getAliasVisionModels(aliasId) {
    return getVisionModels(aliasId);
}

function isAliasVisionModelTagged(aliasId, model) {
    return isVisionModelTagged(aliasId, model);
}

function toggleAliasVisionModel(aliasId, model) {
    return toggleVisionModel(aliasId, model);
}

// --- Thinking mode ---

function setAliasThinkingMode(aliasId, enabled) {
    return _api.setThinkingMode(aliasId, enabled);
}

function getAliasThinkingMode(aliasId) {
    return _api.getThinkingMode(aliasId);
}

// --- Web tools ---

function getAliasWebSearchMode(aliasId) {
    return _api.getAliasWebSearchMode(aliasId);
}

function setAliasWebSearchMode(aliasId, enabled) {
    var result = _api.setAliasWebSearchMode(aliasId, enabled);
    if (result) _enrichAlias(aliasId);
    return result;
}

function getAliasWebFetchMode(aliasId) {
    return _api.getAliasWebFetchMode(aliasId);
}

function setAliasWebFetchMode(aliasId, enabled) {
    var result = _api.setAliasWebFetchMode(aliasId, enabled);
    if (result) _enrichAlias(aliasId);
    return result;
}

function getAliasWebSearchApiKey(aliasId) {
    return _api.getAliasWebSearchApiKey(aliasId);
}

function setAliasWebSearchApiKey(aliasId, key) {
    var result = _api.setAliasWebSearchApiKey(aliasId, key);
    if (result) _enrichAlias(aliasId);
    return result;
}

// --- Persistence ---

function loadProviderAliases(jsonStr) {
    _api.loadAliases(jsonStr);
    // Enrich loaded aliases with backward-compat properties
    var ids = _api.getAliasIds();
    for (var i = 0; i < ids.length; i++) {
        _enrichAlias(ids[i]);
    }
}

function saveProviderAliases() {
    return _api.saveAliases();
}

// --- Content generation ---

function generateContent(aliasId, model, prompt, apiKey, history, callback, errorCallback, streamCallback, options) {
    // apiKey parameter is ignored - resolved from alias internally
    // options (optional): { toolLabels, maxToolIterations } - only used by the Ollama tool loop. Claude Generated
    _api.generate(aliasId, model, prompt, history, callback, errorCallback, streamCallback, options);
}

function generateContentWithImages(aliasId, model, prompt, apiKey, history, images, callback, errorCallback, streamCallback, options) {
    // apiKey parameter is ignored - resolved from alias internally
    // options (optional): { systemPrompt, ... } - Claude Generated
    _api.generateWithImages(aliasId, model, prompt, history, images, callback, errorCallback, streamCallback, options);
}

// Claude Generated: temporarily set the alias web search / fetch flags for the next call.
// Restores the previous values after the call completes. Used by ChatPage so the per-session
// web search toggle does not have to be persisted in the alias config.
function withTemporaryWebToolOverride(aliasId, webSearchOverride, webFetchOverride, fn) {
    var alias = _api.getAlias(aliasId);
    if (!alias) {
        fn();
        return;
    }
    var prevSearch = alias.enableWebSearch;
    var prevFetch = alias.enableWebFetch;
    if (typeof webSearchOverride === 'boolean') alias.enableWebSearch = webSearchOverride;
    if (typeof webFetchOverride === 'boolean') alias.enableWebFetch = webFetchOverride;
    try {
        fn();
    } finally {
        alias.enableWebSearch = prevSearch;
        alias.enableWebFetch = prevFetch;
    }
}

// --- Image encoding ---
// Claude Generated - Copyright (C) 2024-2025 Conrad Hübler <Conrad.Huebler@gmx.net>

// Direct Uint8Array -> base64. Avoids Qt.btoa(), which in Qt5 QML UTF-8-encodes
// its input string before base64-encoding, doubling and corrupting binary data.
function _bytesToBase64(bytes) {
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var parts = [];
    var len = bytes.length;
    var chunk = "";
    var chunkCount = 0;
    var i, b1, b2, b3;
    for (i = 0; i + 3 <= len; i += 3) {
        b1 = bytes[i]; b2 = bytes[i + 1]; b3 = bytes[i + 2];
        chunk += chars.charAt(b1 >> 2)
              +  chars.charAt(((b1 & 0x03) << 4) | (b2 >> 4))
              +  chars.charAt(((b2 & 0x0F) << 2) | (b3 >> 6))
              +  chars.charAt(b3 & 0x3F);
        if (++chunkCount >= 256) {
            parts.push(chunk);
            chunk = "";
            chunkCount = 0;
        }
    }
    if (chunk.length > 0) parts.push(chunk);
    var rem = len - i;
    if (rem === 1) {
        b1 = bytes[i];
        parts.push(chars.charAt(b1 >> 2) + chars.charAt((b1 & 0x03) << 4) + "==");
    } else if (rem === 2) {
        b1 = bytes[i]; b2 = bytes[i + 1];
        parts.push(chars.charAt(b1 >> 2)
                 + chars.charAt(((b1 & 0x03) << 4) | (b2 >> 4))
                 + chars.charAt((b2 & 0x0F) << 2) + "=");
    }
    return parts.join("");
}

function encodeImageToBase64(imagePath, callback) {
    // Convert QML Url object to string if needed
    var cleanPath = imagePath.toString();
    if (cleanPath.indexOf("file://") === 0) {
        cleanPath = cleanPath.substring(7);
    }
    // Handle Sailfish content URLs that may have multiple slashes
    if (cleanPath.indexOf("///") === 0) {
        cleanPath = cleanPath.substring(2); // "///path" -> "/path"
    }

    var mimeType = "image/jpeg";
    var ext = cleanPath.split('.').pop().toLowerCase();
    if (ext === "png") mimeType = "image/png";
    else if (ext === "gif") mimeType = "image/gif";
    else if (ext === "webp") mimeType = "image/webp";
    else if (ext === "bmp") mimeType = "image/bmp";

    logVerbose("LLMApi", "Reading image: " + cleanPath + " (" + mimeType + ")");

    var xhr = new XMLHttpRequest();
    xhr.open("GET", "file://" + cleanPath, true);
    xhr.responseType = "arraybuffer";
    xhr.timeout = 30000;
    xhr.ontimeout = function() {
        logError("LLMApi", "Timeout reading image: " + cleanPath);
        callback(null);
    };
    xhr.onerror = function() {
        logError("LLMApi", "XHR error reading image: " + cleanPath);
        callback(null);
    };
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var arrayBuffer = xhr.response;
                    if (!arrayBuffer || !(arrayBuffer instanceof ArrayBuffer)) {
                        logError("LLMApi", "No arraybuffer response for " + cleanPath);
                        callback(null);
                        return;
                    }
                    var bytes = new Uint8Array(arrayBuffer);
                    // Qt.btoa() UTF-8-encodes its input before base64-encoding, which corrupts
                    // binary data (every byte >= 0x80 becomes 2 bytes). Encode bytes directly.
                    var base64 = _bytesToBase64(bytes);
                    logInfo("LLMApi", "Encoded image " + cleanPath + ": " + bytes.length + " bytes -> " + base64.length + " base64 chars");
                    callback({ data: base64, mimeType: mimeType, originalPath: cleanPath });
                } catch (e) {
                    logError("LLMApi", "Exception encoding " + cleanPath + ": " + e);
                    callback(null);
                }
            } else {
                logError("LLMApi", "HTTP status " + xhr.status + " reading " + cleanPath);
                callback(null);
            }
        }
    };
    xhr.send();
}

function encodeImages(imagePaths, callback) {
    if (!imagePaths || imagePaths.length === 0) {
        callback([]);
        return;
    }
    logVerbose("LLMApi", "Encoding " + imagePaths.length + " image(s)");
    var results = [];
    var completed = 0;
    var total = imagePaths.length;
    var failed = 0;
    for (var i = 0; i < total; i++) {
        encodeImageToBase64(imagePaths[i], function(result) {
            if (result) {
                results.push(result);
            } else {
                failed++;
            }
            completed++;
            if (completed === total) {
                logInfo("LLMApi", "Image encoding done: " + results.length + "/" + total + " succeeded" + (failed > 0 ? " (" + failed + " failed)" : ""));
                callback(results);
            }
        });
    }
}

logNormal("LLMApi", "Initialized with ApiAbstraction layer (" + _api.getProviderIds().length + " providers)");