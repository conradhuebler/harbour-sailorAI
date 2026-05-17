import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger
import "../js/DateUtils.js" as DateUtils
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

    ConfigurationValue {
        id: lastSelectedAlias
        key: "/SailorAI/last_selected_alias"
        defaultValue: ""
    }

    ConfigurationValue {
        id: lastSelectedModel
        key: "/SailorAI/last_selected_model"
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
            var isLocalhostOllama = alias.url && alias.url.indexOf("localhost:11434") !== -1;
            if (alias && (alias.api_key || isLocalhostOllama)) {
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
            
            var isLocalhostOllama = alias.url && alias.url.indexOf("localhost:11434") !== -1;
            if (alias && (alias.api_key || isLocalhostOllama)) {
                DebugLogger.logInfo("ConversationListPage", "✓ Active provider found: " + aliasId + " (" + alias.type + ")");
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
            var c = conversations[i];
            c.section_key = DateUtils.getDateSectionKey(c.last_activity);
            conversationList.append(c);
        }
        DebugLogger.logInfo("ConversationListPage", "Loaded " + conversations.length + " conversations");
        updateCoverStatistics();
    }

    // Map DateUtils section key -> localized header text.
    // Kept in QML so qsTr() can pick the strings up at extraction time.
    function sectionLabel(key) {
        if (!key) return ""
        if (key === "today")      return qsTr("Today")
        if (key === "yesterday")  return qsTr("Yesterday")
        if (key === "this_week")  return qsTr("This week")
        if (key === "last_week")  return qsTr("Last week")
        if (key === "older")      return qsTr("Older")
        if (key.indexOf("month:") === 0) {
            var parts = key.substring(6).split("-")
            var monthNames = [
                qsTr("January"), qsTr("February"), qsTr("March"), qsTr("April"),
                qsTr("May"), qsTr("June"), qsTr("July"), qsTr("August"),
                qsTr("September"), qsTr("October"), qsTr("November"), qsTr("December")
            ]
            var idx = parseInt(parts[1]) - 1
            if (idx < 0 || idx > 11) return key
            return monthNames[idx] + " " + parts[0]
        }
        return key
    }

    function newConversation() {
        // Conversation is created lazily in ChatPage.saveMessage() on first send
        pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
            "conversationId": 0,
            "conversationName": "New Conversation"
        });
    }

    function newConversationWithProvider(aliasId, model) {
        // Conversation is created lazily in ChatPage.saveMessage() on first send
        var chatPage = pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
            "conversationId": 0,
            "conversationName": "New Conversation"
        });
        if (chatPage) {
            chatPage.selectedAliasId = aliasId || "";
            chatPage.selectedModel = model || "";
            if (aliasId && model) {
                chatPage.saveCurrentSelection();
                DebugLogger.logInfo("ConversationListPage", "Pre-selected provider: " + aliasId + " with model: " + model);
            }
        }
    }

    // Claude Generated: Open new chat with a pre-captured photo and pre-filled action prompt
    function newConversationWithPhotoAction(imagePath, prompt) {
        pageStack.push(Qt.resolvedUrl("ChatPage.qml"), {
            "conversationId": 0,
            "conversationName": qsTr("New Conversation"),
            "initialImages": [imagePath],
            "initialPrompt": prompt
        })
    }

    // Claude Generated: Deferred push after camera page pops (page stack needs to settle)
    Timer {
        id: photoActionTimer
        interval: 50
        repeat: false
        property string pendingPath: ""
        property string pendingPrompt: ""
        onTriggered: newConversationWithPhotoAction(pendingPath, pendingPrompt)
    }

    // Claude Generated: Open camera, then on capture pop camera and open new chat with photo
    function openPhotoAction(prompt) {
        var camPage = pageStack.push(Qt.resolvedUrl("CameraCapturePage.qml"))
        if (camPage) {
            var capturedPrompt = prompt
            camPage.photoCaptured.connect(function(path) {
                pageStack.pop(null, PageStackAction.Immediate)
                photoActionTimer.pendingPath = path
                photoActionTimer.pendingPrompt = capturedPrompt
                photoActionTimer.restart()
            })
        }
    }

    // Claude Generated: Handle image shared/opened from another app (Gallery, Files, etc.)
    function handleSharedImage(imagePath) {
        var actionPage = pageStack.push(Qt.resolvedUrl("../dialogs/ShareActionPage.qml"), {
            "imagePath": imagePath
        })
        if (actionPage) {
            actionPage.actionSelected.connect(function(prompt) {
                photoActionTimer.pendingPath = imagePath
                photoActionTimer.pendingPrompt = prompt
                photoActionTimer.restart()
            })
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

    function _handlePendingSharedImage() {
        if (app.pendingSharedImage !== "") {
            var path = app.pendingSharedImage
            app.pendingSharedImage = ""
            handleSharedImage(path)
        }
    }

    // Pick up images shared while page was not yet active (cover action, ExecDBus start, etc.)
    Connections {
        target: app
        onPendingSharedImageChanged: {
            if (status === PageStatus.Active) {
                _handlePendingSharedImage()
            }
        }
    }

    // Refresh conversations when page becomes active
    onStatusChanged: {
        if (status === PageStatus.Activating) {
            DebugLogger.logInfo("ConversationListPage", "Page activating - refreshing conversations");
            loadConversations();
            updateCoverStatistics();
        }
        if (status === PageStatus.Active) {
            _handlePendingSharedImage()
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
                text: qsTr("New Chat")
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: app.hasActiveProviders
                onClicked: newConversation()
                onPressAndHold: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": lastSelectedAlias.value,
                        "selectedModel": lastSelectedModel.value
                    });
                    dialog.accepted.connect(function() {
                        var aliasId = dialog.selectedAliasId;
                        var model = dialog.selectedModel;
                        // Remove dialog from stack immediately so back-navigation
                        // from ChatPage returns to ConversationListPage, not the dialog
                        pageStack.pop(null, PageStackAction.Immediate);
                        newConversationWithProvider(aliasId, model);
                    });
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                Button {
                    text: qsTr("Describe photo")
                    enabled: app.hasActiveProviders
                    onClicked: openPhotoAction(
                        qsTr("Please describe this photo in %1.").arg(Qt.locale().nativeLanguageName))
                }

                Button {
                    text: qsTr("Translate from photo")
                    enabled: app.hasActiveProviders
                    onClicked: openPhotoAction(
                        qsTr("Please translate all text visible in this photo to %1.").arg(Qt.locale().nativeLanguageName))
                }
            }

            SilicaListView {
                width: parent.width
                // Bind to contentHeight so section headers expand the list naturally.
                height: contentHeight > 0 ? contentHeight : 200
                interactive: false  // outer SilicaFlickable handles scrolling
                model: conversationList

                section.property: "section_key"
                section.delegate: SectionHeader {
                    text: sectionLabel(section)
                }

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
                                visible: !!model.last_provider && !!model.last_model
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
                        MenuItem {
                            text: qsTr("Export")
                            onClicked: {
                                var displayName = model.name || ("Conversation " + model.id)
                                pageStack.push(Qt.resolvedUrl("../dialogs/ExportDialog.qml"), {
                                    "conversationId": model.id,
                                    "conversationName": displayName
                                })
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
