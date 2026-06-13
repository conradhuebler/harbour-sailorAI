// Alias Manager - Runtime provider alias system
// Claude Generated - Bridges user-created aliases with config templates

.pragma library

Qt.include("DebugLogger.js")

// Alias storage - keyed by aliasId
var providerAliases = {};

// Availability status per alias
var aliasAvailability = {};

// Cached models per alias
var aliasModels = {};

// Cached per-model vision capability for Ollama aliases (aliasId -> { modelName: bool })
var aliasModelVision = {};

/**
 * Add a provider alias
 * @param {string} aliasId - Unique alias identifier
 * @param {string} name - Human-readable name
 * @param {string} type - Provider type (must exist in config)
 * @param {string} url - Base URL override
 * @param {string} apiKey - API key
 * @param {string} port - Port (optional)
 * @param {string} description - Description
 * @param {number} timeout - Request timeout in ms
 * @param {string} favoriteModel - Primary favorite model
 * @param {boolean} enableThinking - Enable thinking mode
 * @param {boolean} [enableWebSearch] - Enable web_search tool (default: true for ollama)
 * @param {boolean} [enableWebFetch] - Enable web_fetch tool (default: true for ollama)
 * @param {string} [webSearchApiKey] - Optional override API key for Ollama web tools
 * @returns {boolean} True if added successfully
 */
function addAlias(aliasId, name, type, url, apiKey, port, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    if (!aliasId || !type) {
        logError("AliasManager", "aliasId and type are required");
        return false;
    }

    var isOllama = (type === "ollama");
    var alias = {
        name: name || aliasId,
        type: type,
        url: url || "",
        api_key: apiKey || "",
        port: port || "",
        description: description || "",
        timeout: timeout || 10000,
        favoriteModel: favoriteModel || "",
        favoriteModels: favoriteModel ? [favoriteModel] : [],
        visionModels: [],
        enableThinking: enableThinking || false,
        enableWebSearch: (typeof enableWebSearch === 'undefined') ? isOllama : !!enableWebSearch,
        enableWebFetch: (typeof enableWebFetch === 'undefined') ? isOllama : !!enableWebFetch,
        webSearchApiKey: webSearchApiKey || "",
        isDefault: false
    };

    providerAliases[aliasId] = alias;
    aliasAvailability[aliasId] = "unchecked";
    aliasModels[aliasId] = [];

    logInfo("AliasManager", "Added alias: " + aliasId + " (" + name + ") type=" + type);
    return true;
}

/**
 * Initialize default aliases from provider config
 * Creates one alias per provider type with sensible defaults
 * @param {object} config - Loaded API configuration
 */
function initDefaultAliases(config) {
    if (!config || !config.api_endpoints) return;

    var defaults = {
        "openai": {
            aliasId: "openai",
            name: "ChatGPT"
        },
        "anthropic": {
            aliasId: "anthropic",
            name: "Claude"
        },
        "gemini": {
            aliasId: "gemini",
            name: "Gemini"
        },
        "ollama": {
            aliasId: "ollama",
            name: "Ollama"
        }
    };

    for (var type in defaults) {
        if (!defaults.hasOwnProperty(type)) continue;
        if (!config.api_endpoints[type]) continue;

        var def = defaults[type];
        var template = config.api_endpoints[type];

        // Skip if alias already exists
        if (providerAliases[def.aliasId]) continue;

        var alias = {
            name: def.name,
            type: type,
            url: template.base_url,
            api_key: "",
            port: "",
            description: template.description || "",
            timeout: 30000,
            favoriteModel: "",
            favoriteModels: [],
            visionModels: [],
            enableThinking: false,
            enableWebSearch: (type === "ollama"),
            enableWebFetch: (type === "ollama"),
            webSearchApiKey: "",
            isDefault: true
        };

        providerAliases[def.aliasId] = alias;
        aliasAvailability[def.aliasId] = "unchecked";
        aliasModels[def.aliasId] = [];
    }

    logInfo("AliasManager", "Initialized default aliases: " + Object.keys(providerAliases).join(", "));
}

/**
 * Remove a provider alias (cannot remove defaults)
 * @param {string} aliasId - Alias identifier
 * @returns {boolean} True if removed
 */
function removeAlias(aliasId) {
    if (!providerAliases[aliasId]) {
        logError("AliasManager", "Alias not found: " + aliasId);
        return false;
    }

    if (providerAliases[aliasId].isDefault) {
        logError("AliasManager", "Cannot remove default alias: " + aliasId);
        return false;
    }

    delete providerAliases[aliasId];
    delete aliasAvailability[aliasId];
    delete aliasModels[aliasId];

    logInfo("AliasManager", "Removed alias: " + aliasId);
    return true;
}

