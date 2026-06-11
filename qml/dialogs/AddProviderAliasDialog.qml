// Copyright (C) 2024 - 2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Create a new provider alias: pick a type, fill in endpoint/key, optionally fetch models.
// Translated & flow relaxed with assistance from Claude.

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/DebugLogger.js" as DebugLogger
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog

    property string aliasName: ""
    property string providerType: "openai"
    property string apiUrl: ""
    property string apiKey: ""
    property string description: ""
    property string favoriteModel: ""
    property var availableModels: []
    property bool fetchingModels: false
    property string serverPreset: ""

    // Auto-generate aliasId from aliasName
    property string aliasId: aliasName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')

    // Provider types from config
    property var providerTypes: LLMApi.getProviderTypes()
    property var providerTypeIds: Object.keys(providerTypes)

    // Claude Generated: a favorite model is no longer required up front — it can be
    // fetched/selected later. Name and URL are enough to create the provider.
    canAccept: aliasName.trim() !== "" && apiUrl.trim() !== "" && !fetchingModels

    function providerTypeHint(type) {
        switch (type) {
            case "openai": return qsTr("OpenAI-compatible — also Mistral, Nvidia, local servers, proxies …");
            case "anthropic": return qsTr("Anthropic Claude API (or compatible endpoint).");
            case "gemini": return qsTr("Google Gemini API.");
            case "ollama": return qsTr("Ollama server (local or remote).");
            default: return "";
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge * 1.5

            DialogHeader {
                title: qsTr("Create provider")
                acceptText: qsTr("Create")
                cancelText: qsTr("Cancel")
            }

            // Section 1: Basic Information
            SectionHeader {
                text: qsTr("Basic information")
            }

            TextField {
                id: aliasNameField
                label: qsTr("Provider name")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                placeholderText: qsTr("My Gemini account")
                text: aliasName
                onTextChanged: aliasName = text
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Display name. Generated ID: %1").arg(aliasId || "provider_name")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingMedium }

            ComboBox {
                id: providerTypeComboBox
                label: qsTr("Provider type")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: providerTypeIds.indexOf(providerType)
                menu: ContextMenu {
                    Repeater {
                        model: providerTypeIds
                        MenuItem {
                            text: providerTypes[modelData] ? providerTypes[modelData].name : modelData
                            onClicked: {
                                providerType = modelData;
                                apiUrl = providerTypes[modelData] ? providerTypes[modelData].defaultUrl : "";
                                serverPreset = "";
                                loadModelsForType(modelData);
                            }
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: providerTypeHint(providerType)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingMedium }

            ComboBox {
                id: serverPresetComboBox
                label: qsTr("Server / endpoint")
                visible: providerType === "openai" || providerType === "anthropic"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: {
                    if (serverPreset === "official") return 0;
                    if (serverPreset === "ollama") return 1;
                    if (serverPreset === "custom") return 2;
                    return -1;
                }
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Official API")
                        onClicked: {
                            serverPreset = "official";
                            if (providerType === "openai") apiUrl = "https://api.openai.com/v1";
                            else if (providerType === "anthropic") apiUrl = "https://api.anthropic.com/v1";
                        }
                    }
                    MenuItem {
                        text: qsTr("Ollama compatible")
                        onClicked: {
                            serverPreset = "ollama";
                            if (providerType === "openai") apiUrl = "https://ollama.com/v1";
                            else if (providerType === "anthropic") apiUrl = "https://ollama.com/v1";
                        }
                    }
                    MenuItem {
                        text: qsTr("Custom")
                        onClicked: {
                            serverPreset = "custom";
                            apiUrl = "";
                        }
                    }
                }
            }

            Label {
                visible: serverPresetComboBox.visible
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Select the API server to use")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingLarge }

            // Section 2: API Configuration
            SectionHeader {
                text: qsTr("API configuration")
            }

            TextField {
                id: apiUrlField
                label: qsTr("API URL")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: apiUrl
                onTextChanged: apiUrl = text
                placeholderText: qsTr("https://api.example.com/v1")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Base URL (auto-filled from provider type)")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingMedium }

            TextField {
                id: apiKeyField
                label: qsTr("API key")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: apiKey
                onTextChanged: apiKey = text
                echoMode: TextInput.Password
                placeholderText: apiUrl.indexOf("localhost:11434") !== -1 ? qsTr("API key (optional for local Ollama)") : qsTr("Enter your API key…")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: apiUrl.indexOf("localhost:11434") !== -1 ? qsTr("Ollama doesn't require an API key for local use") : qsTr("Your API key for authentication")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingSmall }

            Button {
                id: fetchModelsButton
                text: fetchingModels ? qsTr("Fetching models…") : qsTr("Fetch available models")
                enabled: !fetchingModels && apiUrl.trim() !== ""
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: fetchModelsFromProvider()
            }

            Label {
                visible: fetchingModels
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Fetching models from provider, please wait…")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item { height: Theme.paddingLarge }

            // Section 3: Model Selection
            SectionHeader {
                text: qsTr("Model selection")
            }

            ComboBox {
                id: favoriteModelComboBox
                label: qsTr("Favorite model")
                description: availableModels.length > 0 ?
                    qsTr("Select from %1 available models").arg(availableModels.length) :
                    qsTr("Optional — fetch models to choose, or set it later")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: availableModels.indexOf(favoriteModel)
                enabled: availableModels.length > 0 && !fetchingModels
                menu: ContextMenu {
                    Repeater {
                        model: availableModels
                        MenuItem {
                            text: modelData
                            onClicked: {
                                favoriteModel = modelData;
                            }
                        }
                    }
                }
            }

            Item { height: Theme.paddingLarge }

            // Section 4: Additional Settings
            SectionHeader {
                text: qsTr("Additional settings")
            }

            TextField {
                id: descriptionField
                label: qsTr("Description (optional)")
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: description
                onTextChanged: description = text
                placeholderText: qsTr("Personal account, company proxy, etc.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Optional description to help identify this provider configuration")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingLarge }
        }
    }

    function loadModelsForType(type) {
        // No hardcoded defaults - models are fetched dynamically
        availableModels = [];
        favoriteModel = "";
        DebugLogger.logInfo("AddProviderAliasDialog", "Provider type set to: " + type + " - fetch models to see available options");
    }

    function fetchModelsFromProvider() {
        if (!apiUrl.trim()) {
            DebugLogger.logError("AddProviderAliasDialog", "No API URL provided for model fetching");
            return;
        }

        fetchingModels = true;
        DebugLogger.logInfo("AddProviderAliasDialog", "Fetching models for type: " + providerType + " from: " + apiUrl);

        LLMApi.fetchModelsForType(providerType, apiUrl, apiKey.trim(), function(models) {
            fetchingModels = false;
            if (models.length > 0) {
                availableModels = models;
                favoriteModel = models[0];
                DebugLogger.logInfo("AddProviderAliasDialog", "Fetched " + models.length + " models successfully");
            } else {
                DebugLogger.logInfo("AddProviderAliasDialog", "No models found for " + providerType);
            }
        }, function(error) {
            fetchingModels = false;
            DebugLogger.logError("AddProviderAliasDialog", "Model fetch failed: " + error);
        });
    }

    Component.onCompleted: {
        // Auto-fill URL from provider config
        if (providerTypes[providerType]) {
            apiUrl = providerTypes[providerType].defaultUrl;
        }
    }

    onAccepted: {
        DebugLogger.logInfo("AddProviderAliasDialog", "Creating alias: " + aliasId + " (" + aliasName + ") with favorite model: " + favoriteModel);
    }
}
