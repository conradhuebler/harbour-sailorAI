import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger
import "../js/DatabaseQueries.js" as DatabaseQueries
import "../js/MarkdownRenderer.js" as Markdown

Page {
    id: page

    // Claude Generated: allow the chat to rotate into landscape so wide tables/code can use
    // the full screen width.
    allowedOrientations: Orientation.All

    // Properties passed from ConversationListPage
    property int conversationId: -1
    property string conversationName: "Chat"

    // Initial state for photo actions (set by cover or in-app camera actions)
    property string initialPrompt: ""
    property var initialImages: []

    ListModel {
        id: chatModel
    }

    property int currentConversationId: conversationId
    property string selectedAliasId: ""
    property string selectedModel: "gemini-1.5-flash"
    property bool currentModelSupportsVision: true

    // Claude Generated: landscape detection for layout tweaks (e.g. wider chat bubbles).
    property bool landscapeMode: width > height

    function updateVisionCapability() {
        // Don't hide button during transient empty states while loading
        if (!selectedAliasId) return;
        var alias = LLMApi.getProviderAlias(selectedAliasId);
        if (!alias) return;
        // Cloud providers, or a model the user manually tagged as vision-capable → synchronous yes
        if (alias.type !== "ollama" || LLMApi.isAliasVisionModelTagged(selectedAliasId, selectedModel)) {
            currentModelSupportsVision = true;
            return;
        }
        if (!selectedModel) return;
        currentModelSupportsVision = true; // optimistic while /api/show is in flight
        var snapAlias = selectedAliasId;
        var snapModel = selectedModel;
        LLMApi.checkOllamaModelVision(snapAlias, snapModel, function(hasVision) {
            // Discard stale callbacks from a previous model selection
            if (selectedAliasId !== snapAlias || selectedModel !== snapModel) return;
            // A manual tag overrides a negative auto-detection
            currentModelSupportsVision = hasVision || LLMApi.isAliasVisionModelTagged(snapAlias, snapModel);
            if (!currentModelSupportsVision) selectedImages = [];
        });
    }

    // Claude Generated: translate the canonical fallback conversation names used internally
    // ("Chat", "New Conversation", "Conversation N") into the current UI language for display.
    function displayConversationName(name) {
        if (!name) return qsTr("Chat")
        if (name === "Chat") return qsTr("Chat")
        if (name === "New Conversation") return qsTr("New Conversation")
        var m = name.match(/^Conversation (\d+)$/)
        if (m) return qsTr("Conversation %1").arg(parseInt(m[1], 10))
        if (name === "Describe photo") return qsTr("Describe photo")
        if (name === "Translate photo") return qsTr("Translate photo")
        return name
    }

    // Claude Generated: Push camera page; on capture return to this chat and attach the photo.
    function openCameraAction(prompt) {
        var camPage = pageStack.push(Qt.resolvedUrl("CameraCapturePage.qml"))
        if (camPage) {
            camPage.photoCaptured.connect(function(path) {
                pageStack.pop(page)
                _addPickedImage(path)
                if (prompt) textField.text = prompt
            })
        }
    }

    // Claude Generated: Image picker helpers — gallery grid and file-manager browsing.
    function _addPickedImage(content) {
        if (!content) return
        var newImages = selectedImages.slice()
        newImages.push(content)
        selectedImages = newImages
        DebugLogger.logInfo("ChatPage", "Added image: " + content)
    }

    function pickFromGallery() {
        var picker = pageStack.push("Sailfish.Pickers.ImagePickerPage")
        picker.selectedContentChanged.connect(function() {
            if (picker.selectedContent) _addPickedImage(picker.selectedContent)
        })
    }

    function pickFromFiles() {
        var picker = pageStack.push("Sailfish.Pickers.FilePickerPage", {
            "title": qsTr("Select image"),
            "nameFilters": [ "*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp" ]
        })
        picker.selectedContentPropertiesChanged.connect(function() {
            var props = picker.selectedContentProperties
            if (props && props.filePath) _addPickedImage(props.filePath)
        })
    }

    // Claude Generated: Pick a text or document file and append its content to the input field.
    function pickTextDocument() {
        var picker = pageStack.push("Sailfish.Pickers.FilePickerPage", {
            "title": qsTr("Select document"),
            "nameFilters": [ "*.txt", "*.md", "*.csv", "*.json", "*.xml",
                             "*.yaml", "*.yml", "*.log", "*.py", "*.js",
                             "*.cpp", "*.h", "*.qml", "*.html", "*.css" ]
        })
        picker.selectedContentPropertiesChanged.connect(function() {
            var props = picker.selectedContentProperties
            if (!props || !props.filePath) return
            _readTextFile(props.filePath)
        })
    }

    function _readTextFile(filePath) {
        var cleanPath = filePath.toString()
        if (cleanPath.indexOf("file://") !== 0) cleanPath = "file://" + cleanPath
        var xhr = new XMLHttpRequest()
        xhr.open("GET", cleanPath, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                var content = xhr.responseText
                if (content.length > 32000) {
                    // Hard limit: truncate very large files with a notice
                    content = content.substring(0, 32000) + "\n\n[... " + qsTr("file truncated at 32000 chars") + "]"
                }
                var existing = textField.text
                textField.text = existing ? existing + "\n\n" + content : content
            } else {
                DebugLogger.logError("ChatPage", "Failed to read file: " + filePath + " HTTP " + xhr.status)
            }
        }
        xhr.send()
    }

    onSelectedModelChanged: updateVisionCapability()
    onSelectedAliasIdChanged: updateVisionCapability()
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

    // Claude Generated: Lets the user choose where to pick an image from — the gallery grid or the
    // file manager (filesystem browser). Pops back to the chat (Immediate) before opening the picker
    // so there is no chooser page left underneath it.
    Component {
        id: imageSourceChooser
        Page {
            id: chooserPage
            Column {
                width: parent.width

                PageHeader { title: qsTr("Add image") }

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeLarge
                    onClicked: {
                        pageStack.pop(page, PageStackAction.Immediate)
                        page.pickFromGallery()
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.horizontalPageMargin
                        spacing: Theme.paddingLarge
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-image"
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("From gallery")
                        }
                    }
                }

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeLarge
                    onClicked: {
                        pageStack.pop(page, PageStackAction.Immediate)
                        page.pickFromFiles()
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.horizontalPageMargin
                        spacing: Theme.paddingLarge
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-folder"
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("From files")
                        }
                    }
                }
            }
        }
    }

    // Canvas for resizing large images before sending to API.
    // Must use requestPaint() → onPaint cycle: toDataURL() only works after onPaint.
    Canvas {
        id: imageResizeCanvas
        width: 1
        height: 1
        visible: false

        property var pendingCallback: null
        property string pendingSource: ""
        property bool imageReady: false

        onImageLoaded: {
            imageReady = true;
            requestPaint();
        }

        onPaint: {
            if (!imageReady || !pendingSource || !pendingCallback) return;
            var ctx = getContext('2d');
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(pendingSource, 0, 0, width, height);
            var dataUrl = toDataURL('image/jpeg', 0.7);
            var b64Data = dataUrl.substring(dataUrl.indexOf(',') + 1);
            DebugLogger.logInfo("ChatPage", "Resized image to " + width + "x" + height + " (" + b64Data.length + " chars)");
            var cb = pendingCallback;
            var src = pendingSource;
            pendingCallback = null;
            pendingSource = "";
            imageReady = false;
            unloadImage(src);
            if (b64Data.length < 100) {
                DebugLogger.logError("ChatPage", "Resize produced tiny output, falling back to original");
                cb(null);
            } else {
                cb({ data: b64Data, mimeType: "image/jpeg" });
            }
        }
    }

    // Resize a large image using QML Canvas.
    // Dimensions are set before loadImage() so the canvas is the right size when onPaint fires.
    function resizeImageFile(imageUrl, maxWidth, maxHeight, callback) {
        var tmpImg = Qt.createQmlObject('import QtQuick 2.0; Image { source: "' + imageUrl + '"; cache: false }', page);
        function proceed() {
            var origW = tmpImg.implicitWidth;
            var origH = tmpImg.implicitHeight;
            tmpImg.destroy();
            if (origW <= 0 || origH <= 0) {
                DebugLogger.logError("ChatPage", "Image has zero dimensions, skipping resize");
                callback(null);
                return;
            }
            var scale = Math.min(maxWidth / origW, maxHeight / origH, 1.0);
            var w = Math.round(origW * scale);
            var h = Math.round(origH * scale);
            DebugLogger.logInfo("ChatPage", "Resizing image from " + origW + "x" + origH + " to " + w + "x" + h);
            imageResizeCanvas.pendingCallback = callback;
            imageResizeCanvas.pendingSource = imageUrl;
            imageResizeCanvas.imageReady = false;
            // Set dimensions first, then load — onPaint from dimension change is ignored (imageReady=false)
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

    // Threshold: base64 chars above this triggers canvas resize
    property int maxImageBase64Size: imageMaxDimension.value > 0 ? imageMaxDimension.value * imageMaxDimension.value * 2 : 4000000

    // Provider aliases configuration - Claude Generated: reload aliases live when they change
    ConfigurationValue {
        id: providerAliasesConfig
        key: "/SailorAI/provider_aliases"
        defaultValue: ""
        onValueChanged: {
            if (value) {
                try {
                    LLMApi.loadProviderAliases(value);
                    loadAliases();
                    DebugLogger.logInfo("ChatPage", "Provider aliases reloaded from config change");
                } catch (e) {
                    DebugLogger.logError("ChatPage", "Failed to reload provider aliases: " + e.toString());
                }
            }
        }
    }

    // Also reload aliases when the page becomes active again (user returned from SettingsPage) - Claude Generated
    onStatusChanged: {
        if (status === PageStatus.Active) {
            if (providerAliasesConfig.value) {
                try {
                    LLMApi.loadProviderAliases(providerAliasesConfig.value);
                    loadAliases();
                } catch (e) {
                    DebugLogger.logError("ChatPage", "Failed to reload aliases on activation: " + e.toString());
                }
            }
        }
    }

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

    // Claude Generated: general default model for new chats (any provider)
    ConfigurationValue {
        id: defaultProviderAliasConfig
        key: "/SailorAI/default_provider_alias"
        defaultValue: ""
    }

    ConfigurationValue {
        id: defaultModelConfig
        key: "/SailorAI/default_model"
        defaultValue: ""
    }

    ConfigurationValue {
        id: imageMaxDimension
        key: "/SailorAI/image_max_dimension"
        defaultValue: 1280
    }

    // Claude Generated: photo-action behaviour and dedicated vision model (set in SettingsPage)
    ConfigurationValue {
        id: photoActionAutoSendConfig
        key: "/SailorAI/photo_action_auto_send"
        defaultValue: true
    }

    ConfigurationValue {
        id: visionProviderAliasConfig
        key: "/SailorAI/vision_provider_alias"
        defaultValue: ""
    }

    ConfigurationValue {
        id: visionModelConfig
        key: "/SailorAI/vision_model"
        defaultValue: ""
    }

    // Claude Generated: per-session web search toggle for Ollama providers
    ConfigurationValue {
        id: webSearchEnabledConfig
        key: "/SailorAI/web_search_enabled"
        defaultValue: true
    }
    property bool webSearchEnabled: webSearchEnabledConfig.value === true || webSearchEnabledConfig.value === "true"

    // Claude Generated: global default for Markdown rendering. A per-session override lets
    // the user switch raw/plain view without changing the default.
    ConfigurationValue {
        id: markdownRenderingEnabledConfig
        key: "/SailorAI/markdown_rendering_enabled"
        defaultValue: true
    }
    property bool markdownRenderingDefault: markdownRenderingEnabledConfig.value === true || markdownRenderingEnabledConfig.value === "true"
    property var sessionMarkdownEnabled: null

    // True when this chat page should render Markdown. Uses the session override if the user
    // toggled it, otherwise the global default. Claude Generated
    property bool markdownRenderingEnabled: {
        if (sessionMarkdownEnabled !== null) return sessionMarkdownEnabled;
        return markdownRenderingDefault;
    }

    // Claude Generated: max number of Ollama web-tool iterations before a final answer is forced
    ConfigurationValue {
        id: maxToolIterConfig
        key: "/SailorAI/max_tool_iter"
        defaultValue: 8
    }

    // Claude Generated: opt-in deterministic auto web_fetch of URLs found in the user's message
    ConfigurationValue {
        id: autoWebFetchConfig
        key: "/SailorAI/auto_web_fetch"
        defaultValue: false
    }
    property bool autoWebFetch: autoWebFetchConfig.value === true || autoWebFetchConfig.value === "true"

    // Claude Generated: make the model answer in the device language (default on)
    ConfigurationValue {
        id: respondInSystemLanguageConfig
        key: "/SailorAI/respond_in_system_language"
        defaultValue: true
    }
    property bool respondInSystemLanguage: respondInSystemLanguageConfig.value === true || respondInSystemLanguageConfig.value === "true"

    // System prompt instructing the model to reply in the device language; "" when disabled. Claude Generated
    function languageSystemPrompt() {
        if (!respondInSystemLanguage) return "";
        return qsTr("Always answer in %1, regardless of the language the question is written in.")
                 .arg(Qt.locale().nativeLanguageName);
    }

    // Claude Generated: formatting rules that the model must follow so that the
    // renderer can detect and collapse web-tool sources correctly.
    function formattingSystemPrompt() {
        return "When you include sources collected by web tools, emit them as a single final \"Sources\" block formatted exactly like this:\n\n" +
               "Sources:\n" +
               "1. Page Title — https://example.com\n" +
               "2. Another Title — https://example.org\n\n" +
               "Use the em-dash (—) between title and URL, number each source starting at 1, " +
               "keep the header as the literal word \"Sources:\", and emit this block only once. " +
               "Use this exact English header even when the rest of the answer is in another language.";
    }

    // Claude Generated: combine language and formatting instructions for the model.
    function buildSystemPrompt() {
        var parts = [];
        var lang = languageSystemPrompt();
        if (lang) parts.push(lang);
        parts.push(formattingSystemPrompt());
        return parts.join("\n\n");
    }

    // Localized labels handed to the JS tool loop (which has no qsTr) - Claude Generated
    function webToolLabels() {
        return {
            searching: qsTr("🔍 Searching: %1"),
            reading: qsTr("📄 Reading: %1"),
            sourcesHeader: qsTr("Sources"),
            sourcesSummary: qsTr("📚 Sources (%1)"),
            sourcesTitle: qsTr("Sources"),
            toolLogSummary: qsTr("🔍 Web-Tools used (%1 calls)"),
            toolLogTitle: qsTr("Web-Tools log")
        };
    }

    // True iff the currently selected alias is Ollama with at least one web tool enabled - Claude Generated
    property bool currentAliasSupportsWebTools: {
        if (!selectedAliasId) return false;
        var alias = LLMApi.getProviderAlias(selectedAliasId);
        if (!alias) return false;
        if (alias.type !== "ollama") return false;
        return (alias.enableWebSearch || alias.enableWebFetch);
    }

    // True iff the selected alias is Ollama with web_fetch enabled (gates the auto-fetch toggle) - Claude Generated
    property bool currentAliasSupportsWebFetch: {
        if (!selectedAliasId) return false;
        var alias = LLMApi.getProviderAlias(selectedAliasId);
        return !!(alias && alias.type === "ollama" && alias.enableWebFetch);
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
        // Run with final alias+model values after both are restored
        updateVisionCapability();
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
            // New chats always start from the configured general default model (any
            // provider); existing chats restore the last used selection. - Claude Generated
            if (currentConversationId <= 0 && defaultProviderAliasConfig.value &&
                    availableAliases.indexOf(defaultProviderAliasConfig.value) !== -1) {
                selectedAliasId = defaultProviderAliasConfig.value;
                selectedModel = defaultModelConfig.value || "";
                DebugLogger.logInfo("ChatPage", "New chat using default model: " + selectedAliasId + " / " + selectedModel);
            } else {
                restoreLastSelection();
            }

            // If still no valid selection, use first available
            if (!selectedAliasId || availableAliases.indexOf(selectedAliasId) === -1) {
                selectedAliasId = availableAliases[0];
                DebugLogger.logInfo("ChatPage", "Selected default alias: " + selectedAliasId);
            }
            loadModels();
        }
    }

    function sortModelsByFavorites(models, aliasId) {
        var favorites = LLMApi.getAliasFavoriteModels(aliasId) || [];
        var list = (models || []).slice();

        // When nothing has been fetched/cached yet, surface the favorites so they
        // stay selectable. Once a real (non-empty) list exists it is authoritative:
        // a favorite missing from it was removed on the server and must NOT be
        // re-injected here (see reconcileFavorites). - Claude Generated
        if (list.length === 0) {
            list = favorites.slice();
        }

        var favoriteModels = [];
        var otherModels = [];

        // Separate favorites from non-favorites
        for (var i = 0; i < list.length; i++) {
            if (favorites.indexOf(list[i]) !== -1) {
                favoriteModels.push(list[i]);
            } else {
                otherModels.push(list[i]);
            }
        }

        // Sort favorites by their order in the favorites list
        favoriteModels.sort(function(a, b) {
            return favorites.indexOf(a) - favorites.indexOf(b);
        });
        otherModels.sort();

        // Return favorites first, then other models
        return favoriteModels.concat(otherModels);
    }

    function loadModels() {
        if (selectedAliasId) {
            var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
            var cachedModels = LLMApi.getAliasModels(selectedAliasId);
            // A non-empty cache is a real fetched list and therefore authoritative:
            // a selection/favorite missing from it was removed on the server. An empty
            // cache means "not fetched yet" - keep the current selection. - Claude Generated
            var haveAuthoritative = cachedModels.length > 0;

            // Sort models with favorites first (favorites surfaced when no cache yet)
            availableModels = sortModelsByFavorites(cachedModels, selectedAliasId);

            DebugLogger.logInfo("ChatPage", "Loading models for " + selectedAliasId + " - Available: " + availableModels.length + ", Favorite: " + (favoriteModel || "none") + ", authoritative: " + haveAuthoritative);

            if (haveAuthoritative) {
                // Real list: keep current if still present, else favorite, else first.
                if (selectedModel && availableModels.indexOf(selectedModel) !== -1) {
                    DebugLogger.logInfo("ChatPage", "Keeping current model selection: " + selectedModel);
                } else if (favoriteModel && availableModels.indexOf(favoriteModel) !== -1) {
                    selectedModel = favoriteModel;
                    DebugLogger.logInfo("ChatPage", "Selected provider's favorite model: " + selectedModel);
                } else if (availableModels.length > 0) {
                    selectedModel = availableModels[0];
                    DebugLogger.logInfo("ChatPage", "Selected first available model: " + selectedModel + " (previous selection not on server)");
                }
            } else {
                // Not fetched yet: preserve the current selection (default/last); only
                // seed from favorite when nothing is selected, then fetch in background.
                if (!selectedModel && favoriteModel) {
                    selectedModel = favoriteModel;
                    DebugLogger.logInfo("ChatPage", "Using favorite as initial selection: " + selectedModel);
                }
                var alias = LLMApi.getProviderAlias(selectedAliasId);
                if (alias && alias.api_key) {
                    DebugLogger.logInfo("ChatPage", "No models cached, fetching from API for: " + selectedAliasId);
                    LLMApi.fetchModelsForAlias(selectedAliasId);
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

    function saveMessage(role, message, providerAlias, modelName, images) {
        // Lazy conversation creation: new chats start with conversationId=0
        if (currentConversationId <= 0) {
            currentConversationId = app.database.createConversation(conversationName || "New Conversation");
            if (currentConversationId <= 0) {
                DebugLogger.logError("ChatPage", "Cannot create conversation for first message");
                return;
            }
            DebugLogger.logInfo("ChatPage", "Created conversation lazily: " + currentConversationId);
        }

        // Use current selection if not provided
        var provider = providerAlias || (role === "bot" ? selectedAliasId : null);
        var model = modelName || (role === "bot" ? selectedModel : null);

        if (app.database.saveMessage(currentConversationId, role, message, provider, model, images)) {
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
        
        var isLocalhostOllama = alias.url && alias.url.indexOf("localhost:11434") !== -1;
        if (!alias.api_key && !isLocalhostOllama) {
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
        
        // Web search toggle: when the user disables it, override the alias's tool flags
        // for this call only. Claude Generated
        var aliasForOverride = LLMApi.getProviderAlias(selectedAliasId);
        var canOverride = aliasForOverride && aliasForOverride.type === "ollama"
                          && (aliasForOverride.enableWebSearch || aliasForOverride.enableWebFetch);
        var doCall = function() {
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
            } : null,
            // Options: web-tool log/source labels, iteration cap, opt-in auto web_fetch,
            // and the system-language instruction. Claude Generated
            { toolLabels: webToolLabels(), maxToolIterations: maxToolIterConfig.value,
              autoFetchUrls: autoWebFetch, systemPrompt: buildSystemPrompt() }
        );
        }; if (canOverride) LLMApi.withTemporaryWebToolOverride(selectedAliasId, webSearchEnabled, webSearchEnabled, doCall); else doCall();
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

            var isLocalhostOllama2 = alias.url && alias.url.indexOf("localhost:11434") !== -1;
            if (!alias.api_key && !isLocalhostOllama2) {
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
                    // Web tool override: when the user disabled web search, suppress the
                    // tool loop for this call only. Claude Generated
                    var canOverrideImgs = (alias.type === "ollama")
                                           && (alias.enableWebSearch || alias.enableWebFetch);
                    var doCallImgs = function() {
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
                        },
                        // System-language instruction for multimodal chats too. Claude Generated
                        { systemPrompt: buildSystemPrompt() }
                    );
                    };
                    if (canOverrideImgs) {
                        LLMApi.withTemporaryWebToolOverride(selectedAliasId, webSearchEnabled, webSearchEnabled, doCallImgs);
                    } else {
                        doCallImgs();
                    }
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
                                resizeImageFile(fileUrl, imageMaxDimension.value, imageMaxDimension.value, function(resized) {
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
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Advanced LLM Parameters")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("../dialogs/AdvancedSettingsDialog.qml"), {
                        "temperature": 0.7,
                        "seed": -1
                    })
                }
            }
            MenuItem {
                text: qsTr("Provider") + ": " + getProviderDisplayName()
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": selectedAliasId,
                        "selectedModel": selectedModel
                    })
                    dialog.accepted.connect(function() {
                        selectedAliasId = dialog.selectedAliasId
                        selectedModel = dialog.selectedModel
                        saveCurrentSelection()
                        loadModels()
                    })
                }
            }
            MenuItem {
                text: qsTr("Back to Conversations")
                onClicked: pageStack.pop()
            }
            MenuItem {
                text: qsTr("Export chat")
                onClicked: {
                    var displayName = conversationName && conversationName !== "Chat"
                                      ? conversationName
                                      : qsTr("Conversation %1").arg(currentConversationId)
                    pageStack.push(Qt.resolvedUrl("../dialogs/ExportDialog.qml"), {
                        "conversationId": currentConversationId,
                        "conversationName": displayName
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
                title: displayConversationName(conversationName)
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
                    property var itemImages: {
                        // ListModel can't reliably round-trip JS arrays in Qt5 — store as JSON string
                        if (!model || !model.images_json) return []
                        try { return JSON.parse(model.images_json) } catch(e) { return [] }
                    }
                    
                    Item {
                        id: messageContent
                        width: parent.width
                        height: messageBubble.height
                        
                        Rectangle {
                            id: messageBubble
                            width: {
                                var textW = messageText.implicitWidth + 2 * Theme.paddingMedium
                                var imgW = messageItem.itemImages.length > 0
                                    ? (Theme.itemSizeLarge * 2 + 2 * Theme.paddingMedium + 2 * Theme.paddingSmall)
                                    : 0
                                // Claude Generated: use more horizontal space in landscape so
                                // wide tables and code blocks remain readable.
                                var maxRatio = page.landscapeMode ? 0.95 : 0.85
                                return Math.min(Math.max(textW, imgW), parent.width * maxRatio)
                            }
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

                                // Claude Generated: detect tables so they can be collapsed in the
                                // chat bubble and opened in a dedicated dialog instead.
                                property bool hasTables: {
                                    var msg = model ? model.message : ""
                                    return msg ? Markdown.hasTable(msg) : false
                                }

                                Label {
                                    id: messageText
                                    width: parent.width
                                    // Render Markdown (bold/italic/code/lists/tables/links) as RichText;
                                    // error messages stay plain text. Claude Generated
                                    textFormat: (messageItem.isErrorMessage || !markdownRenderingEnabled)
                                                ? Text.PlainText : Text.RichText
                                    text: (messageItem.isErrorMessage || !markdownRenderingEnabled)
                                          ? (model ? model.message : "")
                                          : (messageColumn.hasTables
                                              ? Markdown.toRichTextCollapsed(model ? model.message : "", { toolLabels: webToolLabels() })
                                              : Markdown.toRichText(model ? model.message : "", { toolLabels: webToolLabels() }))
                                    wrapMode: Text.WordWrap
                                    color: {
                                        if (messageItem.isOwnMessage) return Theme.highlightColor
                                        if (messageItem.isErrorMessage) return "white"
                                        return Theme.primaryColor
                                    }
                                    linkColor: Theme.highlightColor
                                    onLinkActivated: {
                                        if (link.indexOf("http://") === 0 || link.indexOf("https://") === 0) {
                                            Qt.openUrlExternally(link)
                                        } else if (link.indexOf("sailorai:table:") === 0) {
                                            var idx = parseInt(link.substring("sailorai:table:".length), 10)
                                            var tables = Markdown.extractTables(model ? model.message : "")
                                            if (idx >= 0 && idx < tables.length) {
                                                pageStack.push(Qt.resolvedUrl("../dialogs/TableViewDialog.qml"), {
                                                    "tableHtml": tables[idx],
                                                    "originalMessage": model ? model.message : "",
                                                    "tableIndex": idx
                                                })
                                            }
                                        } else if (link.indexOf("sailorai:toollog:") === 0) {
                                            var toolCalls = Markdown.extractToolLog(model ? model.message : "", webToolLabels())
                                            if (toolCalls.length > 0) {
                                                pageStack.push(Qt.resolvedUrl("../dialogs/ToolLogDialog.qml"), {
                                                    "toolCalls": toolCalls,
                                                    "title": webToolLabels().toolLogTitle
                                                })
                                            }
                                        } else if (link.indexOf("sailorai:sources:") === 0) {
                                            var srcList = Markdown.extractSources(model ? model.message : "", webToolLabels())
                                            if (srcList && srcList.length > 0) {
                                                pageStack.push(Qt.resolvedUrl("../dialogs/SourcesDialog.qml"), {
                                                    "sources": srcList,
                                                    "title": webToolLabels().sourcesTitle
                                                })
                                            }
                                        }
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                // Images attached to this message (shown for whichever message carries them)
                                Flow {
                                    visible: messageItem.itemImages.length > 0
                                    width: visible ? parent.width : 0
                                    height: visible ? implicitHeight : 0
                                    spacing: Theme.paddingSmall

                                    Repeater {
                                        // Use integer count as model to avoid modelData scope issues in Qt5
                                        model: messageItem.itemImages.length

                                        Item {
                                            id: chatImageItem
                                            width: Theme.itemSizeLarge * 2
                                            height: Theme.itemSizeLarge * 2
                                            property string imgUrl: ""

                                            Component.onCompleted: {
                                                var imgs = messageItem.itemImages
                                                if (imgs && index < imgs.length) {
                                                    var s = imgs[index].toString()
                                                    imgUrl = s.indexOf("file://") === 0 ? s : "file://" + s
                                                }
                                            }

                                            Image {
                                                id: chatThumb
                                                anchors.fill: parent
                                                source: chatImageItem.imgUrl
                                                fillMode: Image.PreserveAspectCrop
                                                clip: true
                                                smooth: true
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }

                                            // Placeholder while loading or when file is gone
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                                                radius: Theme.paddingSmall
                                                visible: chatThumb.status !== Image.Ready

                                                Image {
                                                    anchors.centerIn: parent
                                                    source: "image://theme/icon-m-image"
                                                    opacity: chatThumb.status === Image.Error ? 0.4 : 0.15
                                                    width: Theme.iconSizeMedium
                                                    height: Theme.iconSizeMedium
                                                }
                                            }
                                        }
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
                            text: qsTr("Retry")
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
        text: qsTr("AI is thinking...")
        anchors.bottom: messageInputContainer.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.paddingSmall
        color: Theme.secondaryColor
        opacity: 0.8
    }
    
    Label {
        visible: isGenerating && streamingMessageIndex >= 0
        text: qsTr("AI is responding...")
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
                                text: qsTr("Image\nPreview")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            // Remove button
                            IconButton {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.paddingSmall / 2
                                icon.source: "image://theme/icon-m-clear"
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
            placeholderText: hasImages ? qsTr("Add a message to your images...") : qsTr("Type a message...")
            
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
                    id: documentButton
                    icon.source: "image://theme/icon-m-document"
                    onClicked: pickTextDocument()
                }

                IconButton {
                    id: attachButton
                    visible: currentModelSupportsVision
                    icon.source: "image://theme/icon-m-image"
                    onClicked: pageStack.push(imageSourceChooser)
                }

                // Per-session web search toggle (only for Ollama aliases with web tools enabled).
                // Toggling writes the config value; the webSearchEnabled binding recomputes from it,
                // and generateResponse() applies it via withTemporaryWebToolOverride. - Claude Generated
                IconButton {
                    id: webSearchButton
                    visible: currentAliasSupportsWebTools
                    enabled: currentAliasSupportsWebTools
                    icon.source: "image://theme/icon-m-search"
                    opacity: webSearchEnabled ? 1.0 : 0.4
                    onClicked: webSearchEnabledConfig.value = !webSearchEnabled
                }

                // Opt-in auto web_fetch toggle: when on, URLs in the user's message are fetched
                // automatically before the model runs (off by default). - Claude Generated
                IconButton {
                    id: autoFetchButton
                    visible: currentAliasSupportsWebFetch
                    enabled: currentAliasSupportsWebFetch
                    icon.source: "image://theme/icon-m-link"
                    opacity: autoWebFetch ? 1.0 : 0.4
                    onClicked: autoWebFetchConfig.value = !autoWebFetch
                }

                // Claude Generated: per-session Markdown rendering toggle. The session override
                // is independent of the global default stored in markdownRenderingEnabledConfig.
                IconButton {
                    id: markdownToggleButton
                    icon.source: "image://theme/icon-m-edit"
                    opacity: markdownRenderingEnabled ? 1.0 : 0.4
                    onClicked: {
                        sessionMarkdownEnabled = !markdownRenderingEnabled
                        DebugLogger.logInfo("ChatPage", "Markdown rendering session override: " + sessionMarkdownEnabled)
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
                    id: sendButton
                    icon.source: isGenerating ? "image://theme/icon-s-sync" : "image://theme/icon-s-message"
                    enabled: !isGenerating
                    onClicked: {
                        var message = textField.text
                        var hasText = message.trim() !== "";

                        if ((hasText || hasImages) && !isGenerating) {
                            // Create message content with text and images
                            var messageContent = message;
                            var images = selectedImages.map(function(p) { return p.toString(); });

                            chatModel.append({
                                role: "user",
                                message: messageContent,
                                timestamp: Date.now(),
                                conversation_id: currentConversationId,
                                images_json: JSON.stringify(images)
                            });
                            DebugLogger.logVerbose("ChatPage", "Added user message to UI with " + selectedImages.length + " images, total count: " + chatModel.count);

                            saveMessage("user", messageContent, null, null, images);

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

        // Claude Generated: ensure aliases are loaded from config before selecting one
        if (providerAliasesConfig.value) {
            try {
                LLMApi.loadProviderAliases(providerAliasesConfig.value);
            } catch (e) {
                DebugLogger.logError("ChatPage", "Failed to load provider aliases on init: " + e.toString());
            }
        }

        loadAliases();

        if (currentConversationId > 0) {
            loadChat(currentConversationId);
        }

        // Apply photo action pre-fill (cover, share, or in-app camera actions)
        if (currentConversationId <= 0 && initialImages.length > 0) {
            // Prefer the dedicated vision provider/model if configured and still available
            if (visionProviderAliasConfig.value && visionModelConfig.value &&
                    availableAliases.indexOf(visionProviderAliasConfig.value) !== -1) {
                selectedAliasId = visionProviderAliasConfig.value
                loadModels()
                selectedModel = visionModelConfig.value
                DebugLogger.logInfo("ChatPage", "Photo action using vision default: " + selectedAliasId + " / " + selectedModel)
            }
            selectedImages = initialImages
        }
        if (currentConversationId <= 0 && initialPrompt.length > 0) {
            textField.text = initialPrompt
        }

        // Auto-send photo actions only when enabled and the active model can do vision;
        // otherwise leave it pre-filled so the user can pick a model and send manually.
        if (currentConversationId <= 0 && initialPrompt.length > 0 && initialImages.length > 0) {
            var autoSend = (photoActionAutoSendConfig.value === true || photoActionAutoSendConfig.value === "true")
            if (autoSend && currentModelSupportsVision) {
                sendButton.clicked()
            } else if (autoSend && !currentModelSupportsVision) {
                DebugLogger.logInfo("ChatPage", "Auto-send skipped: selected model is not vision-capable")
            }
        }
    }
}
