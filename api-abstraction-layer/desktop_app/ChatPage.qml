import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Page {
    id: chatPage
    title: qsTr("Chat")

    property var api: null
    property string selectedAliasId: ""
    property string selectedModel: ""
    property bool isGenerating: false
    property string streamingContent: ""

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

    ListModel {
        id: aliasModel
    }

    ListModel {
        id: modelModel
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
                color: model.role === "user" ? "#e3f2fd" : "#f5f5f5"
                radius: 4

                Text {
                    id: msgText
                    anchors.fill: parent
                    anchors.margins: 6
                    text: model.message
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Input area
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: inputField
                Layout.fillWidth: true
                placeholderText: selectedAliasId ? "Type a message..." : "Add a provider first (Providers tab)"
                enabled: !isGenerating && selectedAliasId.length > 0 && selectedModel.length > 0
                onAccepted: sendMessage()
            }

            Button {
                text: isGenerating ? "..." : "Send"
                enabled: inputField.text.length > 0 && !isGenerating && selectedAliasId.length > 0 && selectedModel.length > 0
                onClicked: sendMessage()
            }
        }
    }

    // Refresh when api changes (called from Main.qml on tab switch too)
    onApiChanged: refreshAll()

    function sendMessage() {
        if (!api || !selectedAliasId || !selectedModel || !inputField.text) return;

        console.log("sendMessage called: alias=" + selectedAliasId + " model=" + selectedModel);

        var prompt = inputField.text;
        inputField.text = "";

        // Add user message
        chatModel.append({"role": "user", "message": prompt});

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

        console.log("Calling generate: type=" + (alias ? alias.type : "?") + " stream=" + supportsStream);

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
            isGenerating = false;
        }
    }
}