/**
 * Get all alias IDs
 * @returns {array} Array of alias ID strings
 */
function getAliasIds() {
    return Object.keys(providerAliases);
}

/**
 * Get alias object by ID
 * @param {string} aliasId - Alias identifier
 * @returns {object|null} Alias object or null
 */
function getAlias(aliasId) {
    return providerAliases[aliasId] || null;
}

/**
 * Update alias properties
 * @param {string} aliasId - Alias identifier
 * @param {string} name - New name (optional)
 * @param {string} url - New URL (optional)
 * @param {string} apiKey - New API key (optional)
 * @param {string} description - New description (optional)
 * @param {number} timeout - New timeout (optional)
 * @param {string} favoriteModel - New favorite model (optional)
 * @param {boolean} enableThinking - New thinking mode (optional)
 * @param {boolean} [enableWebSearch] - Web search tool enabled (optional)
 * @param {boolean} [enableWebFetch] - Web fetch tool enabled (optional)
 * @param {string} [webSearchApiKey] - Web search API key override (optional)
 * @returns {boolean} True if updated
 */
function updateAlias(aliasId, name, url, apiKey, description, timeout, favoriteModel, enableThinking, enableWebSearch, enableWebFetch, webSearchApiKey) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("AliasManager", "Alias not found for update: " + aliasId);
        return false;
    }

    if (!alias.isDefault) {
        if (name) alias.name = name;
        if (url) alias.url = url;
        if (description) alias.description = description;
        if (timeout) alias.timeout = timeout;
    }

    // API key and favorites can always be updated
    if (apiKey !== undefined && apiKey !== null) alias.api_key = apiKey;
    if (favoriteModel) {
        alias.favoriteModel = favoriteModel;
        if (!alias.favoriteModels) alias.favoriteModels = [];
        if (alias.favoriteModels.indexOf(favoriteModel) === -1) {
            alias.favoriteModels.unshift(favoriteModel);
        }
    }
    if (typeof enableThinking !== 'undefined') {
        alias.enableThinking = enableThinking;
    }
    if (typeof enableWebSearch !== 'undefined') {
        alias.enableWebSearch = !!enableWebSearch;
    }
    if (typeof enableWebFetch !== 'undefined') {
        alias.enableWebFetch = !!enableWebFetch;
    }
    if (typeof webSearchApiKey !== 'undefined' && webSearchApiKey !== null) {
        alias.webSearchApiKey = webSearchApiKey;
    }

    logInfo("AliasManager", "Updated alias: " + aliasId);
    return true;
}

/**
 * Resolve an alias to a merged provider configuration
 * Takes the config template for the alias's type and overlays alias-specific values
 * @param {string} aliasId - Alias identifier
 * @param {object} config - Loaded API configuration
 * @returns {object|null} Resolved provider object or null on error
 */
function resolveAlias(aliasId, config) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("AliasManager", "Alias not found: " + aliasId);
        return null;
    }

    if (!config || !config.api_endpoints) {
        logError("AliasManager", "Invalid configuration provided");
        return null;
    }

    var template = config.api_endpoints[alias.type];
    if (!template) {
        logError("AliasManager", "Provider type '" + alias.type + "' not found in config");
        return null;
    }

    // Deep-copy the template
    var resolved = JSON.parse(JSON.stringify(template));

    // Override with alias-specific values
    if (alias.url) resolved.base_url = alias.url;

    // Store alias metadata for use by request building and response parsing
    resolved._aliasId = aliasId;
    resolved._aliasName = alias.name;
    resolved._type = alias.type;
    resolved._apiKey = alias.api_key;
    resolved._timeout = alias.timeout || 10000;
    resolved._favoriteModel = alias.favoriteModel;
    resolved._enableThinking = alias.enableThinking;
    resolved._enableWebSearch = alias.enableWebSearch;
    resolved._enableWebFetch = alias.enableWebFetch;
    resolved._webSearchApiKey = alias.webSearchApiKey || "";

    // If template doesn't have a type field, set it from the alias
    if (!resolved.type) resolved.type = alias.type;

    return resolved;
}

/**
 * Get availability status for an alias
 * @param {string} aliasId - Alias identifier
 * @returns {string} Status string
 */
function getAvailability(aliasId) {
    return aliasAvailability[aliasId] || "unchecked";
}

