/*
 * JavaScript/QML Tests for API Abstraction Layer
 * Claude Generated - Sailfish OS compatible test suite
 *
 * This test suite is designed to run both in QML environments
 * and standalone JavaScript for Cross-Platform compatibility.
 */

.import QtQuick.LocalStorage 2.0 as LS
.import "config/test_providers.js" as TestConfig

// Test framework for JavaScript/QML
var TestRunner = {
    tests: [],
    results: {
        passed: 0,
        failed: 0,
        skipped: 0,
        total: 0
    },
    log: [],

    // Add test case
    addTest: function(name, testFunction, timeout) {
        this.tests.push({
            name: name,
            test: testFunction,
            timeout: timeout || 5000
        });
    },

    // Run all tests
    runAllTests: function() {
        this.logResults("Starting JavaScript/QML API Tests");
        this.logResults("================================");

        // Load configuration
        var config = TestConfig.load();
        if (!config) {
            this.logResults("ERROR: Failed to load test configuration");
            return false;
        }

        // Run each test
        for (var i = 0; i < this.tests.length; i++) {
            var test = this.tests[i];
            this.runSingleTest(test, config);
        }

        // Print summary
        this.printSummary();
        return this.results.failed === 0;
    },

    // Run single test
    runSingleTest: function(test, config) {
        this.results.total++;
        var result = { passed: false, message: "" };

        try {
            print("Running test: " + test.name);

            // Run with timeout
            var timeoutId;
            var completed = false;

            if (typeof Qt !== 'undefined') {
                // QML environment - use timer
                timeoutId = Qt.callLater(function() {
                    if (!completed) {
                        result.message = "Test timed out after " + test.timeout + "ms";
                        TestRunner.logResults(test.name + " - TIMEOUT");
                        TestRunner.results.failed++;
                        completed = true;
                    }
                }, test.timeout);
            }

            // Execute test
            var returnValue = test.test(config, function(asyncResult) {
                completed = true;
                if (typeof Qt !== 'undefined') {
                    clearTimeout(timeoutId);
                }

                if (asyncResult.passed) {
                    TestRunner.results.passed++;
                    TestRunner.logResults(test.name + " - PASS");
                } else {
                    TestRunner.results.failed++;
                    TestRunner.logResults(test.name + " - FAIL: " + asyncResult.message);
                }
            });

            // Synchronous test
            if (returnValue !== undefined) {
                completed = true;
                if (typeof Qt !== 'undefined') {
                    clearTimeout(timeoutId);
                }

                if (returnValue === true) {
                    this.results.passed++;
                    this.logResults(test.name + " - PASS");
                } else {
                    this.results.failed++;
                    this.logResults(test.name + " - FAIL: " + returnValue);
                }
            }

        } catch (error) {
            completed = true;
            if (typeof Qt !== 'undefined') {
                clearTimeout(timeoutId);
            }

            this.results.failed++;
            this.logResults(test.name + " - ERROR: " + error.message);
        }
    },

    // Log results
    logResults: function(message) {
        this.log.push(message);
        console.log(message);
    },

    // Print summary
    printSummary: function() {
        this.logResults("================================");
        this.logResults("Test Summary:");
        this.logResults("Total: " + this.results.total);
        this.logResults("Passed: " + this.results.passed);
        this.logResults("Failed: " + this.results.failed);
        this.logResults("Skipped: " + this.results.skipped);

        var success = this.results.failed === 0;
        this.logResults("Result: " + (success ? "PASS" : "FAIL"));
        this.logResults("================================");

        return success;
    },

    // Assert functions
    assert: function(condition, message) {
        if (!condition) {
            throw new Error(message || "Assertion failed");
        }
        return true;
    },

    assertEqual: function(actual, expected, message) {
        if (actual !== expected) {
            throw new Error(message || "Expected " + expected + ", got " + actual);
        }
        return true;
    },

    assertTrue: function(value, message) {
        return this.assert(value === true, message);
    },

    assertFalse: function(value, message) {
        return this.assert(value === false, message);
    }
};

