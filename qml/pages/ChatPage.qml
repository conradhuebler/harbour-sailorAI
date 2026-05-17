import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
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
    
    // Image upload properties
    property var selectedImages: []
    property bool hasImages: selectedImages.length > 0

    // Safety timeout for image/multimodal requests
    Timer {
        id: imageRequestTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (isGenerating) {
                DebugLogger.logError("ChatPage", "Image request timed out after " + interval + " ms");
                chatModel.append({role: "error", message: "Error: Request timed out", timestamp: Date.now()});
                isGenerating = false;
            }
        }
    }

    // Canvas for resizing large images before sending to API
    Canvas {
        id: imageResizeCanvas
        width: 1
        height: 1
        visible: false

        property var pendingCallback: null
        property string pendingSource: ""
        property real pendingOrigW: 0
        property real pendingOrigH: 0

        onImageLoaded: {
            DebugLogger.logInfo("ChatPage", "Canvas image loaded, resizing from " + pendingOrigW + "x" + pendingOrigH);
            var ctx = getContext('2d');
            var scale = Math.min(1280 / pendingOrigW, 1280 / pendingOrigH, 1.0);
            var w = Math.round(pendingOrigW * scale);
            var h = Math.round(pendingOrigH * scale);
            imageResizeCanvas.width = w;
            imageResizeCanvas.height = h;
            ctx.clearRect(0, 0, w, h);
            ctx.drawImage(pendingSource, 0, 0, w, h);
            var resizedB64 = imageResizeCanvas.toDataURL('image/jpeg', 0.7);
            // Strip data URL prefix: "data:image/jpeg;base64,"
            var b64Data = resizedB64.substring(resizedB64.indexOf(',') + 1);
            DebugLogger.logInfo("ChatPage", "Resized image from " + pendingOrigW + "x" + pendingOrigH + " to " + w + "x" + h + " (" + b64Data.length + " base64 chars)");
            var cb = pendingCallback;
            pendingCallback = null;
            if (b64Data.length < 100) {
                DebugLogger.logError("ChatPage", "Resize produced tiny output (" + b64Data.length + " chars), falling back to original");
                cb(null);
            } else {
                cb({ data: b64Data, mimeType: "image/jpeg" });
            }
        }

    }

    // Resize a large image using QML Canvas with loadImage
    function resizeImageFile(imageUrl, maxWidth, maxHeight, callback) {
        // Get image dimensions first using a temporary Image element
        var tmpImg = Qt.createQmlObject('import QtQuick 2.0; Image { source: "' + imageUrl + '"; cache: false }', page);
        function proceed() {
            var origW = tmpImg.implicitWidth;
            var origH = tmpImg.implicitHeight;
            tmpImg.destroy();
            var scale = Math.min(maxWidth / origW, maxHeight / origH, 1.0);
            var w = Math.round(origW * scale);
            var h = Math.round(origH * scale);
            DebugLogger.logInfo("ChatPage", "Resizing image from " + origW + "x" + origH + " to " + w + "x" + h);
            imageResizeCanvas.pendingCallback = callback;
            imageResizeCanvas.pendingSource = imageUrl;
            imageResizeCanvas.pendingOrigW = origW;
            imageResizeCanvas.pendingOrigH = origH;
            imageResizeCanvas.width = w;
            imageResizeCanvas.height = h;
            imageResizeCanvas.loadImage(imageUrl);
        }
        if (tmpImg.status === Image.Ready) {
            proceed();
        } else if (tmpImg.status === Image.Error) {
            DebugLogger.logError("ChatPage", "Failed to load image for resizing: " + imageUrl);
            tmpImg.destroy();
            callback(null);
        } else {
            tmpImg.onStatusChanged.connect(function() {
                if (tmpImg.status === Image.Ready) proceed();
                else if (tmpImg.status === Image.Error) {
                    DebugLogger.logError("ChatPage", "Failed to load image for resizing: " + imageUrl);
                    tmpImg.destroy();
                    callback(null);
                }
            });
        }
    }

    // Maximum base64 size for images before resizing. Ollama cloud accepts
    // ~2.5 MB payloads fine (verified). The Canvas-based resize path below is
    // currently broken (onImageLoaded never fires), so keep this generous and
    // let typical phone photos through unresized.
    property int maxImageBase64Size: 4000000


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
                // Save the complete streamed content to database with provider/model info
                saveMessage("bot", streamingContent, selectedAliasId, selectedModel);
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

    // Auto-generate conversation title from first user message
    function autoGenerateConversationTitle(message) {
        // Only generate title if this is still "New Conversation" and we have a meaningful message
        if (conversationName !== "New Conversation" || !message || message.trim().length === 0) {
            return;
        }
        
        // Check if this is the first user message (excluding the title message itself)
        var userMessageCount = 0;
        for (var i = 0; i < chatModel.count; i++) {
            var msg = chatModel.get(i);
            if (msg.role === "user") {
                userMessageCount++;
            }
        }
        
        // Only generate title from the first user message
        if (userMessageCount !== 1) {
            return;
        }
        
        // Clean and truncate the message for title
        var title = message.trim();
        
        // Remove line breaks and excessive whitespace
        title = title.replace(/\s+/g, ' ');
        
        // Truncate to reasonable length
        var maxLength = 40;
        if (title.length > maxLength) {
            title = title.substring(0, maxLength) + "...";
        }
        
        // Update conversation name
        if (app.database.updateConversationName(currentConversationId, title)) {
            conversationName = title;
            DebugLogger.logInfo("ChatPage", "Auto-generated conversation title: " + title);
            
            // Force refresh of the PageHeader by triggering property change
            pageHeader.title = conversationName;
            
            // Update the conversation list if previous page exists
            if (pageStack.previousPage && pageStack.previousPage.loadConversations) {
                pageStack.previousPage.loadConversations();
                DebugLogger.logVerbose("ChatPage", "Triggered conversation list refresh");
            }
        } else {
            DebugLogger.logError("ChatPage", "Failed to auto-generate conversation title");
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

    function sortModelsByFavorites(models, aliasId) {
        if (!models || models.length === 0) return [];
        
        var favorites = LLMApi.getAliasFavoriteModels(aliasId);
        var favoriteModels = [];
        var otherModels = [];
        
        // Separate favorites from non-favorites
        for (var i = 0; i < models.length; i++) {
            if (favorites.indexOf(models[i]) !== -1) {
                favoriteModels.push(models[i]);
            } else {
                otherModels.push(models[i]);
            }
        }
        
        // Sort favorites by their order in the favorites list
        favoriteModels.sort(function(a, b) {
            return favorites.indexOf(a) - favorites.indexOf(b);
        });
        
        // Return favorites first, then other models
        return favoriteModels.concat(otherModels);
    }

    function loadModels() {
        if (selectedAliasId) {
            var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
            var rawModels = LLMApi.getAliasModels(selectedAliasId);
            
            // Sort models with favorites first
            availableModels = sortModelsByFavorites(rawModels, selectedAliasId);
            
            DebugLogger.logInfo("ChatPage", "Loading models for " + selectedAliasId + " - Available: " + availableModels.length + ", Favorite: " + (favoriteModel || "none"));
            
            // Always prefer the favorite model for the current provider when switching
            if (availableModels.length > 0) {
                // Priority: 1) Provider's favorite model, 2) First available model
                if (favoriteModel && availableModels.indexOf(favoriteModel) !== -1) {
                    selectedModel = favoriteModel;
                    DebugLogger.logInfo("ChatPage", "✓ Selected provider's favorite model: " + selectedModel);
                } else {
                    selectedModel = availableModels[0];
                    DebugLogger.logInfo("ChatPage", "Selected first available model: " + selectedModel + " (favorite '" + favoriteModel + "' not in list)");
                }
            } else {
                // No models cached - try to fetch them and use favorite as fallback
                var alias = LLMApi.getProviderAlias(selectedAliasId);
                if (alias && alias.api_key) {
                    DebugLogger.logInfo("ChatPage", "No models cached, fetching from API for: " + selectedAliasId);
                    LLMApi.fetchModelsForAlias(selectedAliasId);
                    
                    // Use favorite as temporary selection while fetching
                    if (favoriteModel) {
                        selectedModel = favoriteModel;
                        DebugLogger.logInfo("ChatPage", "Using favorite as temporary selection: " + selectedModel);
                    }
                } else if (favoriteModel) {
                    // No API key but we have a favorite - use it
                    selectedModel = favoriteModel;
                    DebugLogger.logInfo("ChatPage", "No API key, using favorite: " + selectedModel);
                }
            }
            
            // Log final selection
            DebugLogger.logInfo("ChatPage", "Final model selection: " + selectedModel + " for provider " + selectedAliasId);
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

    function saveMessage(role, message, providerAlias, modelName) {
        if (currentConversationId <= 0) {
            DebugLogger.logError("ChatPage", "Cannot save message: no conversation ID");
            return;
        }
        
        // Use current selection if not provided
        var provider = providerAlias || (role === "bot" ? selectedAliasId : null);
        var model = modelName || (role === "bot" ? selectedModel : null);
        
        if (app.database.saveMessage(currentConversationId, role, message, provider, model)) {
            var logDetails = role;
            if (provider && model) {
                logDetails += " (" + provider + " / " + model + ")";
            }
            DebugLogger.logVerbose("ChatPage", "Saved message: " + logDetails + " - " + message.substring(0, 50) + "...");
            
            // Signal that conversation list should be refreshed
            if (pageStack.previousPage && pageStack.previousPage.loadConversations) {
                pageStack.previousPage.loadConversations();
                DebugLogger.logVerbose("ChatPage", "Triggered conversation list refresh");
            }
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
        var supportsStreaming = providerAlias && providerAlias.supportsStreaming;
        
        if (supportsStreaming) {
            // Add empty bot message for streaming (will be saved to DB when complete)
            var timestamp = Date.now();
            chatModel.append({
                role: "bot", 
                message: "", 
                timestamp: timestamp, 
                conversation_id: currentConversationId,
                provider_alias: selectedAliasId,
                model_name: selectedModel
            });
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
                    chatModel.append({
                        role: "bot", 
                        message: response, 
                        timestamp: Date.now(), 
                        conversation_id: currentConversationId,
                        provider_alias: selectedAliasId,
                        model_name: selectedModel
                    });
                    DebugLogger.logVerbose("ChatPage", "Added bot response to UI, total count: " + chatModel.count);
                    saveMessage("bot", response, selectedAliasId, selectedModel);
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
            supportsStreaming ? function(chunk) {
                // Streaming callback (only passed if streaming is supported)
                if (streamingMessageIndex >= 0) {
                    streamingContent += chunk;
                    chatModel.setProperty(streamingMessageIndex, "message", streamingContent);
                    DebugLogger.logVerbose("ChatPage", "Streaming chunk added, total length: " + streamingContent.length);
                }
            } : null
        );
    }

    function generateResponseWithImages(prompt, images) {
        if (images && images.length > 0) {
            DebugLogger.logInfo("ChatPage", "Generating multimodal response with " + images.length + " images");

            // Use the enhanced LLM generation with image support
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
            DebugLogger.logInfo("ChatPage", "Generating multimodal response with alias: " + selectedAliasId + ", model: " + selectedModel);

            // Safety timeout: reset isGenerating if no response within 60 seconds
            imageRequestTimer.interval = 60000;
            imageRequestTimer.start();

            // Build history from current chat (excluding the current prompt that was just added)
            var history = [];
            for (var i = 0; i < chatModel.count - 1; i++) { // -1 to exclude the message we just added
                var msg = chatModel.get(i);
                if (msg.role === "user" || msg.role === "bot") {
                    history.push(msg);
                }
            }

            // Check if streaming is supported for multimodal requests
            var supportsStreaming = alias.supportsStreaming;
            DebugLogger.logInfo("ChatPage", "Multimodal request streaming: " + supportsStreaming);

            if (supportsStreaming) {
                // Add empty bot message placeholder for streaming
                chatModel.append({
                    role: "bot",
                    message: "",
                    timestamp: Date.now(),
                    conversation_id: currentConversationId,
                    provider_alias: selectedAliasId,
                    model_name: selectedModel
                });
                streamingMessageIndex = chatModel.count - 1;
                streamingContent = "";
                DebugLogger.logInfo("ChatPage", "Starting multimodal streaming response");
            }

            // Asynchronously encode images to base64 before sending
            LLMApi.encodeImages(images, function(encodedImages) {
                if (encodedImages.length === 0 && images.length > 0) {
                    imageRequestTimer.stop();
                    chatModel.append({role: "error", message: "Error: Failed to process images", timestamp: Date.now()});
                    isGenerating = false;
                    DebugLogger.logError("ChatPage", "Image encoding failed for all " + images.length + " images");
                    return;
                }

                DebugLogger.logInfo("ChatPage", "Encoded " + encodedImages.length + " images successfully");
                for (var ei = 0; ei < encodedImages.length; ei++) {
                    DebugLogger.logVerbose("ChatPage", "Image " + ei + ": " + encodedImages[ei].mimeType + ", data length=" + encodedImages[ei].data.length);
                }

                // Send images to API (called directly or after resize)
                var sendImages = function(imgs) {
                    DebugLogger.logInfo("ChatPage", "Sending " + imgs.length + " images");
                    for (var fi2 = 0; fi2 < imgs.length; fi2++) {
                        DebugLogger.logVerbose("ChatPage", "Final image " + fi2 + ": " + imgs[fi2].mimeType + ", data length=" + imgs[fi2].data.length);
                    }
                    LLMApi.generateContentWithImages(
                        selectedAliasId,
                        selectedModel,
                        prompt,
                        alias.api_key,
                        history,
                        imgs,
                        function(response) {
                            imageRequestTimer.stop();
                            if (!supportsStreaming) {
                                chatModel.append({
                                    role: "bot",
                                    message: response,
                                    timestamp: Date.now(),
                                    conversation_id: currentConversationId,
                                    provider_alias: selectedAliasId,
                                    model_name: selectedModel
                                });
                                saveMessage("bot", response, selectedAliasId, selectedModel);
                            } else {
                                finalizeStreamingMessage();
                            }
                            isGenerating = false;
                        },
                        function(error) {
                            imageRequestTimer.stop();
                            finalizeStreamingMessage();
                            chatModel.append({role: "error", message: error, timestamp: Date.now()});
                            isGenerating = false;
                            DebugLogger.logError("ChatPage", "Multimodal generation error: " + error);
                        },
                        function(chunk) {
                            if (streamingMessageIndex >= 0) {
                                streamingContent += chunk;
                                chatModel.setProperty(streamingMessageIndex, "message", streamingContent);
                                DebugLogger.logVerbose("ChatPage", "Multimodal streaming chunk added, total length: " + streamingContent.length);
                            }
                        }
                    );
                };

                // Resize images that exceed the size limit
                var imagesToResize = 0;
                var resizeCompleted = 0;
                var finalImages = [];
                for (var ri = 0; ri < encodedImages.length; ri++) {
                    if (encodedImages[ri].data.length > maxImageBase64Size) {
                        imagesToResize++;
                    }
                }

                if (imagesToResize > 0) {
                    DebugLogger.logInfo("ChatPage", imagesToResize + " image(s) exceed size limit, resizing");
                    for (var fi = 0; fi < encodedImages.length; fi++) {
                        (function(idx) {
                            if (encodedImages[idx].data.length > maxImageBase64Size) {
                                var path = encodedImages[idx].originalPath || "";
                                var fileUrl = path.indexOf("file://") === 0 ? path : "file://" + path;
                                resizeImageFile(fileUrl, 1280, 1280, function(resized) {
                                    resizeCompleted++;
                                    if (resized) {
                                        finalImages.push(resized);
                                    } else {
                                        DebugLogger.logError("ChatPage", "Resize failed, sending original");
                                        finalImages.push({ data: encodedImages[idx].data, mimeType: encodedImages[idx].mimeType });
                                    }
                                    if (resizeCompleted === imagesToResize) {
                                        for (var ni = 0; ni < encodedImages.length; ni++) {
                                            if (encodedImages[ni].data.length <= maxImageBase64Size) {
                                                finalImages.push(encodedImages[ni]);
                                            }
                                        }
                                        sendImages(finalImages);
                                    }
                                });
                            }
                        })(fi);
                    }
                } else {
                    sendImages(encodedImages);
                }
            });
        } else {
            generateResponse(prompt);
        }
    }

    // Main content area with proper structure for PullDownMenu
    SilicaFlickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.height
        
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
            MenuItem {
                text: "Export chat"
                onClicked: {
                    // Open an export dialog for the current conversation
                    var dlg = pageStack.push(Qt.resolvedUrl("../dialogs/ExportDialog.qml"), {
                        "conversationId": currentConversationId
                    })
                }
            }
        }
        
        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                id: pageHeader
                title: conversationName
                description: getProviderDisplayName() + " (" + selectedModel + ")"
            }

            // Chat messages area - properly fills remaining space
            SilicaListView {
                id: chatView
                width: parent.width
                height: page.height - pageHeader.height - messageInputContainer.height - Theme.paddingMedium * 4
                model: chatModel
                clip: true
        
        property bool manuallyScrolledToBottom: true
        
        verticalLayoutDirection: ListView.TopToBottom
        
        delegate: ListItem {
                    id: messageItem
                    width: chatView.width
                    contentHeight: messageContent.height + Theme.paddingMedium
                    
                    property bool isOwnMessage: model ? model.role === "user" : false
                    property bool isErrorMessage: model ? model.role === "error" : false
                    
                    Item {
                        id: messageContent
                        width: parent.width
                        height: messageBubble.height
                        
                        Rectangle {
                            id: messageBubble
                            width: Math.min(messageText.implicitWidth + 2 * Theme.paddingMedium, parent.width * 0.85)
                            height: messageColumn.implicitHeight + 2 * Theme.paddingSmall
                            
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
                                id: messageColumn
                                anchors.fill: parent
                                anchors.margins: Theme.paddingSmall
                                spacing: Theme.paddingSmall
                                
                                Label {
                                    id: messageText
                                    width: parent.width
                                    text: model ? model.message : ""
                                    wrapMode: Text.WordWrap
                                    color: {
                                        if (messageItem.isOwnMessage) return Theme.highlightColor
                                        if (messageItem.isErrorMessage) return "white"
                                        return Theme.primaryColor
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                // Image thumbnail for messages with attached images
                                Image {
                                    id: imageThumbnail
                                    visible: messageItem.isOwnMessage && model && model.images && model.images.length > 0
                                    width: visible ? Theme.itemSizeSmall * 2 : 0
                                    height: visible ? Theme.itemSizeSmall * 2 : 0
                                    source: visible ? (model.images[0].toString().indexOf("file://") === 0 ? model.images[0] : "file://" + model.images[0]) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    clip: true
                                    smooth: true
                                    onStatusChanged: {
                                        if (status === Image.Error) console.log("[ChatPage] Failed to load thumbnail: " + source)
                                    }
                                }
                                
                                // Provider/Model info for bot messages
                                Label {
                                    visible: model && model.role === "bot" && (!!model.provider_alias || !!model.model_name)
                                    width: parent.width
                                    text: {
                                        if (!model) return "";
                                        if (model.provider_alias && model.model_name) {
                                            var alias = LLMApi.getProviderAlias(model.provider_alias);
                                            var providerName = alias ? alias.name : model.provider_alias;
                                            return "via " + model.model_name + " (" + providerName + ")";
                                        } else if (model.model_name) {
                                            return "via " + model.model_name;
                                        } else if (model.provider_alias) {
                                            var alias = LLMApi.getProviderAlias(model.provider_alias);
                                            return "via " + (alias ? alias.name : model.provider_alias);
                                        }
                                        return "";
                                    }
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    font.italic: true
                                    color: messageItem.isErrorMessage ? "white" : Theme.secondaryColor
                                }
                                
                                Row {
                                    width: parent.width
                                    
                                    Label {
                                        id: timestampLabel
                                        text: model ? formatTimestamp(model.timestamp) : ""
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
                                            Clipboard.text = model ? model.message : ""
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
                                    if (prevMessage && prevMessage.role === "user") {
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
                        if (streamingMessageIndex >= 0 && manuallyScrolledToBottom) {
                            // Only auto-scroll if user hasn't manually scrolled away
                            chatView.positionViewAtEnd();
                        }
                    }
                }
                
                // Track user scroll behavior
                onMovementStarted: {
                    manuallyScrolledToBottom = (atYEnd === true);
                }
                
                onMovementEnded: {
                    manuallyScrolledToBottom = (atYEnd === true);
                }
                
                // Ensure we scroll to bottom when content height changes during streaming
                onContentHeightChanged: {
                    if (streamingMessageIndex >= 0 && manuallyScrolledToBottom) {
                        positionViewAtEnd();
                    }
                }
            }
        }
    }

    // Status indicators positioned between chat and input
    Label {
        visible: isGenerating && streamingMessageIndex < 0
        text: "AI is thinking..."
        anchors.bottom: messageInputContainer.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.paddingSmall
        color: Theme.secondaryColor
        opacity: 0.8
    }
    
    Label {
        visible: isGenerating && streamingMessageIndex >= 0
        text: "AI is responding..."
        anchors.bottom: messageInputContainer.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.paddingSmall
        color: Theme.highlightColor
        opacity: 0.8
        
        SequentialAnimation on opacity {
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 800 }
            NumberAnimation { to: 0.8; duration: 800 }
        }
    }

    Column {
        id: messageInputContainer
        width: parent.width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingMedium
        spacing: Theme.paddingSmall
        
        // Image preview area (shown when images are selected)
        Flickable {
            id: imagePreviewArea
            visible: hasImages
            width: parent.width
            height: visible ? Theme.itemSizeSmall * 1.5 : 0
            contentHeight: imagePreviewRow.height
            contentWidth: imagePreviewRow.width
            clip: true
            
            Row {
                id: imagePreviewRow
                spacing: Theme.paddingSmall
                
                Repeater {
                    model: selectedImages
                    delegate: Item {
                        width: Theme.itemSizeSmall * 1.5
                        height: Theme.itemSizeSmall * 1.5
                        
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.3)
                            radius: Theme.paddingSmall
                            border.color: Theme.highlightColor
                            border.width: 1
                            
                            Image {
                                id: previewImage
                                anchors.fill: parent
                                anchors.margins: Theme.paddingSmall
                                source: modelData.toString().indexOf("file://") === 0 ? modelData : "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                clip: true
                                
                                // Debug info
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        DebugLogger.logError("ChatPage", "Failed to load image: " + source);
                                    } else if (status === Image.Ready) {
                                        DebugLogger.logInfo("ChatPage", "Successfully loaded image: " + source);
                                    }
                                }
                            }
                            
                            // Fallback text for failed images
                            Label {
                                visible: previewImage.status === Image.Error
                                anchors.centerIn: parent
                                text: "Image\nPreview"
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            // Remove button
                            IconButton {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.paddingSmall / 2
                                icon.source: "image://theme/icon-s-clear"
                                icon.color: Theme.errorColor
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                onClicked: {
                                    var newImages = [];
                                    for (var i = 0; i < selectedImages.length; i++) {
                                        if (i !== index) {
                                            newImages.push(selectedImages[i]);
                                        }
                                    }
                                    selectedImages = newImages;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Button row above text input


        // Text input area
        TextArea {
            id: textField
            width: parent.width
            placeholderText: hasImages ? "Add a message to your images..." : "Type a message..."
            
            // Ensure the text area can receive focus and input
            focus: true
            enabled: true
            
            // Send on Enter (without Shift)
            onFocusChanged: {
                if (focus) {
                    cursorPosition = text.length;
                }
            }
            
            // Handle Enter key
            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!(event.modifiers & Qt.ShiftModifier)) {
                        // Enter without Shift - send message
                        if (!isGenerating && (textField.text.trim() !== "" || hasImages)) {
                            sendButton.clicked();
                        }
                        event.accepted = true;
                    }
                    // Enter with Shift - new line (default behavior)
                }
            }
        }

        // Button row with proper layout
        Row {
            id: buttonRow
            width: parent.width
            
            // Left side buttons
            Row {
                id: leftButtons
                spacing: Theme.paddingSmall
                
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
                    id: modelButton
                    icon.source: "image://theme/icon-s-setting"
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
            
            // Spacer to push right buttons to the right
            Item {
                width: parent.width - leftButtons.width - rightButtons.width
                height: 1
            }
            
            // Right side buttons
            Row {
                id: rightButtons
                spacing: Theme.paddingSmall
                
                IconButton {
                    id: attachButton
                    icon.source: "image://theme/icon-s-attach"
                    onClicked: {
                        // Open image picker
                        var picker = pageStack.push("Sailfish.Pickers.ImagePickerPage");
                        picker.selectedContentChanged.connect(function() {
                            if (picker.selectedContent) {
                                var newImages = selectedImages.slice(); // Copy existing images
                                newImages.push(picker.selectedContent);
                                selectedImages = newImages;
                                DebugLogger.logInfo("ChatPage", "Added image: " + picker.selectedContent);
                            }
                        });
                    }
                }
                
                IconButton {
                    id: sendButton
                    icon.source: isGenerating ? "image://theme/icon-s-sync" : "image://theme/icon-s-message"
                    enabled: !isGenerating
                    onClicked: {
                        var message = textField.text
                        var hasText = message.trim() !== "";

                        if ((hasText || hasImages) && !isGenerating) {
                            // Create message content with text and images
                            var messageContent = message;
                            var images = selectedImages.slice(); // Copy for this message

                            // For display purposes, show both text and image info
                            if (hasImages) {
                                messageContent = message + (hasText ? "\n" : "") + "[" + selectedImages.length + " image(s) attached]";
                            }

                            chatModel.append({
                                role: "user",
                                message: messageContent,
                                timestamp: Date.now(),
                                conversation_id: currentConversationId,
                                images: images
                            });
                            DebugLogger.logVerbose("ChatPage", "Added user message to UI with " + selectedImages.length + " images, total count: " + chatModel.count);

                            // Save to database (images will be stored as JSON if needed later)
                            saveMessage("user", messageContent); // User messages don't need provider/model info

                            // Auto-generate conversation title from first user message
                            autoGenerateConversationTitle(message);

                            // Generate response with multimodal support
                            generateResponseWithImages(message, images);

                            // Clear input
                            textField.text = "";
                            selectedImages = [];
                        }
                    }
                }
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
