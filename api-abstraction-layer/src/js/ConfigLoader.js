// Configuration Loader and Validator
// Claude Generated - Abstracts API endpoint configuration loading

.pragma library

Qt.include("DebugLogger.js")

// Global cache for loaded configurations
var configCache = {};

/**
 * Load API configuration from JSON file (synchronous)
 * @param {string} configPath - Path to configuration file
 * @returns {object|null} Parsed configuration or null on error
 */
function loadConfig(configPath) {
    // Check cache first
    if (configCache[configPath]) {
        logInfo("ConfigLoader", "Using cached configuration for " + configPath);
        return configCache[configPath];
    }

    try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", configPath, false); // Synchronous
        xhr.send();

        if (xhr.status === 200) {
            var config = JSON.parse(xhr.responseText);

            if (validateConfig(config)) {
                configCache[configPath] = config;
                logInfo("ConfigLoader", "Successfully loaded and cached configuration from " + configPath);
                return config;
            } else {
                logError("ConfigLoader", "Configuration validation failed for " + configPath);
                return null;
            }
        } else {
            logError("ConfigLoader", "Failed to load configuration from " + configPath + " (status: " + xhr.status + ")");
            return null;
        }
    } catch (e) {
        logError("ConfigLoader", "Error loading configuration from " + configPath + ": " + e.toString());
        return null;
    }
}

/**
 * Load API configuration from JSON file (asynchronous)
 * @param {string} configPath - Path to configuration file
 * @param {function} callback - Callback with config object or null on error
 */
function loadConfigAsync(configPath, callback) {
    // Check cache first
    if (configCache[configPath]) {
        logInfo("ConfigLoader", "Using cached configuration for " + configPath);
        callback(configCache[configPath]);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.open("GET", configPath, true); // Async

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var config = JSON.parse(xhr.responseText);
                    if (validateConfig(config)) {
                        configCache[configPath] = config;
                        logInfo("ConfigLoader", "Successfully loaded configuration async from " + configPath);
                        callback(config);
                    } else {
                        logError("ConfigLoader", "Configuration validation failed for " + configPath);
                        callback(null);
                    }
                } catch (e) {
                    logError("ConfigLoader", "Failed to parse configuration: " + e.toString());
                    callback(null);
                }
            } else {
                logError("ConfigLoader", "Failed to load configuration from " + configPath + " (status: " + xhr.status + ")");
                callback(null);
            }
        }
    };

    xhr.send();
}

/**
 * Validate configuration against schema requirements
 * @param {object} config - Configuration object to validate
 * @returns {boolean} True if valid, false otherwise
 */
function validateConfig(config) {
    if (!config || typeof config !== 'object') {
        logError("ConfigLoader", "Configuration must be an object");
        return false;
    }

    if (!config.api_endpoints) {
        logError("ConfigLoader", "Missing required 'api_endpoints' property");
        return false;
    }

    var endpoints = config.api_endpoints;

    for (var providerId in endpoints) {
        if (!endpoints.hasOwnProperty(providerId)) {
            continue;
        }

        var provider = endpoints[providerId];

        var requiredProps = ['name', 'base_url', 'endpoints', 'authentication', 'features', 'defaultModels', 'headers'];
        for (var i = 0; i < requiredProps.length; i++) {
            var prop = requiredProps[i];
            if (!provider[prop]) {
                logError("ConfigLoader", "Provider '" + providerId + "' missing required property: " + prop);
                return false;
            }
        }

        var endpointsObj = provider.endpoints;
        var requiredEndpoints = ['chat', 'models', 'streaming'];
        for (var j = 0; j < requiredEndpoints.length; j++) {
            var endpoint = requiredEndpoints[j];
            if (typeof endpointsObj[endpoint] !== 'string') {
                logError("ConfigLoader", "Provider '" + providerId + "' missing endpoint: " + endpoint);
                return false;
            }
        }

        var auth = provider.authentication;
        if (!auth.header || typeof auth.header !== 'string') {
            logError("ConfigLoader", "Provider '" + providerId + "' invalid authentication header");
            return false;
        }

        var features = provider.features;
        var requiredFeatures = ['supportsStreaming', 'supportsImages', 'supportsThinking'];
        for (var k = 0; k < requiredFeatures.length; k++) {
            var feature = requiredFeatures[k];
            if (typeof features[feature] !== 'boolean') {
                logError("ConfigLoader", "Provider '" + providerId + "' missing feature: " + feature);
                return false;
            }
        }

        var headers = provider.headers;
        if (!headers.required || !Array.isArray(headers.required)) {
            logError("ConfigLoader", "Provider '" + providerId + "' missing required headers array");
            return false;
        }
    }

    logInfo("ConfigLoader", "Configuration validation passed for " + Object.keys(endpoints).length + " providers");
    return true;
}

/**
 * Get provider configuration by ID
 * @param {object} config - Loaded configuration
 * @param {string} providerId - Provider identifier
 * @returns {object|null} Provider configuration or null if not found
 */
function getProvider(config, providerId) {
    if (!config || !config.api_endpoints) {
        logError("ConfigLoader", "Invalid configuration provided");
        return null;
    }

    var provider = config.api_endpoints[providerId];
    if (!provider) {
        logError("ConfigLoader", "Provider '" + providerId + "' not found in configuration");
        return null;
    }

    return provider;
}

/**
 * Get all available provider IDs
 * @param {object} config - Loaded configuration
 * @returns {array} Array of provider IDs
 */
function getProviderIds(config) {
    if (!config || !config.api_endpoints) {
        logError("ConfigLoader", "Invalid configuration provided");
        return [];
    }

    return Object.keys(config.api_endpoints);
}

/**
 * Check if provider supports specific feature
 * @param {object} config - Loaded configuration
 * @param {string} providerId - Provider identifier
 * @param {string} feature - Feature name
 * @returns {boolean} True if feature is supported
 */
function supportsFeature(config, providerId, feature) {
    var provider = getProvider(config, providerId);
    if (!provider || !provider.features) {
        logError("ConfigLoader", "Cannot check feature for provider '" + providerId + "'");
        return false;
    }

    return Boolean(provider.features[feature]);
}

/**
 * Get default models for a provider
 * @param {object} config - Loaded configuration
 * @param {string} providerId - Provider identifier
 * @returns {array} Array of default model names
 */
function getDefaultModels(config, providerId) {
    var provider = getProvider(config, providerId);
    if (!provider) {
        return [];
    }

    return provider.defaultModels || [];
}

/**
 * Clear configuration cache
 * @param {string} [configPath] - Optional specific config path to clear
 */
function clearCache(configPath) {
    if (configPath) {
        delete configCache[configPath];
        logInfo("ConfigLoader", "Cleared cache for " + configPath);
    } else {
        configCache = {};
        logInfo("ConfigLoader", "Cleared all configuration cache");
    }
}

/**
 * Reload configuration from file
 * @param {string} configPath - Path to configuration file
 * @returns {object|null} Reloaded configuration or null on error
 */
function reloadConfig(configPath) {
    clearCache(configPath);
    return loadConfig(configPath);
}