/**
 * Check alias availability by pinging the provider
 * @param {string} aliasId - Alias identifier
 * @param {object} config - Loaded API configuration
 * @param {function} callback - Callback with (available: bool, status: string)
 */
function checkAvailability(aliasId, config, callback) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        callback && callback(false, "Alias not found");
        return;
    }

    // No API key needed for Ollama
    if (!alias.api_key && alias.type !== "ollama") {
        aliasAvailability[aliasId] = "no_key";
        callback && callback(false, "No API key configured");
        return;
    }

    aliasAvailability[aliasId] = "checking";

    var xhr = new XMLHttpRequest();
    xhr.timeout = alias.timeout || 10000;

    xhr.ontimeout = function() {
        aliasAvailability[aliasId] = "timeout";
        callback && callback(false, "Timeout");
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 401 || xhr.status === 403) {
                // Server reachable (401/403 = auth issue but server is there)
                aliasAvailability[aliasId] = "available";
                callback && callback(true, "Available");
            } else if (xhr.status === 0) {
                aliasAvailability[aliasId] = "timeout";
                callback && callback(false, "Network error");
            } else {
                aliasAvailability[aliasId] = "error";
                callback && callback(false, "HTTP " + xhr.status);
            }
        }
    };

    try {
        // Build ping URL based on provider type
        var pingUrl = alias.url;
        if (alias.type === "ollama") {
            pingUrl += "/api/tags";
        } else if (alias.type === "openai") {
            pingUrl += "/models";
        } else if (alias.type === "gemini") {
            pingUrl = alias.url; // Already includes models base
        } else if (alias.type === "anthropic") {
            // Anthropic has no models endpoint - just ping the base
            pingUrl += "/messages";
        }

        xhr.open("GET", pingUrl, true);

        // Set auth headers for ping
        if (alias.type === "gemini" && alias.api_key) {
            xhr.setRequestHeader("x-goog-api-key", alias.api_key);
        } else if (alias.api_key) {
            xhr.setRequestHeader("Authorization", "Bearer " + alias.api_key);
        }

        xhr.send();
    } catch (e) {
        aliasAvailability[aliasId] = "error";
        callback && callback(false, "Error: " + e.toString());
    }
}

/**
 * Get cached models for an alias
 * @param {string} aliasId - Alias identifier
 * @returns {array} Array of model name strings
 */
function getModels(aliasId) {
    return aliasModels[aliasId] || [];
}

/**
 * Set cached models for an alias
 * @param {string} aliasId - Alias identifier
 * @param {array} models - Array of model name strings
 */
function setModels(aliasId, models) {
    aliasModels[aliasId] = models || [];
}

/**
 * Fetch models from the provider API and cache them
 * @param {string} aliasId - Alias identifier
 * @param {object} config - Loaded API configuration
 * @param {function} callback - Callback with models array
 * @param {function} errorCallback - Error callback
 */
function fetchModels(aliasId, config, callback, errorCallback) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        errorCallback && errorCallback("Alias not found");
        return;
    }

    var resolved = resolveAlias(aliasId, config);
    if (!resolved) {
        errorCallback && errorCallback("Failed to resolve alias");
        return;
    }

    // Anthropic has no models endpoint
    if (alias.type === 'anthropic') {
        var defaults = resolved.defaultModels || [];
        aliasModels[aliasId] = defaults;
        callback && callback(defaults);
        return;
    }

    // Build models URL
    var modelsUrl = buildEndpointUrl(resolved, 'models', {}, {apiKey: alias.api_key});
    if (!modelsUrl) {
        // No models endpoint - use defaults
        var defaults = resolved.defaultModels || [];
        aliasModels[aliasId] = defaults;
        callback && callback(defaults);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.timeout = alias.timeout || 10000;

    xhr.ontimeout = function() {
        errorCallback && errorCallback("Models fetch timeout");
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var models = extractModels(response, resolved);
                    aliasModels[aliasId] = models;
                    callback && callback(models);
                } catch (e) {
                    errorCallback && errorCallback("Failed to parse models response");
                }
            } else {
                // Fall back to default models on error
                var defaults = resolved.defaultModels || [];
                aliasModels[aliasId] = defaults;
                callback && callback(defaults);
            }
        }
    };

    try {
        xhr.open('GET', modelsUrl, true);
        var headers = buildHeaders(resolved, alias.api_key);
        for (var headerName in headers) {
            if (headers.hasOwnProperty(headerName)) {
                xhr.setRequestHeader(headerName, headers[headerName]);
            }
        }
        xhr.send();
    } catch (e) {
        var defaults = resolved.defaultModels || [];
        aliasModels[aliasId] = defaults;
        callback && callback(defaults);
    }
}

