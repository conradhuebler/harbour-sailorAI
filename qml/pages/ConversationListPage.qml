import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger
import "../js/DatabaseQueries.js" as DatabaseQueries

Page {
    id: page

    ListModel {
        id: conversationList
    }

    // Configuration values for each provider
    ConfigurationValue {
        id: geminiConfig
        key: "/SailorAI/gemini_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: openaiConfig
        key: "/SailorAI/openai_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: anthropicConfig
        key: "/SailorAI/anthropic_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: ollamaConfig
        key: "/SailorAI/ollama_config"
        defaultValue: ""
    }

    // Debug level configuration
    ConfigurationValue {
        id: debugLevelConfig
        key: "/SailorAI/debug_level"
        defaultValue: "1"
        onValueChanged: {
            DebugLogger.setDebugLevel(parseInt(value) || 1);
        }
    }

    // Provider aliases configuration
    ConfigurationValue {
        id: providerAliasesConfig
        key: "/SailorAI/provider_aliases"
        defaultValue: ""
    }

    function loadAllConfigs() {
        // Initialize debug level first
        DebugLogger.setDebugLevel(parseInt(debugLevelConfig.value) || 1);
        DebugLogger.logNormal("ConversationListPage", "Debug level set to " + DebugLogger.getDebugLevel());
        
        // Load provider aliases if configured
        if (providerAliasesConfig.value) {
            try {
                LLMApi.loadProviderAliases(providerAliasesConfig.value);
                DebugLogger.logInfo("ConversationListPage", "Loaded provider aliases from config");
            } catch (e) {
                DebugLogger.logError("ConversationListPage", "Failed to load provider aliases: " + e.toString());
            }
        } else {
            // No provider aliases found - user needs to create them
            DebugLogger.logInfo("ConversationListPage", "No provider aliases found - user needs to create them manually");
        }

        // Load legacy configs for backward compatibility (will be migrated to aliases)
        var configs = [
            {provider: "gemini", config: geminiConfig},
            {provider: "openai", config: openaiConfig},
            {provider: "anthropic", config: anthropicConfig},
            {provider: "ollama", config: ollamaConfig}
        ];

        for (var i = 0; i < configs.length; i++) {
            var item = configs[i];
            if (item.config.value) {
                try {
                    // Legacy config loading - migrated to alias system
                    DebugLogger.logInfo("ConversationListPage", "Loaded legacy config for provider: " + item.provider);
                } catch (e) {
                    DebugLogger.logError("ConversationListPage", "Failed to load legacy config for provider " + item.provider + ": " + e.toString());
                }
            }
        }
    }

    // Database operations now handled by DatabaseManager singleton

    function loadConversations() {
        conversationList.clear();
        var conversations = app.database.loadConversations();
        for (var i = 0; i < conversations.length; i++) {
            conversationList.append(conversations[i]);
        }
        DebugLogger.logInfo("ConversationListPage", "Loaded " + conversations.length + " conversations");
    }

    function newConversation() {
        // Fixed deadlock: DB operation BEFORE pageStack.push
        var conversationId = app.database.createConversation("New Conversation");
        if (conversationId > 0) {
            DebugLogger.logInfo("ConversationListPage", "Created new conversation with ID: " + conversationId);
            
            // Open the new chat AFTER DB operation completes
            pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                "conversationId": conversationId,
                "conversationName": "New Conversation"
            });
        } else {
            DebugLogger.logError("ConversationListPage", "Failed to create conversation");
        }
    }

    function deleteConversation(conversationId) {
        if (app.database.deleteConversation(conversationId)) {
            DebugLogger.logInfo("ConversationListPage", "Deleted conversation: " + conversationId);
            loadConversations();
        } else {
            DebugLogger.logError("ConversationListPage", "Failed to delete conversation: " + conversationId);
        }
    }

    Component.onCompleted: {
        DebugLogger.logNormal("ConversationListPage", "Loading conversations");
        
        // Database initialization handled by DatabaseManager singleton
        // Load provider configs from Settings
        loadAllConfigs();
        
        // Load conversations (DatabaseManager will queue if not initialized yet)
        loadConversations();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "Settings"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "SailorAI"
                description: "Conversations"
            }

            Button {
                text: "New Chat"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: newConversation()
            }

            SilicaListView {
                width: parent.width
                height: conversationList.count > 0 ? conversationList.count * Theme.itemSizeMedium : 200
                model: conversationList

                delegate: ListItem {
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                            "conversationId": model.id,
                            "conversationName": model.name
                        });
                    }

                    Label {
                        text: model.name || ("Conversation " + model.id)
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.primaryColor
                    }

                    menu: ContextMenu {
                        MenuItem {
                            text: "Rename"
                            onClicked: {
                                var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/RenameDialog.qml"), {
                                    "originalName": model.name || ("Conversation " + model.id)
                                });
                                dialog.accepted.connect(function() {
                                    if (app.database.updateConversationName(model.id, dialog.newName)) {
                                        DebugLogger.logInfo("ConversationListPage", "Renamed conversation " + model.id + " to: " + dialog.newName);
                                        loadConversations();
                                    } else {
                                        DebugLogger.logError("ConversationListPage", "Failed to rename conversation: " + model.id);
                                    }
                                });
                            }
                        }
                        MenuItem {
                            text: "Delete"
                            onClicked: {
                                deleteConversation(model.id);
                            }
                        }
                    }
                }

                ViewPlaceholder {
                    enabled: conversationList.count === 0
                    text: "No conversations yet"
                    hintText: "Pull down to access settings or tap 'New Chat' to start"
                }
            }
        }
    }
}