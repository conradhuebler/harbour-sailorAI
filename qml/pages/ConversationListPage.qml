import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger
import "../js/DatabaseQueries.js" as DatabaseQueries

Page {
    id: page
    objectName: "conversationListPage"

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

    // Date formatting helper function
    function formatDate(timestamp) {
        if (!timestamp) return "";
        
        var date = new Date(timestamp);
        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        
        if (messageDate.getTime() === today.getTime()) {
            // Today: show time only
            return Qt.formatDateTime(date, "hh:mm");
        } else if (messageDate.getTime() === today.getTime() - 86400000) {
            // Yesterday
            return "Yesterday";
        } else if (now.getTime() - date.getTime() < 7 * 86400000) {
            // This week: show day name
            return Qt.formatDateTime(date, "ddd");
        } else {
            // Older: show date
            return Qt.formatDateTime(date, "dd.MM.yy");
        }
    }

    // Format conversation timespan (start - end)
    function formatConversationTimespan(firstActivity, lastActivity) {
        if (!firstActivity || !lastActivity) return "";
        
        var first = new Date(firstActivity);
        var last = new Date(lastActivity);
        var now = new Date();
        
        // If same day, show date + time range
        if (first.toDateString() === last.toDateString()) {
            var dayLabel = formatDate(lastActivity);
            if (first.getTime() === last.getTime()) {
                // Single message
                return dayLabel;
            } else {
                // Time range on same day
                return dayLabel + " (" + Qt.formatDateTime(first, "hh:mm") + "-" + Qt.formatDateTime(last, "hh:mm") + ")";
            }
        } else {
            // Different days: show start date - end date
            var firstStr = Qt.formatDateTime(first, "dd.MM");
            var lastStr = formatDate(lastActivity);
            return firstStr + " - " + lastStr;
        }
    }

    function updateCoverStatistics() {
        // Update app-wide statistics for cover
        app.activeProviderCount = getActiveProviderCount();
        app.conversationCount = conversationList.count;
        app.hasActiveProviders = hasActiveProviders();
        
        DebugLogger.logVerbose("ConversationListPage", "Updated cover stats: " + 
            app.activeProviderCount + " providers, " + 
            app.conversationCount + " conversations, " +
            "active: " + app.hasActiveProviders);
    }
    
    function getActiveProviderCount() {
        var aliases = LLMApi.getProviderAliases();
        var count = 0;
        for (var i = 0; i < aliases.length; i++) {
            var alias = LLMApi.getProviderAlias(aliases[i]);
            if (alias && (alias.api_key || alias.type === "ollama")) {
                count++;
            }
        }
        return count;
    }

    function hasActiveProviders() {
        var aliases = LLMApi.getProviderAliases();
        DebugLogger.logInfo("ConversationListPage", "=== CHECKING ACTIVE PROVIDERS ===");
        DebugLogger.logInfo("ConversationListPage", "Found " + aliases.length + " total aliases");
        
        for (var i = 0; i < aliases.length; i++) {
            var aliasId = aliases[i];
            var alias = LLMApi.getProviderAlias(aliasId);
            DebugLogger.logInfo("ConversationListPage", "Alias " + aliasId + ": type=" + (alias ? alias.type : "null") + ", api_key=" + (alias && alias.api_key ? "***SET***" : "empty"));
            
            if (alias && alias.api_key && alias.type !== "ollama") {
                DebugLogger.logInfo("ConversationListPage", "✓ Active provider found: " + aliasId + " (" + alias.type + ")");
                return true;
            } else if (alias && alias.type === "ollama") {
                // Ollama doesn't require API key
                DebugLogger.logInfo("ConversationListPage", "✓ Active Ollama provider found: " + aliasId);
                return true;
            }
        }
        DebugLogger.logInfo("ConversationListPage", "✗ No active providers found");
        return false;
    }

    function autoFetchModelsForAllProviders() {
        var aliases = LLMApi.getProviderAliases();
        var fetchCount = 0;
        
        for (var i = 0; i < aliases.length; i++) {
            var aliasId = aliases[i];
            var alias = LLMApi.getProviderAlias(aliasId);
            
            if (alias && alias.api_key) {
                var cachedModels = LLMApi.getAliasModels(aliasId);
                if (cachedModels.length === 0) {
                    DebugLogger.logInfo("ConversationListPage", "Auto-fetching models for: " + aliasId);
                    LLMApi.fetchModelsForAlias(aliasId);
                    fetchCount++;
                } else {
                    DebugLogger.logVerbose("ConversationListPage", "Models already cached for: " + aliasId + " (" + cachedModels.length + " models)");
                }
            } else if (alias) {
                DebugLogger.logVerbose("ConversationListPage", "Skipping model fetch for " + aliasId + " (no API key)");
            }
        }
        
        if (fetchCount > 0) {
            DebugLogger.logInfo("ConversationListPage", "Started background model fetch for " + fetchCount + " providers");
        }
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
                
                // Auto-fetch models for all providers with API keys
                autoFetchModelsForAllProviders();
                
                // Update cover statistics after loading providers
                updateCoverStatistics();
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
        updateCoverStatistics();
    }

    function newConversation() {
        // Fixed deadlock: DB operation BEFORE pageStack.push
        var conversationId = app.database.createConversation("New Conversation");
        if (conversationId > 0) {
            DebugLogger.logInfo("ConversationListPage", "Created new conversation with ID: " + conversationId);
            
            // Refresh the conversation list to show the new conversation
            loadConversations();
            
            // Open the new chat AFTER DB operation completes
            pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                "conversationId": conversationId,
                "conversationName": "New Conversation"
            });
        } else {
            DebugLogger.logError("ConversationListPage", "Failed to create conversation");
        }
    }

    function newConversationWithProvider(aliasId, model) {
        // Create new conversation with pre-selected provider/model
        var conversationId = app.database.createConversation("New Conversation");
        if (conversationId > 0) {
            DebugLogger.logInfo("ConversationListPage", "Created new conversation with ID: " + conversationId + " (Provider: " + aliasId + ", Model: " + model + ")");
            
            // Refresh the conversation list to show the new conversation
            loadConversations();
            
            // Open the new chat with pre-selected provider/model
            var chatPage = pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                "conversationId": conversationId,
                "conversationName": "New Conversation"
            });
            
            // Set the selected provider/model after page is loaded
            if (chatPage) {
                chatPage.selectedAliasId = aliasId || "";
                chatPage.selectedModel = model || "";
                
                // Save this selection as the new default
                if (aliasId && model) {
                    chatPage.saveCurrentSelection();
                    DebugLogger.logInfo("ConversationListPage", "Pre-selected provider: " + aliasId + " with model: " + model);
                }
            }
        } else {
            DebugLogger.logError("ConversationListPage", "Failed to create conversation with provider");
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

    // Refresh conversations when page becomes active
    onStatusChanged: {
        if (status === PageStatus.Activating) {
            DebugLogger.logInfo("ConversationListPage", "Page activating - refreshing conversations");
            loadConversations();
            updateCoverStatistics();
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
                enabled: app.hasActiveProviders
                onClicked: newConversation()
                onPressAndHold: {
                    // Open provider selection dialog for new chat
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": "",
                        "selectedModel": ""
                    });
                    dialog.accepted.connect(function() {
                        // Create new conversation with selected provider/model
                        newConversationWithProvider(dialog.selectedAliasId, dialog.selectedModel);
                    });
                }
            }

            SilicaListView {
                width: parent.width
                height: conversationList.count > 0 ? conversationList.count * Theme.itemSizeLarge : 200
                model: conversationList

                delegate: ListItem {
                    contentHeight: Theme.itemSizeLarge
                    
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
                            "conversationId": model.id,
                            "conversationName": model.name
                        });
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.right: messageCountBadge.left
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall
                        
                        Label {
                            text: model.name || ("Conversation " + model.id)
                            width: parent.width
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryColor
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        
                        Row {
                            spacing: Theme.paddingMedium
                            
                            Label {
                                text: formatConversationTimespan(model.first_activity, model.last_activity)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                            
                            Label {
                                visible: model.last_provider && model.last_model
                                text: {
                                    if (model.last_provider && model.last_model) {
                                        // Get provider display name
                                        var alias = LLMApi.getProviderAlias(model.last_provider);
                                        var providerName = alias ? alias.name : model.last_provider;
                                        return providerName + " (" + model.last_model + ")";
                                    }
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.highlightColor
                                elide: Text.ElideRight
                            }
                        }
                    }
                    
                    Rectangle {
                        id: messageCountBadge
                        visible: model.message_count > 0
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(Theme.iconSizeSmall, countLabel.implicitWidth + Theme.paddingSmall * 2)
                        height: Theme.iconSizeSmall
                        radius: height / 2
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.6)
                        
                        Label {
                            id: countLabel
                            anchors.centerIn: parent
                            text: model.message_count
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                        }
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
                                // Find the ListItem to apply remorse action
                                var listItem = parent.parent.parent; // Navigate from MenuItem -> ContextMenu -> ListItem
                                listItem.remorseAction("Deleting conversation", function() {
                                    deleteConversation(model.id);
                                });
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