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

    canAccept: aliasName.trim() !== "" && favoriteModel !== "" && !fetchingModels

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge * 1.5

            DialogHeader {
                title: "Create Provider Alias"
                acceptText: "Create"
                cancelText: "Cancel"
            }

            // Section 1: Basic Information
            SectionHeader {
                text: "Basic Information"
            }

            TextField {
                id: aliasNameField
                label: "Provider Name"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                placeholderText: "My Gemini Account"
                text: aliasName
                onTextChanged: aliasName = text
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Display name for this provider\nGenerated ID: " + (aliasId || "provider_name")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingMedium }

            ComboBox {
                id: providerTypeComboBox
                label: "Provider Type"
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

            Item { height: Theme.paddingMedium }

            ComboBox {
                id: serverPresetComboBox
                label: "Server / Endpoint"
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
                        text: "Official API"
                        onClicked: {
                            serverPreset = "official";
                            if (providerType === "openai") apiUrl = "https://api.openai.com/v1";
                            else if (providerType === "anthropic") apiUrl = "https://api.anthropic.com/v1";
                        }
                    }
                    MenuItem {
                        text: "Ollama Compatible"
                        onClicked: {
                            serverPreset = "ollama";
                            if (providerType === "openai") apiUrl = "https://ollama.com/v1";
                            else if (providerType === "anthropic") apiUrl = "https://ollama.com/v1";
                        }
                    }
                    MenuItem {
                        text: "Custom"
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
                text: "Select the API server to use"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingLarge }

            // Section 2: API Configuration
            SectionHeader {
                text: "API Configuration"
            }

            TextField {
                id: apiUrlField
                label: "API URL"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: apiUrl
                onTextChanged: apiUrl = text
                placeholderText: "https://api.example.com/v1"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Base URL (auto-filled from provider type)"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingMedium }

            TextField {
                id: apiKeyField
                label: "API Key"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: apiKey
                onTextChanged: apiKey = text
                echoMode: TextInput.Password
                placeholderText: apiUrl.indexOf("localhost:11434") !== -1 ? "API Key (optional for local Ollama)" : "Enter your API key..."
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: apiUrl.indexOf("localhost:11434") !== -1 ? "Ollama doesn't require an API key for local use" : "Your API key for authentication"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Item { height: Theme.paddingSmall }

            Button {
                id: fetchModelsButton
                text: fetchingModels ? "Fetching Models..." : "Fetch Available Models"
                enabled: !fetchingModels && apiUrl.trim() !== ""
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: fetchModelsFromProvider()
            }

            Label {
                visible: fetchingModels
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Fetching models from provider, please wait..."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item { height: Theme.paddingLarge }

            // Section 3: Model Selection
            SectionHeader {
                text: "Model Selection"
            }

            ComboBox {
                id: favoriteModelComboBox
                label: "Favorite Model"
                description: availableModels.length > 0 ?
                    "Select from " + availableModels.length + " available models" :
                    "Fetch models first to select"
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
                text: "Additional Settings"
            }

            TextField {
                id: descriptionField
                label: "Description (Optional)"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: description
                onTextChanged: description = text
                placeholderText: "Personal account, company proxy, etc."
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Optional description to help identify this provider configuration"
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