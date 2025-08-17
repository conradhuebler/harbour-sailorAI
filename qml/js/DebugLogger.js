// Debug logging system for SailorAI
.pragma library

// Debug levels:
// 0 = None (production)
// 1 = Normal (errors, important events)
// 2 = Informative (API calls, provider switches)
// 3 = Verbose (all operations, model fetching)

var currentDebugLevel = 1; // Default to normal logging

function setDebugLevel(level) {
    currentDebugLevel = Math.max(0, Math.min(3, level));
}

function getDebugLevel() {
    return currentDebugLevel;
}

function logError(component, message) {
    if (currentDebugLevel >= 1) {
        console.log("[ERROR] " + component + ": " + message);
    }
}

function logNormal(component, message) {
    if (currentDebugLevel >= 1) {
        console.log("[INFO] " + component + ": " + message);
    }
}

function logInfo(component, message) {
    if (currentDebugLevel >= 2) {
        console.log("[DEBUG] " + component + ": " + message);
    }
}

function logVerbose(component, message) {
    if (currentDebugLevel >= 3) {
        console.log("[VERBOSE] " + component + ": " + message);
    }
}

// Convenience functions for common components
function logApi(message) {
    logInfo("LLMApi", message);
}

function logChat(message) {
    logInfo("ChatPage", message);
}

function logSettings(message) {
    logInfo("Settings", message);
}

function logProvider(message) {
    logInfo("Provider", message);
}

function logConversation(message) {
    logInfo("Conversation", message);
}