// HTTP Request helper for JavaScript/QML
var HttpRequest = {
    // Make HTTP request (cross-platform)
    request: function(options, callback) {
        var self = this;

        if (typeof XMLHttpRequest !== 'undefined') {
            // Browser/Qt environment
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === 4) {
                    var response = {
                        status: xhr.status,
                        statusText: xhr.statusText,
                        responseText: xhr.responseText,
                        response: xhr.response
                    };
                    callback(response);
                }
            };

            xhr.open(options.method || 'GET', options.url, true);

            // Set headers
            if (options.headers) {
                for (var header in options.headers) {
                    xhr.setRequestHeader(header, options.headers[header]);
                }
            }

            if (options.data) {
                xhr.send(JSON.stringify(options.data));
            } else {
                xhr.send();
            }

        } else if (typeof require !== 'undefined') {
            // Node.js environment
            var http = require('http') || require('https');
            var url = require('url');

            var parsedUrl = url.parse(options.url);
            var requestOptions = {
                hostname: parsedUrl.hostname,
                port: parsedUrl.port,
                path: parsedUrl.path,
                method: options.method || 'GET',
                headers: options.headers || {}
            };

            if (options.data) {
                var postData = JSON.stringify(options.data);
                requestOptions.headers['Content-Length'] = Buffer.byteLength(postData);
            }

            var req = http.request(requestOptions, function(res) {
                var responseText = '';
                res.setEncoding('utf8');
                res.on('data', function(chunk) {
                    responseText += chunk;
                });
                res.on('end', function() {
                    var response = {
                        status: res.statusCode,
                        statusText: res.statusMessage,
                        responseText: responseText
                    };
                    callback(response);
                });
            });

            req.on('error', function(err) {
                var response = {
                    status: -1,
                    statusText: err.message,
                    responseText: ''
                };
                callback(response);
            });

            if (options.data) {
                req.write(postData);
            }
            req.end();

        } else {
            // Fallback - simulate error
            setTimeout(function() {
                callback({
                    status: -1,
                    statusText: "HTTP not available",
                    responseText: ''
                });
            }, 100);
        }
    },

    // Make GET request
    get: function(url, headers, callback) {
        return this.request({
            method: 'GET',
            url: url,
            headers: headers
        }, callback);
    },

    // Make POST request
    post: function(url, headers, data, callback) {
        return this.request({
            method: 'POST',
            url: url,
            headers: headers,
            data: data
        }, callback);
    }
};

// Configuration loader for test setup
var ConfigLoader = {
    load: function() {
        try {
            // Try to load from different possible sources
            if (typeof TestConfig !== 'undefined') {
                return TestConfig.load();
            }

            // Fallback configuration
            return {
                api_endpoints: {
                    gemini: {
                        name: "Google Gemini",
                        base_url: "https://generativelanguage.googleapis.com/v1beta/models",
                        endpoints: {
                            chat: "/{model}:generateContent",
                            models: "",
                            streaming: "/{model}:streamGenerateContent"
                        },
                        authentication: {
                            header: "x-goog-api-key",
                            prefix: ""
                        },
                        features: {
                            supportsStreaming: true,
                            supportsImages: true,
                            supportsThinking: false
                        }
                    }
                },
                test_providers: {
                    gemini: {
                        api_key: "AIzaSyDfYDTVvpJveVYj7UWoleU1iZJVwJyFxB0",
                        test_models: ["gemini-2.0-flash"],
                        enabled: true
                    }
                }
            };
        } catch (error) {
            console.error("Failed to load configuration:", error);
            return null;
        }
    }
};