// --- Favorite model management ---

function getFavoriteModel(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? alias.favoriteModel : "";
}

function setFavoriteModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (alias) {
        alias.favoriteModel = model;
        if (!alias.favoriteModels) alias.favoriteModels = [];
        if (alias.favoriteModels.indexOf(model) === -1) {
            alias.favoriteModels.unshift(model);
        }
        return true;
    }
    return false;
}

function getFavoriteModels(aliasId) {
    var alias = providerAliases[aliasId];
    if (alias) {
        if (!alias.favoriteModels && alias.favoriteModel) {
            alias.favoriteModels = [alias.favoriteModel];
        }
        return alias.favoriteModels || [];
    }
    return [];
}

function setFavoriteModels(aliasId, models) {
    var alias = providerAliases[aliasId];
    if (alias && Array.isArray(models)) {
        alias.favoriteModels = models.slice();
        alias.favoriteModel = models.length > 0 ? models[0] : "";
        return true;
    }
    return false;
}

function addFavoriteModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (alias && model) {
        if (!alias.favoriteModels) alias.favoriteModels = [];
        if (alias.favoriteModels.indexOf(model) === -1) {
            alias.favoriteModels.push(model);
            return true;
        }
    }
    return false;
}

function removeFavoriteModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (alias && model && alias.favoriteModels) {
        var index = alias.favoriteModels.indexOf(model);
        if (index !== -1) {
            alias.favoriteModels.splice(index, 1);
            if (alias.favoriteModel === model) {
                alias.favoriteModel = alias.favoriteModels.length > 0 ? alias.favoriteModels[0] : "";
            }
            return true;
        }
    }
    return false;
}

function isFavoriteModel(aliasId, model) {
    var favorites = getFavoriteModels(aliasId);
    return favorites.indexOf(model) !== -1;
}

// --- Vision capability detection (Ollama /api/show, with per-alias cache) ---

function isModelVisionKnown(aliasId, modelName) {
    var visionMap = aliasModelVision[aliasId];
    return !!(visionMap && (modelName in visionMap));
}

function isModelVisionCapable(aliasId, modelName) {
    var alias = providerAliases[aliasId];
    if (!alias) return false;
    // Manual user tag always wins
    if (alias.visionModels && alias.visionModels.indexOf(modelName) !== -1) return true;
    if (alias.type !== 'ollama') return true;
    var visionMap = aliasModelVision[aliasId];
    if (!visionMap || !(modelName in visionMap)) return false;
    return visionMap[modelName];
}

function checkOllamaModelVision(aliasId, modelName, callback) {
    var alias = providerAliases[aliasId];
    if (!alias || alias.type !== 'ollama') {
        callback && callback(true);
        return;
    }
    var visionMap = aliasModelVision[aliasId];
    if (visionMap && (modelName in visionMap)) {
        callback && callback(visionMap[modelName]);
        return;
    }
    var showUrl = alias.url + "/api/show";
    var xhr = new XMLHttpRequest();
    xhr.timeout = 10000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            var hasVision = false;
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    if (resp.capabilities) {
                        hasVision = resp.capabilities.indexOf("vision") !== -1;
                    } else if (resp.details && resp.details.families) {
                        hasVision = resp.details.families.indexOf("clip") !== -1;
                    }
                } catch (e) {
                    logError("AliasManager", "Failed to parse /api/show response: " + e);
                }
            }
            if (!aliasModelVision[aliasId]) aliasModelVision[aliasId] = {};
            aliasModelVision[aliasId][modelName] = hasVision;
            logInfo("AliasManager", "Vision check for " + modelName + ": " + hasVision);
            callback && callback(hasVision);
        }
    };
    try {
        xhr.open("POST", showUrl, true);
        if (alias.api_key) xhr.setRequestHeader("Authorization", "Bearer " + alias.api_key);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({model: modelName}));
    } catch (e) {
        logError("AliasManager", "checkOllamaModelVision failed: " + e);
        callback && callback(false);
    }
}

// --- Manual vision tags (user-marked, persisted per alias) ---

function getVisionModels(aliasId) {
    var alias = providerAliases[aliasId];
    return (alias && alias.visionModels) ? alias.visionModels : [];
}

function isVisionModelTagged(aliasId, model) {
    var alias = providerAliases[aliasId];
    return !!(alias && alias.visionModels && alias.visionModels.indexOf(model) !== -1);
}

function addVisionModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (!alias || !model) return false;
    if (!alias.visionModels) alias.visionModels = [];
    if (alias.visionModels.indexOf(model) === -1) {
        alias.visionModels.push(model);
        return true;
    }
    return false;
}

function removeVisionModel(aliasId, model) {
    var alias = providerAliases[aliasId];
    if (!alias || !alias.visionModels) return false;
    var idx = alias.visionModels.indexOf(model);
    if (idx !== -1) { alias.visionModels.splice(idx, 1); return true; }
    return false;
}

function toggleVisionModel(aliasId, model) {
    if (isVisionModelTagged(aliasId, model)) {
        removeVisionModel(aliasId, model);
        return false;
    }
    addVisionModel(aliasId, model);
    return true;
}

// --- Thinking mode ---

function setThinkingMode(aliasId, enabled) {
    var alias = providerAliases[aliasId];
    if (alias) {
        alias.enableThinking = enabled || false;
        return true;
    }
    return false;
}

function getThinkingMode(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? alias.enableThinking || false : false;
}

// --- Web tools ---

function setAliasWebSearchMode(aliasId, enabled) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("AliasManager", "Alias not found: " + aliasId);
        return false;
    }
    alias.enableWebSearch = !!enabled;
    return true;
}

function getAliasWebSearchMode(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? (alias.enableWebSearch || false) : false;
}

function setAliasWebFetchMode(aliasId, enabled) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("AliasManager", "Alias not found: " + aliasId);
        return false;
    }
    alias.enableWebFetch = !!enabled;
    return true;
}

function getAliasWebFetchMode(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? (alias.enableWebFetch || false) : false;
}

function setAliasWebSearchApiKey(aliasId, key) {
    var alias = providerAliases[aliasId];
    if (!alias) {
        logError("AliasManager", "Alias not found: " + aliasId);
        return false;
    }
    alias.webSearchApiKey = (typeof key === 'string') ? key : "";
    return true;
}

function getAliasWebSearchApiKey(aliasId) {
    var alias = providerAliases[aliasId];
    return alias ? (alias.webSearchApiKey || "") : "";
}

// --- Persistence ---

/**
 * Load aliases from a JSON string
 * @param {string} jsonStr - JSON string of alias data
 * @param {object} config - Loaded API configuration for validation
 */
function loadAliases(jsonStr, config) {
    if (!jsonStr) {
        logInfo("AliasManager", "No alias data to load");
        return;
    }

    try {
        var data = JSON.parse(jsonStr);
        if (typeof data !== 'object') {
            logError("AliasManager", "Invalid alias data format");
            return;
        }

        for (var aliasId in data) {
            if (!data.hasOwnProperty(aliasId)) continue;

            var alias = data[aliasId];

            // Validate that alias type exists in config
            if (config && config.api_endpoints && alias.type) {
                if (!config.api_endpoints[alias.type]) {
                    logError("AliasManager", "Alias '" + aliasId + "' has unknown type: " + alias.type);
                    continue;
                }
            }

            // Ensure required fields
            if (!alias.favoriteModels) {
                alias.favoriteModels = alias.favoriteModel ? [alias.favoriteModel] : [];
            }
            if (!alias.visionModels) {
                alias.visionModels = [];
            }

            // Migration: defaults for fields added after the initial release
            var isOllamaAlias = (alias.type === "ollama");
            if (typeof alias.enableWebSearch === 'undefined') {
                alias.enableWebSearch = isOllamaAlias;
            }
            if (typeof alias.enableWebFetch === 'undefined') {
                alias.enableWebFetch = isOllamaAlias;
            }
            if (typeof alias.webSearchApiKey === 'undefined') {
                alias.webSearchApiKey = "";
            }

            providerAliases[aliasId] = alias;
            if (!aliasAvailability[aliasId]) aliasAvailability[aliasId] = "unchecked";
            if (!aliasModels[aliasId]) aliasModels[aliasId] = [];
        }

        logInfo("AliasManager", "Loaded " + Object.keys(providerAliases).length + " aliases");
    } catch (e) {
        logError("AliasManager", "Failed to parse alias data: " + e.toString());
    }
}

/**
 * Save aliases to a JSON string
 * @returns {string} JSON string of alias data
 */
function saveAliases() {
    return JSON.stringify(providerAliases);
}

/**
 * Clear all aliases (for testing)
 */
function clearAliases() {
    providerAliases = {};
    aliasAvailability = {};
    aliasModels = {};
}