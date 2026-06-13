// Copyright (C) 2024 - 2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Edit an existing provider alias. Translated & flow relaxed with assistance from Claude.

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/DebugLogger.js" as DebugLogger
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog

    property string aliasId: ""
    property string aliasName: ""
    property string providerType: "openai"
    property string apiUrl: ""
    property string apiKey: ""
    property string description: ""
    property string favoriteModel: ""
    property var availableModels: []
    property bool fetchingModels: false
    property string serverPreset: ""
    // Claude Generated: provider metadata for signup/API-key link
    property var providerTypes: LLMApi.getProviderTypes()
    property string providerSignupUrl: providerTypes[providerType] ? (providerTypes[providerType].signupUrl || "") : ""
    // Web tool flags (Ollama only) - Claude Generated
    property bool enableWebSearch: true
    property bool enableWebFetch: true
    property string webSearchApiKey: ""

    // Claude Generated: favorite model optional — can be (re)selected later.
    canAccept: aliasName.trim() !== "" && apiUrl.trim() !== "" && !fetchingModels

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge * 1.5

            DialogHeader {
                title: qsTr("Edit provider")
                acceptText: qsTr("Save")
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
                currentIndex: {
                    var types = ["openai", "anthropic", "gemini", "ollama"];
                    return types.indexOf(providerType);
                }
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("OpenAI Compatible")
                        onClicked: {
                            providerType = "openai";
                            apiUrl = "https://api.openai.com/v1";
                            serverPreset = "";
                            loadModelsForType("openai");
                        }
                    }
                    MenuItem {
                        text: qsTr("Anthropic Claude")
                        onClicked: {
                            providerType = "anthropic";
                            apiUrl = "https://api.anthropic.com/v1";
                            serverPreset = "";
                            loadModelsForType("anthropic");
                        }
                    }
                    MenuItem {
                        text: qsTr("Google Gemini")
                        onClicked: {
                            providerType = "gemini";
                            apiUrl = "https://generativelanguage.googleapis.com/v1beta/models";
                            serverPreset = "";
                            loadModelsForType("gemini");
                        }
                    }
                    MenuItem {
                        text: qsTr("Ollama Local")
                        onClicked: {
                            providerType = "ollama";
                            apiUrl = "https://ollama.com";
                            serverPreset = "";
                            loadModelsForType("ollama");
                        }
                    }
                }
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
                text: qsTr("Base URL for the API endpoint (automatically set based on provider type)")
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
                text: apiUrl.indexOf("localhost:11434") !== -1 ? qsTr("Ollama doesn't require an API key for local use") : qsTr("Your API key for authentication (required for most providers)")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            // Claude Generated: link to provider signup / API key page
            BackgroundItem {
                visible: providerSignupUrl !== ""
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: Qt.openUrlExternally(providerSignupUrl)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Sign up or get API key")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Label {
                visible: providerSignupUrl !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: providerSignupUrl
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

            // Web tools - Ollama only - Claude Generated
            SectionHeader {
                text: qsTr("Web tools")
                visible: providerType === "ollama"
            }

            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                visible: providerType === "ollama"

                TextSwitch {
                    id: webSearchSwitch
                    text: qsTr("Enable web search")
                    description: qsTr("Let the model call Ollama's web_search tool when it needs fresh information.")
                    checked: enableWebSearch
                    onCheckedChanged: enableWebSearch = checked
                }

                TextSwitch {
                    id: webFetchSwitch
                    text: qsTr("Enable web fetch")
                    description: qsTr("Let the model call Ollama's web_fetch tool to read a specific page.")
                    checked: enableWebFetch
                    onCheckedChanged: enableWebFetch = checked
                }

                TextField {
                    id: webSearchApiKeyField
                    label: qsTr("Web search API key (optional)")
                    width: parent.width
                    text: webSearchApiKey
                    onTextChanged: webSearchApiKey = text
                    echoMode: TextInput.Password
                    placeholderText: apiKey.trim() !== "" ? qsTr("Using provider API key") : ""
                }

                Label {
                    width: parent.width
                    text: qsTr("If empty, the provider API key is used.")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
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

    function sortModelsByFavorites(models, aliasId) {
        var favorites = LLMApi.getAliasFavoriteModels(aliasId) || [];
        var list = (models || []).slice();

        // When nothing is fetched/cached yet, surface favorites so they stay
        // selectable. A non-empty list is authoritative - a favorite missing from
        // it was removed on the server and is not re-injected. - Claude Generated
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

        // Sort non-favorites alphabetically
        otherModels.sort();

        // Return favorites first, then other models
        return favoriteModels.concat(otherModels);
    }

    function loadModelsForType(type) {
        // Get alias to access its defaultModels
        var alias = LLMApi.getProviderAlias(aliasId);
        if (alias && alias.defaultModels) {
            var rawModels = alias.defaultModels.slice(); // Copy array
            // Sort models with favorites first
            availableModels = sortModelsByFavorites(rawModels, aliasId);
            if (availableModels.length > 0) {
                favoriteModel = availableModels[0];
            }
            DebugLogger.logVerbose("EditProviderAliasDialog", "Loaded " + availableModels.length + " default models from alias");
        } else {
            // Ultimate fallback: empty array
            availableModels = [];
            favoriteModel = "";
            DebugLogger.logWarning("EditProviderAliasDialog", "No default models found for type: " + type);
        }
    }

    function fetchModelsFromProvider() {
        if (!apiUrl.trim()) {
            DebugLogger.logError("EditProviderAliasDialog", "No API URL provided for model fetching");
            return;
        }

        fetchingModels = true;
        DebugLogger.logInfo("EditProviderAliasDialog", "Fetching models for type: " + providerType + " from: " + apiUrl);

        LLMApi.fetchModelsForType(providerType, apiUrl, apiKey.trim(), function(models) {
            fetchingModels = false;
            if (models.length > 0) {
                availableModels = sortModelsByFavorites(models, aliasId);
                if (favoriteModel === "" && availableModels.length > 0) {
                    favoriteModel = availableModels[0];
                }
                DebugLogger.logInfo("EditProviderAliasDialog", "Fetched " + models.length + " models successfully");
            } else {
                DebugLogger.logInfo("EditProviderAliasDialog", "No models returned for " + providerType);
            }
        }, function(error) {
            fetchingModels = false;
            DebugLogger.logError("EditProviderAliasDialog", "Model fetch failed: " + error);
        });
    }

    Component.onCompleted: {
        DebugLogger.logVerbose("EditProviderAliasDialog", "Dialog opened for alias: " + aliasId);

        // Load web tool state from alias (defaults are ollama=true, others=false)
        enableWebSearch = LLMApi.getAliasWebSearchMode(aliasId);
        enableWebFetch = LLMApi.getAliasWebFetchMode(aliasId);
        webSearchApiKey = LLMApi.getAliasWebSearchApiKey(aliasId);

        // First try to get real models from LLMApi
        var realModels = LLMApi.getAliasModels(aliasId);
        if (realModels && realModels.length > 0) {
            // Sort models with favorites first
            availableModels = sortModelsByFavorites(realModels, aliasId);
            DebugLogger.logInfo("EditProviderAliasDialog", "Loaded " + realModels.length + " real models from LLMApi");
        } else {
            // Fallback to default models
            loadModelsForType(providerType);
            DebugLogger.logInfo("EditProviderAliasDialog", "Using default models, will try to fetch real ones");

            // Try to fetch real models in background if API key is available
            var alias = LLMApi.getProviderAlias(aliasId);
            if (alias && alias.api_key) {
                LLMApi.fetchModelsForAlias(aliasId);
            }
        }
    }

    onAccepted: {
        DebugLogger.logInfo("EditProviderAliasDialog", "Updating alias: " + aliasId + " (" + aliasName + ") with favorite model: " + favoriteModel);

        // Persist web tool settings before closing - Claude Generated
        LLMApi.setAliasWebSearchMode(aliasId, enableWebSearch);
        LLMApi.setAliasWebFetchMode(aliasId, enableWebFetch);
        LLMApi.setAliasWebSearchApiKey(aliasId, webSearchApiKey);
    }
}