// Test functions
var Tests = {
    // Test configuration loading
    testConfigurationLoading: function(config, asyncCallback) {
        TestRunner.assert(config !== null, "Configuration should load");
        TestRunner.assert(config.api_endpoints !== undefined, "API endpoints should exist");
        TestRunner.assert(config.test_providers !== undefined, "Test providers should exist");

        // Check specific provider
        var gemini = config.api_endpoints.gemini;
        TestRunner.assert(gemini !== undefined, "Gemini provider should exist");
        TestRunner.assertEqual(gemini.name, "Google Gemini", "Gemini name should match");

        return true;
    },

    // Test Gemini connectivity
    testGeminiConnectivity: function(config, asyncCallback) {
        var provider = config.test_providers.gemini;
        var endpoint = config.api_endpoints.gemini;

        if (!provider || !provider.enabled) {
            TestRunner.logResults("Gemini provider not enabled, skipping");
            TestRunner.results.skipped++;
            return true; // Skip test
        }

        var url = endpoint.base_url + "/gemini-2.0-flash:generateContent";
        var headers = {
            'Content-Type': 'application/json',
            'x-goog-api-key': provider.api_key
        };

        var data = {
            'contents': [{
                'parts': [{
                    'text': 'Hello! Please respond with a simple greeting.'
                }]
            }],
            'generationConfig': {
                'maxOutputTokens': 50,
                'temperature': 0.7
            }
        };

        HttpRequest.post(url, headers, data, function(response) {
            var success = response.status === 200;
            var message = success ? "Gemini API responded" : "Status: " + response.status + " - " + response.statusText;

            if (asyncCallback) {
                asyncCallback({
                    passed: success,
                    message: message
                });
            }
        });

        // Return undefined for async
        return undefined;
    },

    // Test URL building
    testUrlBuilding: function(config, asyncCallback) {
        var gemini = config.api_endpoints.gemini;

        // Test basic URL building
        var baseUrl = gemini.base_url;
        TestRunner.assert(baseUrl.indexOf("https") === 0, "Base URL should use HTTPS");

        // Test endpoint templates
        var chatTemplate = gemini.endpoints.chat;
        TestRunner.assert(chatTemplate.indexOf("{model}") >= 0, "Chat endpoint should have model placeholder");

        // Test substitution
        var model = "gemini-pro";
        var chatEndpoint = chatTemplate.replace("{model}", model);
        var fullUrl = baseUrl + "/" + chatEndpoint;
        var expectedUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

        TestRunner.assertEqual(fullUrl, expectedUrl, "URL building should work correctly");

        return true;
    },

    // Test authentication
    testAuthentication: function(config, asyncCallback) {
        var gemini = config.api_endpoints.gemini;
        var provider = config.test_providers.gemini;

        // Test header construction
        var auth = gemini.authentication;
        var headers = {};

        if (auth.header && provider.api_key) {
            headers[auth.header] = auth.prefix + provider.api_key;
        }

        TestRunner.assert(headers['x-goog-api-key'] !== undefined, "Auth header should be set");
        TestRunner.assertTrue(headers['x-goog-api-key'].indexOf(provider.api_key) >= 0, "API key should be in header");

        return true;
    },

    // Test feature detection
    testFeatureDetection: function(config, asyncCallback) {
        var gemini = config.api_endpoints.gemini;

        TestRunner.assertTrue(typeof gemini.features.supportsStreaming === 'boolean', "Streaming flag should be boolean");
        TestRunner.assertTrue(typeof gemini.features.supportsImages === 'boolean', "Images flag should be boolean");
        TestRunner.assertTrue(typeof gemini.features.supportsThinking === 'boolean', "Thinking flag should be boolean");

        TestRunner.assertTrue(gemini.features.supportsStreaming, "Gemini should support streaming");
        TestRunner.assertTrue(gemini.features.supportsImages, "Gemini should support images");

        return true;
    },

    // Test error handling
    testErrorHandling: function(config, asyncCallback) {
        var provider = config.test_providers.gemini;
        var endpoint = config.api_endpoints.gemini;

        if (!provider || !provider.enabled) {
            TestRunner.logResults("Gemini provider not enabled, skipping error test");
            TestRunner.results.skipped++;
            return true;
        }

        // Test invalid model
        var url = endpoint.base_url + "/invalid-model:generateContent";
        var headers = {
            'Content-Type': 'application/json',
            'x-goog-api-key': provider.api_key
        };

        var data = {
            'contents': [{
                'parts': [{
                    'text': 'Hello'
                }]
            }]
        };

        HttpRequest.post(url, headers, data, function(response) {
            // Should get an error (4xx status)
            var success = response.status >= 400 && response.status < 500;
            var message = success ? "Error handling working correctly" : "Expected error but got status: " + response.status;

            if (asyncCallback) {
                asyncCallback({
                    passed: success,
                    message: message
                });
            }
        });

        return undefined;
    },

    // Test configuration validation
    testConfigValidation: function(config, asyncCallback) {
        var validationErrors = [];

        // Check required fields for each provider
        for (var providerId in config.api_endpoints) {
            var provider = config.api_endpoints[providerId];

            var requiredFields = ['name', 'base_url', 'endpoints', 'authentication', 'features', 'defaultModels', 'headers'];
            for (var i = 0; i < requiredFields.length; i++) {
                var field = requiredFields[i];
                if (!provider[field]) {
                    validationErrors.push('Provider ' + providerId + ' missing field: ' + field);
                }
            }
        }

        TestRunner.assertEqual(validationErrors.length, 0, "No validation errors: " + validationErrors.join(', '));

        return true;
    }
};

// Add all tests to the runner
function setupTests() {
    TestRunner.addTest("Configuration Loading", Tests.testConfigurationLoading);
    TestRunner.addTest("URL Building", Tests.testUrlBuilding);
    TestRunner.addTest("Authentication", Tests.testAuthentication);
    TestRunner.addTest("Feature Detection", Tests.testFeatureDetection);
    TestRunner.addTest("Configuration Validation", Tests.testConfigValidation);
    TestRunner.addTest("Gemini Connectivity", Tests.testGeminiConnectivity, 15000);
    TestRunner.addTest("Error Handling", Tests.testErrorHandling, 10000);
}

// Main execution
function runTests() {
    setupTests();
    return TestRunner.runAllTests();
}

// For QML environment
if (typeof Qt !== 'undefined') {
    // Export for QML usage
    TestRunner.runTests = runTests;
}

// For Node.js or standalone JavaScript
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        TestRunner: TestRunner,
        HttpRequest: HttpRequest,
        Tests: Tests,
        runTests: runTests
    };
}

// Auto-run if this is the main script
if (typeof window === 'undefined' && typeof global !== 'undefined') {
    // Node.js environment - check if this is being run directly
    if (require.main === module) {
        runTests();
        process.exit(TestRunner.results.failed === 0 ? 0 : 1);
    }
}
