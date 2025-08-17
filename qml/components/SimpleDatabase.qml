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
                
                // Initialize schema immediately
                DebugLogger.logInfo("SimpleDatabase", "Starting schema initialization transaction...");
                database.transaction(function(tx) {
                    DebugLogger.logVerbose("SimpleDatabase", "Inside transaction - creating conversations table");
                    tx.executeSql('CREATE TABLE IF NOT EXISTS conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
                    DebugLogger.logVerbose("SimpleDatabase", "Inside transaction - creating messages table");
                    tx.executeSql('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER, role TEXT, message TEXT, timestamp INTEGER)');
                    DebugLogger.logVerbose("SimpleDatabase", "Transaction operations completed");
                });
                DebugLogger.logInfo("SimpleDatabase", "Schema initialization transaction completed");
                
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
                var rs = tx.executeSql('SELECT * FROM conversations ORDER BY id DESC');
                for (var i = 0; i < rs.rows.length; i++) {
                    conversations.push(rs.rows.item(i));
                }
            });
            
            DebugLogger.logInfo("SimpleDatabase", "Loaded " + conversations.length + " conversations");
            return conversations;
        } catch (e) {
            DebugLogger.logError("SimpleDatabase", "Failed to load conversations: " + e.toString());
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
    
    function saveMessage(conversationId, role, message) {
        try {
            var db = getDatabase();
            var timestamp = Date.now();
            
            db.transaction(function(tx) {
                tx.executeSql('INSERT INTO messages (conversation_id, role, message, timestamp) VALUES (?, ?, ?, ?)', 
                            [conversationId, role, message, timestamp]);
            });
            
            DebugLogger.logVerbose("SimpleDatabase", "Saved message for conversation " + conversationId + ": " + role);
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