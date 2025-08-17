import QtQuick 2.0
import QtQuick.LocalStorage 2.0
import "../js/DebugLogger.js" as DebugLogger

QtObject {
    id: simpleDb
    
    property var database: null
    property bool isInitialized: false
    
    function getDatabase() {
        DebugLogger.logVerbose("SimpleDatabase", "getDatabase() called");
        if (!database) {
            try {
                DebugLogger.logInfo("SimpleDatabase", "Opening database connection...");
                database = LocalStorage.openDatabaseSync("SailorAI", "1.0", "SailorAI Database", 1000000);
                DebugLogger.logInfo("SimpleDatabase", "Database connection opened successfully");
                
                // Initialize schema and migrate if needed
                DebugLogger.logInfo("SimpleDatabase", "Starting schema initialization transaction...");
                database.transaction(function(tx) {
                    DebugLogger.logVerbose("SimpleDatabase", "Inside transaction - creating conversations table");
                    tx.executeSql('CREATE TABLE IF NOT EXISTS conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
                    DebugLogger.logVerbose("SimpleDatabase", "Inside transaction - creating messages table");
                    tx.executeSql('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER, role TEXT, message TEXT, timestamp INTEGER, provider_alias TEXT, model_name TEXT)');
                    
                    // Migration for existing databases - add new columns if they don't exist
                    try {
                        DebugLogger.logVerbose("SimpleDatabase", "Checking for schema migration...");
                        tx.executeSql('ALTER TABLE messages ADD COLUMN provider_alias TEXT');
                        DebugLogger.logInfo("SimpleDatabase", "Added provider_alias column");
                    } catch (e) {
                        DebugLogger.logVerbose("SimpleDatabase", "provider_alias column already exists or error: " + e.toString());
                    }
                    
                    try {
                        tx.executeSql('ALTER TABLE messages ADD COLUMN model_name TEXT');
                        DebugLogger.logInfo("SimpleDatabase", "Added model_name column");
                    } catch (e) {
                        DebugLogger.logVerbose("SimpleDatabase", "model_name column already exists or error: " + e.toString());
                    }
                    
                    DebugLogger.logVerbose("SimpleDatabase", "Transaction operations completed");
                });
                DebugLogger.logInfo("SimpleDatabase", "Schema initialization and migration completed");
                
                isInitialized = true;
                DebugLogger.logNormal("SimpleDatabase", "Database initialized successfully");
            } catch (e) {
                DebugLogger.logError("SimpleDatabase", "Failed to initialize database: " + e.toString());
            }
        } else {
            DebugLogger.logVerbose("SimpleDatabase", "Database already initialized, returning existing connection");
        }
        return database;
    }
    
    // Synchronous operations - no callbacks
    function createConversation(name) {
        try {
            var db = getDatabase();
            var conversationId = 0;
            
            db.transaction(function(tx) {
                var rs = tx.executeSql('INSERT INTO conversations (name) VALUES (?)', [name]);
                conversationId = rs.insertId;
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Created conversation with ID: " + conversationId);
            return conversationId;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to create conversation: " + e.toString());
            return 0;
        }
    }
    
    function loadConversations() {
        try {
            var db = getDatabase();
            var conversations = [];
            
            db.readTransaction(function(tx) {
                // Enhanced query with message count, first/last activity, and last used provider/model
                var query = "SELECT c.*, " +
                    "COUNT(m.id) as message_count, " +
                    "MIN(m.timestamp) as first_activity, " +
                    "MAX(m.timestamp) as last_activity, " +
                    "(SELECT m2.provider_alias FROM messages m2 " +
                    "WHERE m2.conversation_id = c.id AND m2.role = 'bot' " +
                    "ORDER BY m2.timestamp DESC LIMIT 1) as last_provider, " +
                    "(SELECT m2.model_name FROM messages m2 " +
                    "WHERE m2.conversation_id = c.id AND m2.role = 'bot' " +
                    "ORDER BY m2.timestamp DESC LIMIT 1) as last_model " +
                    "FROM conversations c " +
                    "LEFT JOIN messages m ON c.id = m.conversation_id " +
                    "GROUP BY c.id " +
                    "ORDER BY COALESCE(last_activity, c.id) DESC";
                
                var rs = tx.executeSql(query);
                for (var i = 0; i < rs.rows.length; i++) {
                    var row = rs.rows.item(i);
                    // Ensure we have default values for missing data
                    row.message_count = row.message_count || 0;
                    row.first_activity = row.first_activity || Date.now();
                    row.last_activity = row.last_activity || Date.now();
                    row.last_provider = row.last_provider || null;
                    row.last_model = row.last_model || null;
                    conversations.push(row);
                }
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Loaded " + conversations.length + " conversations with metadata");
            return conversations;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to load conversations: " + e.toString());
            // Fallback to simple query if enhanced query fails
            return loadConversationsSimple();
        }
    }
    
    function loadConversationsSimple() {
        try {
            var db = getDatabase();
            var conversations = [];
            
            db.readTransaction(function(tx) {
                var rs = tx.executeSql('SELECT * FROM conversations ORDER BY id DESC');
                for (var i = 0; i < rs.rows.length; i++) {
                    var row = rs.rows.item(i);
                    // Add default metadata for compatibility
                    row.message_count = 0;
                    row.first_activity = Date.now();
                    row.last_activity = Date.now();
                    row.last_provider = null;
                    row.last_model = null;
                    conversations.push(row);
                }
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Loaded " + conversations.length + " conversations (simple mode)");
            return conversations;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to load conversations (simple): " + e.toString());
            return [];
        }
    }
    
    function deleteConversation(conversationId) {
        try {
            var db = getDatabase();
            
            db.transaction(function(tx) {
                tx.executeSql('DELETE FROM messages WHERE conversation_id = ?', [conversationId]);
                tx.executeSql('DELETE FROM conversations WHERE id = ?', [conversationId]);
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Deleted conversation: " + conversationId);
            return true;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to delete conversation: " + e.toString());
            return false;
        }
    }
    
    function updateConversationName(conversationId, newName) {
        try {
            var db = getDatabase();
            
            db.transaction(function(tx) {
                tx.executeSql('UPDATE conversations SET name = ? WHERE id = ?', [newName, conversationId]);
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Updated conversation " + conversationId + " name to: " + newName);
            return true;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to update conversation name: " + e.toString());
            return false;
        }
    }
    
    function loadMessages(conversationId) {
        try {
            var db = getDatabase();
            var messages = [];
            
            db.readTransaction(function(tx) {
                var rs = tx.executeSql('SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp', [conversationId]);
                for (var i = 0; i < rs.rows.length; i++) {
                    var item = rs.rows.item(i);
                    if (!item.timestamp) {
                        item.timestamp = Date.now();
                    }
                    messages.push(item);
                }
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Loaded " + messages.length + " messages for conversation " + conversationId);
            return messages;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to load messages: " + e.toString());
            return [];
        }
    }
    
    function saveMessage(conversationId, role, message, providerAlias, modelName) {
        try {
            var db = getDatabase();
            var timestamp = Date.now();
            var provider = providerAlias || null;
            var model = modelName || null;
            
            db.transaction(function(tx) {
                tx.executeSql('INSERT INTO messages (conversation_id, role, message, timestamp, provider_alias, model_name) VALUES (?, ?, ?, ?, ?, ?)', 
                            [conversationId, role, message, timestamp, provider, model]);
            });
            
            var logDetails = role;
            if (provider && model) {
                logDetails += " (" + provider + " / " + model + ")";
            }
            DebugLogger.logVerbose("SimpleDatabase", "Saved message for conversation " + conversationId + ": " + logDetails);
            return true;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to save message: " + e.toString());
            return false;
        }
    }
    
    Component.onCompleted: {
        DebugLogger.logNormal("SimpleDatabase", "Simple database manager created");
        getDatabase(); // Initialize immediately
    }
}