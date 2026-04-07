import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.3

Page {
    id: chatPage
    title: qsTr("Chat")

    property var api: null
    property string selectedAliasId: ""
    property string selectedModel: ""
    property bool isGenerating: false
    property string streamingContent: ""
    property var selectedImages: []
    property bool hasImages: selectedImages.length > 0

    // Refresh both combo boxes whenever the page becomes active or api changes
    function refreshAll() {
        refreshAliasList();
        refreshModelList();
    }

    function refreshAliasList() {
        if (!api) return;
        aliasModel.clear();
        var ids = api.getAliasIds();
        for (var i = 0; i < ids.length; i++) {
            var alias = api.getAlias(ids[i]);
            aliasModel.append({
                "aliasId": ids[i],
                "aliasName": alias ? alias.name : ids[i]
            });
        }
        // Re-select if previous selection still exists
        if (selectedAliasId && api.getAlias(selectedAliasId)) {
            for (var j = 0; j < aliasModel.count; j++) {
                if (aliasModel.get(j).aliasId === selectedAliasId) {
                    aliasCombo.currentIndex = j;
                    break;
                }
            }
        } else {
            selectedAliasId = "";
            selectedModel = "";
            modelModel.clear();
        }
    }

    function refreshModelList() {
        modelModel.clear();
        if (!api || !selectedAliasId) return;

        // Try cached models first
        var cached = api.getAliasModels(selectedAliasId);
        if (cached.length > 0) {
            for (var i = 0; i < cached.length; i++) {
                modelModel.append({"modelName": cached[i]});
            }
        } else {
            // Fall back to provider defaultModels
            var alias = api.getAlias(selectedAliasId);
            if (alias) {
                var provider = api.getProvider(alias.type);
                if (provider && provider.defaultModels) {
                    for (var i = 0; i < provider.defaultModels.length; i++) {
                        modelModel.append({"modelName": provider.defaultModels[i]});
                    }
                }
            }
        }

        // Re-select if previous model still exists
        if (selectedModel) {
            for (var k = 0; k < modelModel.count; k++) {
                if (modelModel.get(k).modelName === selectedModel) {
                    modelCombo.currentIndex = k;
                    return;
                }
            }
        }
        // Default to first model
        if (modelModel.count > 0) {
            selectedModel = modelModel.get(0).modelName;
        }
    }

    // Encode a single image file to base64 (async)
    function encodeImageToBase64(imagePath, callback) {
        var cleanPath = imagePath;
        if (cleanPath.indexOf("file://") === 0) {
            cleanPath = cleanPath.substring(7);
        }
        // Handle Windows paths
        if (cleanPath.indexOf("/") !== 0 && cleanPath.length > 2 && cleanPath.charAt(1) === ":") {
            // Already a Windows path, keep it
        }

        var mimeType = "image/jpeg";
        var ext = cleanPath.split('.').pop().toLowerCase();
        if (ext === "png") mimeType = "image/png";
        else if (ext === "gif") mimeType = "image/gif";
        else if (ext === "webp") mimeType = "image/webp";
        else if (ext === "bmp") mimeType = "image/bmp";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + cleanPath, true);
        xhr.responseType = "arraybuffer";
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var arrayBuffer = xhr.response;
                        var bytes = new Uint8Array(arrayBuffer);
                        var binary = "";
                        for (var i = 0; i < bytes.length; i++) {
                            binary += String.fromCharCode(bytes[i]);
                        }
                        var base64 = Qt.btoa(binary);
                        console.log("Encoded image: " + cleanPath + " (" + bytes.length + " bytes, " + mimeType + ")");
                        callback({ data: base64, mimeType: mimeType, path: cleanPath });
                    } catch (e) {
                        console.log("Failed to encode image: " + e);
                        callback(null);
                    }
                } else {
                    console.log("Failed to read image file: " + cleanPath + " (status: " + xhr.status + ")");
                    callback(null);
                }
            }
        };
        xhr.send();
    }

    // Encode multiple images to base64 (async, calls callback when all done)
    function encodeImages(imagePaths, callback) {
        if (!imagePaths || imagePaths.length === 0) {
            callback([]);
            return;
        }
        var results = [];
        var completed = 0;
        var total = imagePaths.length;
        for (var i = 0; i < total; i++) {
            encodeImageToBase64(imagePaths[i], function(result) {
                if (result) {
                    results.push(result);
                }
                completed++;
                if (completed === total) {
                    console.log("Encoded " + results.length + "/" + total + " images successfully");
                    callback(results);
                }
            });
        }
    }

    ListModel {
        id: aliasModel
    }

    ListModel {
        id: modelModel
    }

    // Image file dialog
    FileDialog {
        id: imageDialog
        title: "Select Image"
        folder: shortcuts.pictures
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp *.webp)"]
        selectMultiple: true
        onAccepted: {
            var newImages = selectedImages.slice();
            var urls = imageDialog.fileUrls;
            for (var i = 0; i < urls.length; i++) {
                var path = urls[i].toString();
                // Convert file:/// to file:// for consistency
                if (path.indexOf("file:///") === 0) {
                    path = "file://" + path.substring(7);
                }
                newImages.push(path);
                console.log("Added image: " + path);
            }
            selectedImages = newImages;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Provider selection
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Provider:"
                font.bold: true
            }

            ComboBox {
                id: aliasCombo
                Layout.fillWidth: true
                textRole: "aliasName"
                model: aliasModel
                displayText: selectedAliasId ? (api ? (api.getAlias(selectedAliasId) || {}).name || selectedAliasId : selectedAliasId) : "Select provider..."

                onActivated: {
                    if (currentIndex >= 0 && currentIndex < aliasModel.count) {
                        selectedAliasId = aliasModel.get(currentIndex).aliasId;
                        selectedModel = api ? api.getFavoriteModel(selectedAliasId) || "" : "";
                        refreshModelList();
                    }
                }
            }

            Label {
                text: "Model:"
                font.bold: true
            }

            ComboBox {
                id: modelCombo
                Layout.fillWidth: true
                textRole: "modelName"
                model: modelModel
                displayText: selectedModel || "Select model..."

                onActivated: {
                    if (currentIndex >= 0 && currentIndex < modelModel.count) {
                        selectedModel = modelModel.get(currentIndex).modelName;
                    }
                }
            }

            Button {
                text: "Fetch"
                enabled: api && selectedAliasId.length > 0
                onClicked: {
                    if (api && selectedAliasId) {
                        fetchButton.enabled = false;
                        api.fetchModelsForAlias(selectedAliasId, function(models) {
                            refreshModelList();
                            fetchButton.enabled = true;
                        }, function(error) {
                            fetchButton.enabled = true;
                        });
                    }
                }

                id: fetchButton
            }
        }

        // Chat messages
        ListView {
            id: chatList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4

            model: ListModel {
                id: chatModel
            }

            delegate: Rectangle {
                width: chatList.width
                height: msgText.height + 12
                color: model.role === "user" ? "#e3f2fd" : (model.role === "error" ? "#ffebee" : "#f5f5f5")
                radius: 4

                Text {
                    id: msgText
                    anchors.fill: parent
                    anchors.margins: 6
                    text: model.message
                    wrapMode: Text.WordWrap
                    color: model.role === "error" ? "#c62828" : "#212121"
                }
            }
        }

        // Image preview area
        RowLayout {
            Layout.fillWidth: true
            visible: hasImages
            spacing: 4

            Repeater {
                model: selectedImages
                delegate: Rectangle {
                    width: 60
                    height: 60
                    color: "#e0e0e0"
                    radius: 4
                    border.color: "#1976d2"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var newImages = selectedImages.slice();
                            newImages.splice(index, 1);
                            selectedImages = newImages;
                        }
                        ToolTip.visible: pressed
                        ToolTip.text: "Click to remove"
                    }
                }
            }
        }

        // Input area
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "📷"
                enabled: !isGenerating && selectedAliasId.length > 0
                ToolTip.text: "Attach image"
                onClicked: imageDialog.open()
            }

            TextField {
                id: inputField
                Layout.fillWidth: true
                placeholderText: hasImages ? "Add a message to your images..." : (selectedAliasId ? "Type a message..." : "Add a provider first (Providers tab)")
                enabled: !isGenerating && selectedAliasId.length > 0 && selectedModel.length > 0
                onAccepted: sendMessage()
            }

            Button {
                text: isGenerating ? "..." : "Send"
                enabled: (inputField.text.length > 0 || hasImages) && !isGenerating && selectedAliasId.length > 0 && selectedModel.length > 0
                onClicked: sendMessage()
            }
        }
    }

    // Refresh when api changes (called from Main.qml on tab switch too)
    onApiChanged: refreshAll()

    function sendMessage() {
        if (!api || !selectedAliasId || !selectedModel) return;

        var hasText = inputField.text.trim().length > 0;
        var hasImgs = hasImages;
        if (!hasText && !hasImgs) return;

        var prompt = inputField.text.trim();
        var images = selectedImages.slice();

        // Build display message
        var displayMsg = prompt;
        if (hasImgs) {
            displayMsg = (hasText ? prompt : "") + (hasText ? "\n" : "") + "[" + images.length + " image(s) attached]";
        }

        inputField.text = "";
        selectedImages = [];

        // Add user message
        chatModel.append({"role": "user", "message": displayMsg});

        // Build history from previous messages
        var history = [];
        for (var i = 0; i < chatModel.count - 1; i++) {
            var entry = chatModel.get(i);
            history.push({role: entry.role, message: entry.message});
        }

        // Add empty bot message for streaming
        chatModel.append({"role": "bot", "message": ""});
        var botIndex = chatModel.count - 1;
        streamingContent = "";
        isGenerating = true;

        var alias = api.getAlias(selectedAliasId);
        var provider = api.getProvider(alias ? alias.type : "");
        var supportsStream = provider ? provider.features.supportsStreaming : false;

        if (hasImgs && images.length > 0) {
            // Multimodal: encode images first, then send
            console.log("Sending multimodal request with " + images.length + " images");
            encodeImages(images, function(encodedImages) {
                if (encodedImages.length === 0 && images.length > 0) {
                    chatModel.setProperty(botIndex, "message", "Error: Failed to encode images");
                    chatModel.setProperty(botIndex, "role", "error");
                    isGenerating = false;
                    return;
                }

                console.log("Encoded " + encodedImages.length + " images, sending request");
                // Multimodal requests use non-streaming mode
                try {
                    api.generateWithImages(
                        selectedAliasId,
                        selectedModel,
                        prompt,
                        history,
                        encodedImages,
                        // Success
                        function(response) {
                            console.log("generateWithImages success: " + (response ? response.length : 0) + " chars");
                            chatModel.setProperty(botIndex, "message", response);
                            isGenerating = false;
                        },
                        // Error
                        function(error) {
                            console.log("generateWithImages error: " + error);
                            chatModel.setProperty(botIndex, "message", "Error: " + error);
                            chatModel.setProperty(botIndex, "role", "error");
                            isGenerating = false;
                        },
                        // Stream callback (disabled for images)
                        null
                    );
                } catch (e) {
                    console.log("generateWithImages exception: " + e);
                    chatModel.setProperty(botIndex, "message", "Exception: " + e);
                    chatModel.setProperty(botIndex, "role", "error");
                    isGenerating = false;
                }
            });
        } else {
            // Text-only
            console.log("sendMessage called: alias=" + selectedAliasId + " model=" + selectedModel);

            try {
                api.generate(
                    selectedAliasId,
                    selectedModel,
                    prompt,
                    history,
                    // Success
                    function(response) {
                        console.log("generate success: " + (response ? response.length : 0) + " chars");
                        if (streamingContent.length === 0 && response.length > 0) {
                            chatModel.setProperty(botIndex, "message", response);
                        }
                        isGenerating = false;
                    },
                    // Error
                    function(error) {
                        console.log("generate error: " + error);
                        chatModel.setProperty(botIndex, "message", "Error: " + error);
                        chatModel.setProperty(botIndex, "role", "error");
                        isGenerating = false;
                    },
                    // Stream callback
                    supportsStream ? function(chunk) {
                        streamingContent += chunk;
                        chatModel.setProperty(botIndex, "message", streamingContent);
                    } : null
                );
            } catch (e) {
                console.log("generate exception: " + e);
                chatModel.setProperty(botIndex, "message", "Exception: " + e);
                chatModel.setProperty(botIndex, "role", "error");
                isGenerating = false;
            }
        }
    }
}