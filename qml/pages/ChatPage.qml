import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger
import "../js/DatabaseQueries.js" as DatabaseQueries

Page {
    id: page

    // Properties passed from ConversationListPage
    property int conversationId: -1
    property string conversationName: "Chat"

    ListModel {
        id: chatModel
    }

    property int currentConversationId: conversationId
    property string selectedAliasId: ""
    property string selectedModel: "gemini-1.5-flash"
    property var availableAliases: []
    property var availableModels: []
    property bool isGenerating: false
    property string streamingContent: ""
    property int streamingMessageIndex: -1
    
    // Configuration for last selected provider/model
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
    

    function getProviderDisplayName() {
        if (selectedAliasId) {
            var alias = LLMApi.getProviderAlias(selectedAliasId);
            return alias ? alias.name : selectedAliasId;
        }
        return "No Provider";
    }

    // Save current selection to configuration
    function saveCurrentSelection() {
        if (selectedAliasId) {
            lastSelectedAlias.value = selectedAliasId;
            DebugLogger.logVerbose("ChatPage", "Saved last selected alias: " + selectedAliasId);
        }
        if (selectedModel) {
            lastSelectedModel.value = selectedModel;
            DebugLogger.logVerbose("ChatPage", "Saved last selected model: " + selectedModel);
        }
    }
    
    // Restore last selection from configuration
    function restoreLastSelection() {
        if (lastSelectedAlias.value && availableAliases.indexOf(lastSelectedAlias.value) !== -1) {
            selectedAliasId = lastSelectedAlias.value;
            DebugLogger.logInfo("ChatPage", "Restored last selected alias: " + selectedAliasId);
        }
        if (lastSelectedModel.value) {
            selectedModel = lastSelectedModel.value;
            DebugLogger.logInfo("ChatPage", "Restored last selected model: " + selectedModel);
        }
    }
    
    // Finalize streaming message - save to DB and clean up
    function finalizeStreamingMessage() {
        if (streamingMessageIndex >= 0) {
            if (streamingContent.length > 0) {
                // Save the complete streamed content to database
                saveMessage("bot", streamingContent);
                DebugLogger.logInfo("ChatPage", "Saved streaming message to DB: " + streamingContent.length + " characters");
            } else {
                // Remove empty streaming message if no content was received
                chatModel.remove(streamingMessageIndex);
                DebugLogger.logInfo("ChatPage", "Removed empty streaming message");
            }
            // Clean up streaming state
            streamingMessageIndex = -1;
            streamingContent = "";
        }
    }

    function loadAliases() {
        availableAliases = LLMApi.getProviderAliases();
        DebugLogger.logInfo("ChatPage", "Loaded " + availableAliases.length + " provider aliases");
        
        if (availableAliases.length > 0) {
            // First restore last selection if available
            restoreLastSelection();
            
            // If still no valid selection, use first available
            if (!selectedAliasId || availableAliases.indexOf(selectedAliasId) === -1) {
                selectedAliasId = availableAliases[0];
                DebugLogger.logInfo("ChatPage", "Selected default alias: " + selectedAliasId);
            }
            loadModels();
        }
    }

    function loadModels() {
        if (selectedAliasId) {
            var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
            availableModels = LLMApi.getAliasModels(selectedAliasId);
            
            // Only use favorite model if no model is currently selected or current model is invalid
            if (availableModels.length > 0) {
                if (availableModels.indexOf(selectedModel) === -1) {
                    // Current model not available, try favorite or fallback to first
                    if (favoriteModel && availableModels.indexOf(favoriteModel) !== -1) {
                        selectedModel = favoriteModel;
                        DebugLogger.logVerbose("ChatPage", "Current model invalid, selected favorite: " + selectedModel);
                    } else {
                        selectedModel = availableModels[0];
                        DebugLogger.logVerbose("ChatPage", "Selected first available model: " + selectedModel);
                    }
                } else {
                    DebugLogger.logVerbose("ChatPage", "Keeping current model: " + selectedModel);
                }
            } else if (!selectedModel && favoriteModel) {
                // No models available but we have a favorite - use it
                selectedModel = favoriteModel;
                DebugLogger.logVerbose("ChatPage", "No models available, using favorite: " + selectedModel);
            }
            
            // If we have no models cached and have API key, fetch them
            var alias = LLMApi.getProviderAlias(selectedAliasId);
            if (availableModels.length === 0 && alias && alias.api_key) {
                DebugLogger.logInfo("ChatPage", "No models cached, fetching from API for: " + selectedAliasId);
                LLMApi.fetchModelsForAlias(selectedAliasId);
            }
        }
    }

    // Database operations now handled by DatabaseManager singleton

    // Conversation management is now handled by ConversationListPage

    function loadChat(conversationId) {
        DebugLogger.logInfo("ChatPage", "Loading chat for conversation: " + conversationId);

        chatModel.clear();
        currentConversationId = conversationId;
        
        var messages = app.database.loadMessages(conversationId);
        for (var i = 0; i < messages.length; i++) {
            chatModel.append(messages[i]);
        }
        
        DebugLogger.logInfo("ChatPage", "Loaded " + messages.length + " messages");
    }

    function saveMessage(role, message) {
        if (currentConversationId <= 0) {
            DebugLogger.logError("ChatPage", "Cannot save message: no conversation ID");
            return;
        }
        
        if (app.database.saveMessage(currentConversationId, role, message)) {
            DebugLogger.logVerbose("ChatPage", "Saved message: " + role + " - " + message.substring(0, 50) + "...");
        } else {
            DebugLogger.logError("ChatPage", "Failed to save message for conversation " + currentConversationId);
        }
    }

    // Settings are now handled by Qt.labs.settings in other pages

    function formatTimestamp(timestamp) {
        if (!timestamp) return ""
        var date = new Date(timestamp)
        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        
        if (messageDate.getTime() === today.getTime()) {
            // Today: show time only
            return Qt.formatDateTime(date, "hh:mm")
        } else if (messageDate.getTime() === today.getTime() - 86400000) {
            // Yesterday
            return "Yesterday " + Qt.formatDateTime(date, "hh:mm")
        } else {
            // Older: show date and time
            return Qt.formatDateTime(date, "dd.MM hh:mm")
        }
    }

    function generateResponse(prompt) {
        if (!selectedAliasId) {
            chatModel.append({role: "error", message: "Error: No provider alias selected", timestamp: Date.now()});
            return;
        }
        
        var alias = LLMApi.getProviderAlias(selectedAliasId);
        if (!alias) {
            chatModel.append({role: "error", message: "Error: Provider alias not found: " + selectedAliasId, timestamp: Date.now()});
            return;
        }
        
        if (!alias.api_key && alias.type !== "ollama") {
            chatModel.append({role: "error", message: "Error: No API key configured for " + alias.name, timestamp: Date.now()});
            return;
        }
        
        isGenerating = true;
        DebugLogger.logInfo("ChatPage", "Generating response with alias: " + selectedAliasId + ", model: " + selectedModel);
        
        // Build history from current chat (excluding the current prompt that was just added)
        var history = [];
        for (var i = 0; i < chatModel.count - 1; i++) { // -1 to exclude the message we just added
            var msg = chatModel.get(i);
            if (msg.role === "user" || msg.role === "bot") {
                history.push(msg);
            }
        }
        DebugLogger.logVerbose("ChatPage", "Built history with " + history.length + " messages (excluding current prompt)");
        
        // Check if streaming is supported
        var providerAlias = LLMApi.getProviderAlias(selectedAliasId);
        var providerTypes = LLMApi.getProviderTypes();
        var supportsStreaming = providerAlias && providerTypes[providerAlias.type] && providerTypes[providerAlias.type].supportsStreaming;
        
        if (supportsStreaming) {
            // Add empty bot message for streaming (will be saved to DB when complete)
            var timestamp = Date.now();
            chatModel.append({role: "bot", message: "", timestamp: timestamp, conversation_id: currentConversationId});
            streamingMessageIndex = chatModel.count - 1;
            streamingContent = "";
            DebugLogger.logInfo("ChatPage", "Starting streaming response");
        }
        
        LLMApi.generateContent(
            selectedAliasId,
            selectedModel, 
            prompt,
            alias.api_key,
            history,
            function(response) {
                if (!supportsStreaming) {
                    // Non-streaming response
                    chatModel.append({role: "bot", message: response, timestamp: Date.now(), conversation_id: currentConversationId});
                    DebugLogger.logVerbose("ChatPage", "Added bot response to UI, total count: " + chatModel.count);
                    saveMessage("bot", response);
                } else {
                    // Streaming completed - finalize the message
                    finalizeStreamingMessage();
                }
                isGenerating = false;
            },
            function(error) {
                // Finalize streaming message (will remove if empty or save if has content)
                finalizeStreamingMessage();
                
                chatModel.append({role: "error", message: error, timestamp: Date.now()});
                isGenerating = false;
                DebugLogger.logError("ChatPage", "Generation error: " + error);
            },
            function(chunk) {
                // Streaming callback
                if (streamingMessageIndex >= 0) {
                    streamingContent += chunk;
                    chatModel.setProperty(streamingMessageIndex, "message", streamingContent);
                    DebugLogger.logVerbose("ChatPage", "Streaming chunk added, total length: " + streamingContent.length);
                }
            }
        );
    }

    SilicaFlickable {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: messageInputContainer.top
        anchors.bottomMargin: Theme.paddingMedium
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "Settings"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Provider: " + getProviderDisplayName()
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": selectedAliasId,
                        "selectedModel": selectedModel
                    })
                    dialog.accepted.connect(function() {
                        selectedAliasId = dialog.selectedAliasId
                        selectedModel = dialog.selectedModel
                        saveCurrentSelection() // Save the new selection
                        loadModels()
                    })
                }
            }
            MenuItem {
                text: "Back to Conversations"
                onClicked: {
                    pageStack.pop()
                }
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: conversationName
                description: getProviderDisplayName() + " (" + selectedModel + ")"
            }

            SilicaListView {
                id: chatView
                width: parent.width
                height: Math.max(200, page.height - messageInputContainer.height - 200) // Dynamic height with minimum
                model: chatModel
                clip: true
                
                property bool manuallyScrolledToBottom: true
                
                verticalLayoutDirection: ListView.TopToBottom
                
                
                
                delegate: ListItem {
                    id: messageItem
                    width: chatView.width
                    contentHeight: messageContent.height + Theme.paddingMedium
                    
                    property bool isOwnMessage: model.role === "user"
                    property bool isErrorMessage: model.role === "error"
                    
                    Item {
                        id: messageContent
                        width: parent.width
                        height: messageBubble.height
                        
                        Rectangle {
                            id: messageBubble
                            width: Math.min(messageText.implicitWidth + 2 * Theme.paddingMedium, parent.width * 0.8)
                            height: messageText.implicitHeight + timestampLabel.height + 3 * Theme.paddingSmall
                            
                            anchors.right: messageItem.isOwnMessage ? parent.right : undefined
                            anchors.left: messageItem.isOwnMessage ? undefined : parent.left
                            anchors.rightMargin: messageItem.isOwnMessage ? Theme.horizontalPageMargin : 0
                            anchors.leftMargin: messageItem.isOwnMessage ? 0 : Theme.horizontalPageMargin
                            
                            radius: Theme.paddingMedium
                            color: {
                                if (messageItem.isOwnMessage) return Theme.rgba(Theme.highlightBackgroundColor, 0.6)
                                if (messageItem.isErrorMessage) return Theme.errorColor
                                return Theme.rgba(Theme.secondaryHighlightColor, 0.4)
                            }
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.paddingSmall
                                spacing: Theme.paddingSmall
                                
                                Label {
                                    id: messageText
                                    width: parent.width
                                    text: model.message
                                    wrapMode: Text.WordWrap
                                    color: {
                                        if (messageItem.isOwnMessage) return Theme.highlightColor
                                        if (messageItem.isErrorMessage) return "white"
                                        return Theme.primaryColor
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                
                                Row {
                                    width: parent.width
                                    
                                    Label {
                                        id: timestampLabel
                                        text: formatTimestamp(model.timestamp)
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: messageItem.isOwnMessage ? Theme.secondaryHighlightColor : Theme.secondaryColor
                                        anchors.bottom: parent.bottom
                                    }
                                    
                                    Item { width: Theme.paddingSmall; height: 1 }
                                    
                                    IconButton {
                                        icon.source: "image://theme/icon-s-clipboard"
                                        width: Theme.iconSizeSmall
                                        height: Theme.iconSizeSmall
                                        anchors.bottom: parent.bottom
                                        onClicked: {
                                            Clipboard.text = model.message
                                            console.log("Message copied to clipboard")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Retry button for error messages
                        Button {
                            visible: messageItem.isErrorMessage
                            text: "Retry"
                            width: Theme.buttonWidthSmall
                            anchors.top: messageBubble.bottom
                            anchors.topMargin: Theme.paddingSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                            onClicked: {
                                // Find the last user message to retry
                                for (var i = index - 1; i >= 0; i--) {
                                    var prevMessage = chatModel.get(i)
                                    if (prevMessage.role === "user") {
                                        generateResponse(prevMessage.message);
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                
                VerticalScrollDecorator { }
                
                // Auto-scroll to bottom when new messages arrive
                onCountChanged: {
                    DebugLogger.logVerbose("ChatPage", "ListView count changed to " + count + ", scrolling to bottom");
                    positionViewAtEnd();
                }
                
                // Auto-scroll during streaming when content changes
                Connections {
                    target: chatModel
                    function onDataChanged() {
                        if (streamingMessageIndex >= 0) {
                            chatView.positionViewAtEnd();
                        }
                    }
                }
                
                onMovementStarted: {
                    manuallyScrolledToBottom = atYEnd
                }
            }

            Label {
                visible: isGenerating && streamingMessageIndex < 0
                text: "AI is thinking..."
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.secondaryColor
                opacity: 0.8
            }
            
            Label {
                visible: isGenerating && streamingMessageIndex >= 0
                text: "AI is responding..."
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.highlightColor
                opacity: 0.8
                
                SequentialAnimation on opacity {
                    running: parent.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800 }
                    NumberAnimation { to: 0.8; duration: 800 }
                }
            }
        }
    }

    Column {
        id: messageInputContainer
        width: parent.width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingMedium
        spacing: Theme.paddingSmall
        

        
        // Message input row
        Row {
            id: messageInput
            width: parent.width
            spacing: Theme.paddingMedium

            TextField {
                id: textField
                width: parent.width - sendButton.width - advancedButton.width - 2 * Theme.paddingMedium
                placeholderText: "Type a message..."
                
                EnterKey.onClicked: {
                    if (!isGenerating && textField.text.trim() !== "") {
                        sendButton.clicked();
                    }
                }
            }
            
            IconButton {
                id: advancedButton
                icon.source: "image://theme/icon-s-developer"
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/AdvancedSettingsDialog.qml"), {
                        "temperature": 0.7,
                        "seed": -1
                    })
                }
            }

            IconButton {
                id: sendButton
                icon.source: isGenerating ? "image://theme/icon-s-sync" : "image://theme/icon-s-message"
                enabled: !isGenerating
                onClicked: {
                    var message = textField.text
                    if (message.trim() !== "" && !isGenerating) {
                        chatModel.append({role: "user", message: message, timestamp: Date.now(), conversation_id: currentConversationId});
                        DebugLogger.logVerbose("ChatPage", "Added user message to UI, total count: " + chatModel.count);
                        saveMessage("user", message);
                        generateResponse(message);
                        textField.text = ""
                    }
                }
            }
        }

        // Provider and Model selection button
        Button {
            text: getProviderDisplayName() + " (" + selectedModel + ")"
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                    "selectedAliasId": selectedAliasId,
                    "selectedModel": selectedModel
                })
                dialog.accepted.connect(function() {
                    selectedAliasId = dialog.selectedAliasId
                    selectedModel = dialog.selectedModel
                    saveCurrentSelection() // Save the new selection
                    loadModels()
                })
            }
        }
    }

    Component.onCompleted: {
        DebugLogger.logNormal("ChatPage", "Chat page loaded for conversation: " + conversationId)
        
        loadAliases();
        
        if (currentConversationId > 0) {
            loadChat(currentConversationId);
        }
    }
}
