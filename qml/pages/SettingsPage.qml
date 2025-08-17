import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger

Page {
    id: settingsPage

    property string currentAliasId: ""
    property var availableAliases: []
    property var currentAlias: null

    // Configuration for debug level
    ConfigurationValue {
        id: debugLevelConfig
        key: "/SailorAI/debug_level"
        defaultValue: "1"
        onValueChanged: {
            DebugLogger.setDebugLevel(parseInt(value) || 1);
            DebugLogger.logInfo("SettingsPage", "Debug level changed to " + value);
        }
    }

    // Configuration for provider aliases
    ConfigurationValue {
        id: providerAliasesConfig
        key: "/SailorAI/provider_aliases"
        defaultValue: ""
    }

    // Legacy configs for backward compatibility
    ConfigurationValue {
        id: geminiConfig
        key: "/SailorAI/gemini_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: openaiConfig
        key: "/SailorAI/openai_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: anthropicConfig
        key: "/SailorAI/anthropic_config"
        defaultValue: ""
    }

    ConfigurationValue {
        id: ollamaConfig
        key: "/SailorAI/ollama_config"
        defaultValue: ""
    }

    function loadAvailableAliases() {
        availableAliases = LLMApi.getProviderAliases();
        DebugLogger.logInfo("SettingsPage", "Loaded " + availableAliases.length + " provider aliases");
        
        if (availableAliases.length > 0) {
            if (!currentAliasId || availableAliases.indexOf(currentAliasId) === -1) {
                currentAliasId = availableAliases[0];
            }
            loadCurrentAlias();
        }
    }

    function loadCurrentAlias() {
        if (currentAliasId) {
            currentAlias = LLMApi.getProviderAlias(currentAliasId);
            if (currentAlias) {
                DebugLogger.logVerbose("SettingsPage", "Loaded alias: " + currentAliasId);
            }
        }
    }
    
    function showProviderModels(aliasId) {
        var alias = LLMApi.getProviderAlias(aliasId);
        
        if (alias) {
            // Open the favorite management dialog
            var favDialog = pageStack.push(Qt.resolvedUrl("../dialogs/FavoriteModelsDialog.qml"), {
                "selectedAliasId": aliasId
            });
            favDialog.accepted.connect(function() {
                // Refresh the provider list to show updated favorites
                loadAvailableAliases();
                loadCurrentAlias();
                DebugLogger.logInfo("SettingsPage", "Favorites updated for provider: " + aliasId);
            });
        }
    }
    
    function displayModelList(aliasId, fetchFresh) {
        var alias = LLMApi.getProviderAlias(aliasId);
        var models = LLMApi.getAliasModels(aliasId);
        
        if (alias) {
            var modelText = "";
            if (models.length > 0) {
                modelText = "Available models for " + alias.name + ":\\n\\n";
                
                // Sort models: favorites first, then others
                var favoriteModel = alias.favoriteModel;
                var favoriteModels = [];
                var otherModels = [];
                
                for (var i = 0; i < models.length; i++) {
                    if (models[i] === favoriteModel) {
                        favoriteModels.push(models[i]);
                    } else {
                        otherModels.push(models[i]);
                    }
                }
                
                // Add favorites first
                for (var j = 0; j < favoriteModels.length; j++) {
                    modelText += "★ " + favoriteModels[j] + "\\n";
                }
                
                // Add separator if we have favorites
                if (favoriteModels.length > 0 && otherModels.length > 0) {
                    modelText += "\\n── Other Models ──\\n";
                }
                
                // Add other models
                for (var k = 0; k < otherModels.length; k++) {
                    modelText += "• " + otherModels[k] + "\\n";
                }
                
                if (fetchFresh && alias.api_key) {
                    modelText += "\\n⟳ Refreshing from API...";
                }
            } else {
                if (alias.api_key && fetchFresh) {
                    modelText = "Fetching models from " + alias.name + " API...\\nPlease wait...";
                } else {
                    modelText = "No models available for " + alias.name + ".\\n\\n";
                    if (!alias.api_key) {
                        modelText += "Configure an API key to fetch models.";
                    } else {
                        modelText += "Try refreshing the list.";
                    }
                }
            }
            
            var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ModelListDialog.qml"), {
                "title": alias.name + " Models" + (models.length > 0 ? " (" + models.length + ")" : ""),
                "message": modelText,
                "aliasId": aliasId,
                "canRefresh": alias.api_key !== ""
            });
            
            // Start fresh fetch if requested and we have API key
            if (fetchFresh && alias.api_key) {
                LLMApi.checkAliasAvailability(aliasId, function(available, status) {
                    if (available) {
                        LLMApi.fetchModelsForAlias(aliasId);
                        // Update dialog after fetch (simple approach)
                        var refreshTimer = Qt.createQmlObject(
                            "import QtQuick 2.0; Timer { interval: 3000; running: true; repeat: false }",
                            page, "refreshTimer"
                        );
                        refreshTimer.triggered.connect(function() {
                            if (dialog && dialog.updateModelList) {
                                dialog.updateModelList();
                            }
                            refreshTimer.destroy();
                        });
                    }
                });
            }
        }
    }

    function saveCurrentAlias() {
        if (!currentAliasId || !currentAlias) {
            DebugLogger.logError("SettingsPage", "No current alias to save");
            return;
        }

        var apiKey = apiKeyField.text.trim();
        var url = baseUrlField.text.trim();
        var name = aliasNameField.text.trim();
        var description = descriptionField.text.trim();
        var timeout = parseInt(timeoutField.text) || 10000;

        // Update the alias
        if (currentAlias.isDefault) {
            // For default aliases, only update the API key
            currentAlias.api_key = apiKey;
        } else {
            // For custom aliases, update all fields
            currentAlias.name = name;
            currentAlias.api_key = apiKey;
            currentAlias.url = url;
            currentAlias.description = description;
            currentAlias.timeout = timeout;
        }

        // Save all aliases to config
        providerAliasesConfig.value = LLMApi.saveProviderAliases();
        
        DebugLogger.logInfo("SettingsPage", "Saved alias: " + currentAliasId + " with API key: " + (apiKey ? "***set***" : "empty"));

        // Check availability if API key is set
        if (apiKey) {
            DebugLogger.logInfo("SettingsPage", "Checking availability for alias: " + currentAliasId);
            LLMApi.checkAliasAvailability(currentAliasId, function(available, status) {
                DebugLogger.logInfo("SettingsPage", "Availability check result for " + currentAliasId + ": " + (available ? "available" : "unavailable") + " (" + status + ")");
                availabilityStatus.text = available ? "✓ Available (" + status + ")" : "✗ " + status;
                availabilityStatus.color = available ? Theme.primaryColor : Theme.errorColor;
            });
        } else {
            availabilityStatus.text = "No API key";
            availabilityStatus.color = Theme.secondaryColor;
        }
    }

    function createNewAlias() {
        var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/AddProviderAliasDialog.qml"));
        dialog.accepted.connect(function() {
            DebugLogger.logInfo("SettingsPage", "Attempting to create alias: " + dialog.aliasId);
            if (LLMApi.addProviderAlias(dialog.aliasId, dialog.aliasName, dialog.providerType, dialog.apiUrl, dialog.apiKey, "", dialog.description, 10000, dialog.favoriteModel)) {
                var savedConfig = LLMApi.saveProviderAliases();
                providerAliasesConfig.value = savedConfig;
                DebugLogger.logInfo("SettingsPage", "Saved config length: " + savedConfig.length);
                loadAvailableAliases();
                currentAliasId = dialog.aliasId;
                loadCurrentAlias();
                DebugLogger.logInfo("SettingsPage", "Created new alias: " + dialog.aliasId + " with API key: " + (dialog.apiKey ? "***set***" : "empty") + " and favorite model: " + dialog.favoriteModel);
            } else {
                DebugLogger.logError("SettingsPage", "Failed to create alias: " + dialog.aliasId);
            }
        });
    }

    Component.onCompleted: {
        DebugLogger.setDebugLevel(parseInt(debugLevelConfig.value) || 1);
        DebugLogger.logNormal("SettingsPage", "Settings page loaded");
        loadAvailableAliases();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height


        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "Settings"
                description: "Provider Configuration & Debug"
            }

            SectionHeader {
                text: "Debug Level"
            }

            ComboBox {
                id: debugLevelComboBox
                label: "Debug Level"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: parseInt(debugLevelConfig.value) || 1
                menu: ContextMenu {
                    MenuItem { 
                        text: "0 - None (Production)"
                        onClicked: {
                            debugLevelConfig.value = "0";
                            DebugLogger.logNormal("SettingsPage", "Debug level set to 0 (None)");
                        }
                    }
                    MenuItem { 
                        text: "1 - Normal (Errors & Important)"
                        onClicked: {
                            debugLevelConfig.value = "1";
                            DebugLogger.logNormal("SettingsPage", "Debug level set to 1 (Normal)");
                        }
                    }
                    MenuItem { 
                        text: "2 - Informative (API Calls)"
                        onClicked: {
                            debugLevelConfig.value = "2";
                            DebugLogger.logNormal("SettingsPage", "Debug level set to 2 (Informative)");
                        }
                    }
                    MenuItem { 
                        text: "3 - Verbose (All Operations)"
                        onClicked: {
                            debugLevelConfig.value = "3";
                            DebugLogger.logNormal("SettingsPage", "Debug level set to 3 (Verbose)");
                        }
                    }
                }
            }

            SectionHeader {
                text: "Provider Aliases"
            }
            
            Button {
                text: "Add Provider Alias"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: createNewAlias()
            }
            
            Item { height: Theme.paddingMedium }
            
            SilicaListView {
                id: providerListView
                width: parent.width
                height: availableAliases.length * Theme.itemSizeMedium + Theme.paddingLarge
                model: availableAliases
                
                delegate: ListItem {
                    width: providerListView.width
                    
                    onClicked: {
                        currentAliasId = modelData;
                        loadCurrentAlias();
                        showProviderModels(modelData);
                    }
                    
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        
                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall
                            
                            Label {
                                text: {
                                    var alias = LLMApi.getProviderAlias(modelData);
                                    var status = LLMApi.getAliasAvailability(modelData);
                                    var statusIcon = "";
                                    switch (status) {
                                        case "available": statusIcon = "✓"; break;
                                        case "checking": statusIcon = "⚠"; break;
                                        case "no_key": statusIcon = "⚷"; break;
                                        case "error":
                                        case "timeout": statusIcon = "✗"; break;
                                        default: statusIcon = "?"; break;
                                    }
                                    return statusIcon;
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: {
                                    var status = LLMApi.getAliasAvailability(modelData);
                                    switch (status) {
                                        case "available": return Theme.primaryColor;
                                        case "checking": return Theme.highlightColor;
                                        case "no_key": return Theme.secondaryColor;
                                        case "error":
                                        case "timeout": return Theme.errorColor;
                                        default: return Theme.secondaryColor;
                                    }
                                }
                                width: Theme.iconSizeSmall
                            }
                            
                            Column {
                                width: parent.width - Theme.iconSizeSmall - Theme.paddingSmall
                                
                                Label {
                                    text: {
                                        var alias = LLMApi.getProviderAlias(modelData);
                                        return alias ? alias.name : modelData;
                                    }
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeMedium
                                    width: parent.width
                                    truncationMode: TruncationMode.Fade
                                }
                                
                                Label {
                                    text: {
                                        var alias = LLMApi.getProviderAlias(modelData);
                                        if (alias) {
                                            var parts = [];
                                            parts.push("Type: " + alias.type);
                                            // Show multiple favorites
                                            var favorites = LLMApi.getAliasFavoriteModels(modelData);
                                            if (favorites && favorites.length > 0) {
                                                if (favorites.length === 1) {
                                                    parts.push("Favorite: ★ " + favorites[0]);
                                                } else {
                                                    parts.push("Favorites: ★ " + favorites.length);
                                                }
                                            }
                                            if (alias.api_key) {
                                                parts.push("API Key: ✓");
                                            }
                                            return parts.join(" | ");
                                        }
                                        return "";
                                    }
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    width: parent.width
                                    truncationMode: TruncationMode.Fade
                                }
                            }
                        }
                    }
                    
                    menu: ContextMenu {
                        MenuItem {
                            text: "Manage Favorites"
                            onClicked: {
                                showProviderModels(modelData);
                            }
                        }
                        MenuItem {
                            text: "Edit"
                            onClicked: {
                                var alias = LLMApi.getProviderAlias(modelData);
                                if (alias) {
                                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/EditProviderAliasDialog.qml"), {
                                        "aliasId": modelData,
                                        "aliasName": alias.name,
                                        "providerType": alias.type,
                                        "apiUrl": alias.url,
                                        "apiKey": alias.api_key,
                                        "description": alias.description,
                                        "favoriteModel": alias.favoriteModel
                                    });
                                    dialog.accepted.connect(function() {
                                        if (LLMApi.updateProviderAlias(modelData, dialog.aliasName, dialog.apiUrl, dialog.apiKey, dialog.description, 10000, dialog.favoriteModel)) {
                                            providerAliasesConfig.value = LLMApi.saveProviderAliases();
                                            loadAvailableAliases();
                                            DebugLogger.logInfo("SettingsPage", "Updated alias: " + modelData);
                                        }
                                    });
                                }
                            }
                        }
                        MenuItem {
                            text: "Delete"
                            enabled: {
                                var alias = LLMApi.getProviderAlias(modelData);
                                return alias && !alias.isDefault;
                            }
                            onClicked: {
                                if (LLMApi.removeProviderAlias(modelData)) {
                                    providerAliasesConfig.value = LLMApi.saveProviderAliases();
                                    loadAvailableAliases();
                                    DebugLogger.logInfo("SettingsPage", "Deleted alias: " + modelData);
                                }
                            }
                        }
                        MenuItem {
                            text: "Test Connection"
                            onClicked: {
                                var alias = LLMApi.getProviderAlias(modelData);
                                var testMessage = "Testing connection to " + (alias ? alias.name : modelData) + "...";
                                
                                LLMApi.checkAliasAvailability(modelData, function(available, status) {
                                    var resultMessage = "Connection test result:\\n\\n";
                                    resultMessage += "Provider: " + (alias ? alias.name : modelData) + "\\n";
                                    resultMessage += "Status: " + (available ? "✓ Available" : "✗ " + status) + "\\n";
                                    resultMessage += "URL: " + (alias ? alias.url : "Unknown");
                                    
                                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/InfoDialog.qml"), {
                                        "title": "Connection Test",
                                        "message": resultMessage
                                    });
                                });
                            }
                        }
                    }
                }
                
                ViewPlaceholder {
                    enabled: availableAliases.length === 0
                    text: "No provider aliases configured"
                    hintText: "Tap 'Add Provider Alias' to create your first configuration"
                }
            }
        }
    }
}
