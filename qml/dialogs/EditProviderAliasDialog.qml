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

    canAccept: aliasName.trim() !== "" && favoriteModel !== "" && !fetchingModels
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge * 1.5
            
            DialogHeader {
                title: "Edit Provider Alias"
                acceptText: "Save"
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
                currentIndex: {
                    var types = ["openai", "anthropic", "gemini", "ollama"];
                    return types.indexOf(providerType);
                }
                menu: ContextMenu {
                    MenuItem {
                        text: "OpenAI Compatible"
                        onClicked: {
                            providerType = "openai";
                            apiUrl = "https://api.openai.com/v1";
                            serverPreset = "";
                            loadModelsForType("openai");
                        }
                    }
                    MenuItem {
                        text: "Anthropic Claude"
                        onClicked: {
                            providerType = "anthropic";
                            apiUrl = "https://api.anthropic.com/v1";
                            serverPreset = "";
                            loadModelsForType("anthropic");
                        }
                    }
                    MenuItem {
                        text: "Google Gemini"
                        onClicked: {
                            providerType = "gemini";
                            apiUrl = "https://generativelanguage.googleapis.com/v1beta/models";
                            serverPreset = "";
                            loadModelsForType("gemini");
                        }
                    }
                    MenuItem {
                        text: "Ollama Local"
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
                text: "Base URL for the API endpoint (automatically set based on provider type)"
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
                text: apiUrl.indexOf("localhost:11434") !== -1 ? "Ollama doesn't require an API key for local use" : "Your API key for authentication (required for most providers)"
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
                text: "⚠ Fetching models from provider, please wait..."
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
    }
}