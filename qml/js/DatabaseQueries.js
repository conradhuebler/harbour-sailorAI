// Database query constants and helper functions
.pragma library

// Table creation queries
var CREATE_CONVERSATIONS_TABLE = 'CREATE TABLE IF NOT EXISTS conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)';
var CREATE_MESSAGES_TABLE = 'CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER, role TEXT, message TEXT, timestamp INTEGER, provider_alias TEXT, model_name TEXT)';

// Schema migration queries for existing databases
var ADD_PROVIDER_ALIAS_COLUMN = 'ALTER TABLE messages ADD COLUMN provider_alias TEXT';
var ADD_MODEL_NAME_COLUMN = 'ALTER TABLE messages ADD COLUMN model_name TEXT';

// Conversation queries
var SELECT_ALL_CONVERSATIONS = 'SELECT * FROM conversations ORDER BY id DESC';
var INSERT_CONVERSATION = 'INSERT INTO conversations (name) VALUES (?)';
var UPDATE_CONVERSATION_NAME = 'UPDATE conversations SET name = ? WHERE id = ?';
var DELETE_CONVERSATION = 'DELETE FROM conversations WHERE id = ?';

// Message queries
var SELECT_MESSAGES_BY_CONVERSATION = 'SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp';
var INSERT_MESSAGE = 'INSERT INTO messages (conversation_id, role, message, timestamp, provider_alias, model_name) VALUES (?, ?, ?, ?, ?, ?)';
var DELETE_MESSAGES_BY_CONVERSATION = 'DELETE FROM messages WHERE conversation_id = ?';

// Helper functions for parameter validation
function validateConversationId(id) {
    return id && typeof id === 'number' && id > 0;
}

function validateMessageRole(role) {
    return role && (role === 'user' || role === 'bot' || role === 'error' || role === 'system');
}

function validateMessageText(text) {
    return text && typeof text === 'string' && text.trim().length > 0;
}

function validateConversationName(name) {
    return name && typeof name === 'string' && name.trim().length > 0;
}

// Helper function to create operation objects for transactions
function createOperation(sql, params) {
    return {
        sql: sql,
        params: params || []
    };
}

// Common operation factories
function createConversationOperation(name) {
    if (!validateConversationName(name)) {
        throw new Error("Invalid conversation name");
    }
    return createOperation(INSERT_CONVERSATION, [name.trim()]);
}

function createMessageOperation(conversationId, role, message, timestamp, providerAlias, modelName) {
    if (!validateConversationId(conversationId)) {
        throw new Error("Invalid conversation ID");
    }
    if (!validateMessageRole(role)) {
        throw new Error("Invalid message role");
    }
    if (!validateMessageText(message)) {
        throw new Error("Invalid message text");
    }
    
    var ts = timestamp || Date.now();
    var provider = providerAlias || null;
    var model = modelName || null;
    return createOperation(INSERT_MESSAGE, [conversationId, role, message.trim(), ts, provider, model]);
}

function createUpdateConversationNameOperation(conversationId, newName) {
    if (!validateConversationId(conversationId)) {
        throw new Error("Invalid conversation ID");
    }
    if (!validateConversationName(newName)) {
        throw new Error("Invalid conversation name");
    }
    return createOperation(UPDATE_CONVERSATION_NAME, [newName.trim(), conversationId]);
}

function createDeleteConversationOperations(conversationId) {
    if (!validateConversationId(conversationId)) {
        throw new Error("Invalid conversation ID");
    }
    return [
        createOperation(DELETE_MESSAGES_BY_CONVERSATION, [conversationId]),
        createOperation(DELETE_CONVERSATION, [conversationId])
    ];
}

// Query parameter builders
function buildConversationParams(name) {
    return [validateConversationName(name) ? name.trim() : null];
}

function buildMessageParams(conversationId, role, message, timestamp, providerAlias, modelName) {
    return [
        validateConversationId(conversationId) ? conversationId : null,
        validateMessageRole(role) ? role : null,
        validateMessageText(message) ? message.trim() : null,
        timestamp || Date.now(),
        providerAlias || null,
        modelName || null
    ];
}

function buildUpdateConversationParams(newName, conversationId) {
    return [
        validateConversationName(newName) ? newName.trim() : null,
        validateConversationId(conversationId) ? conversationId : null
    ];
}

// Error messages
var ERRORS = {
    INVALID_CONVERSATION_ID: "Invalid or missing conversation ID",
    INVALID_MESSAGE_ROLE: "Invalid message role (must be: user, bot, error, system)",
    INVALID_MESSAGE_TEXT: "Invalid or empty message text",
    INVALID_CONVERSATION_NAME: "Invalid or empty conversation name",
    DATABASE_NOT_INITIALIZED: "Database not initialized",
    TRANSACTION_FAILED: "Database transaction failed",
    QUERY_FAILED: "Database query failed"
};

// Export error constants
function getErrorMessage(errorType) {
    return ERRORS[errorType] || "Unknown database error";
}