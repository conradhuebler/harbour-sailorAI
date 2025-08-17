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
                            loadModelsForType("openai");
                        }
                    }
                    MenuItem { 
                        text: "Anthropic Claude"
                        onClicked: {
                            providerType = "anthropic";
                            apiUrl = "https://api.anthropic.com/v1";
                            loadModelsForType("anthropic");
                        }
                    }
                    MenuItem { 
                        text: "Google Gemini"
                        onClicked: {
                            providerType = "gemini";
                            apiUrl = "https://generativelanguage.googleapis.com/v1beta/models";
                            loadModelsForType("gemini");
                        }
                    }
                    MenuItem { 
                        text: "Ollama Local"
                        onClicked: {
                            providerType = "ollama";
                            apiUrl = "http://localhost:11434/v1";
                            loadModelsForType("ollama");
                        }
                    }
                }
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
                placeholderText: "Enter your API key..."
            }
            
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Your API key for authentication (required for most providers, except Ollama)"
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
            DebugLogger.logError("AddProviderAliasDialog", "No API URL provided for model fetching");
            return;
        }
        
        fetchingModels = true;
        DebugLogger.logInfo("AddProviderAliasDialog", "Fetching models from: " + apiUrl);
        
        // Create temporary alias for model fetching
        var tempAlias = {
            type: providerType,
            url: apiUrl,
            api_key: apiKey.trim(), // Use provided API key if available
            timeout: 10000
        };
        
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                fetchingModels = false;
                
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var models = parseModelsResponse(response, providerType);
                        
                        if (models.length > 0) {
                            availableModels = models;
                            favoriteModel = models[0];
                            DebugLogger.logInfo("AddProviderAliasDialog", "Fetched " + models.length + " models successfully");
                        } else {
                            DebugLogger.logError("AddProviderAliasDialog", "No models found in response");
                        }
                    } catch (e) {
                        DebugLogger.logError("AddProviderAliasDialog", "Failed to parse models response: " + e.toString());
                    }
                } else {
                    DebugLogger.logError("AddProviderAliasDialog", "Model fetch failed with status: " + xhr.status);
                }
            }
        };
        
        try {
            var modelsUrl = apiUrl;
            if (providerType === "ollama" || providerType === "openai" || providerType === "anthropic") {
                if (modelsUrl.indexOf("/models") === -1) {
                    modelsUrl += "/models";
                }
            }
            
            xhr.open("GET", modelsUrl, true);
            xhr.timeout = 10000;
            
            // Add authentication headers if API key is provided
            if (apiKey.trim() !== "") {
                if (providerType === "gemini") {
                    xhr.setRequestHeader("x-goog-api-key", apiKey.trim());
                } else if (providerType === "openai" || providerType === "anthropic" || providerType === "ollama") {
                    xhr.setRequestHeader("Authorization", "Bearer " + apiKey.trim());
                }
            }
            
            xhr.send();
        } catch (e) {
            fetchingModels = false;
            DebugLogger.logError("AddProviderAliasDialog", "Failed to initiate model fetch: " + e.toString());
        }
    }
    
    function parseModelsResponse(response, type) {
        var models = [];
        
        try {
            if (type === "gemini") {
                if (response.models) {
                    for (var i = 0; i < response.models.length; i++) {
                        var model = response.models[i];
                        var modelName = (typeof model === "string") ? model : model.name;
                        if (modelName && modelName.startsWith && modelName.startsWith("models/")) {
                            modelName = modelName.substring(7);
                        }
                        if (modelName) {
                            models.push(modelName);
                        }
                    }
                }
            } else if (type === "openai" || type === "anthropic" || type === "ollama") {
                if (response.data) {
                    for (var j = 0; j < response.data.length; j++) {
                        var modelObj = response.data[j];
                        if (modelObj.id) {
                            models.push(modelObj.id);
                        }
                    }
                }
            }
        } catch (e) {
            DebugLogger.logError("AddProviderAliasDialog", "Error parsing models: " + e.toString());
        }
        
        return models;
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