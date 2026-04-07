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
            "base_url": "http://localhost:11434",
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
}

// --- Alias CRUD ---

function addProviderAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking) {
    var result = _api.addAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking);
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

function updateProviderAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking) {
    return _api.updateAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking);
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

function fetchModelsForAlias(aliasId) {
    _api.fetchModelsForAlias(aliasId, null, null);
}

/**
 * Fetch models for a provider type without creating an alias.
 * Creates a temporary alias, fetches models, then removes it.
 */
function fetchModelsForType(type, url, apiKey, callback, errorCallback) {
    var tempId = "__temp_fetch_" + Date.now();
    _api.addAlias(tempId, "Temp", type, url, apiKey, "", "", 10000, "", false);
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

// --- Thinking mode ---

function setAliasThinkingMode(aliasId, enabled) {
    return _api.setThinkingMode(aliasId, enabled);
}

function getAliasThinkingMode(aliasId) {
    return _api.getThinkingMode(aliasId);
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

function generateContent(aliasId, model, prompt, apiKey, history, callback, errorCallback, streamCallback) {
    // apiKey parameter is ignored - resolved from alias internally
    _api.generate(aliasId, model, prompt, history, callback, errorCallback, streamCallback);
}

function generateContentWithImages(aliasId, model, prompt, apiKey, history, images, callback, errorCallback, streamCallback) {
    // apiKey parameter is ignored - resolved from alias internally
    _api.generateWithImages(aliasId, model, prompt, history, images, callback, errorCallback, streamCallback);
}

// --- Image encoding (TODO: real implementation) ---

function encodeImageToBase64(imagePath) {
    // Placeholder - real implementation needed for Sailfish OS
    var testJpegBase64 = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0HycyPTA1Ni4wMjI1Mjf/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAyADIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAFBABAAAAAAAAAAAAAAAAAAAACf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AOIAA//Z";
    return { data: testJpegBase64, mimeType: "image/jpeg" };
}

logNormal("LLMApi", "Initialized with ApiAbstraction layer (" + _api.getProviderIds().length + " providers)");