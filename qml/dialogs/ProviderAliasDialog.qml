import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger

Dialog {
    id: dialog
    
    property string selectedAliasId: ""
    property string selectedModel: ""
    property var availableAliases: []
    property var availableModels: []
    
    Component.onCompleted: {
        loadAliases();
    }
    
    function loadAliases() {
        availableAliases = LLMApi.getProviderAliases();
        DebugLogger.logVerbose("ProviderAliasDialog", "Loaded " + availableAliases.length + " provider aliases");
        
        if (availableAliases.length > 0) {
            if (!selectedAliasId || availableAliases.indexOf(selectedAliasId) === -1) {
                selectedAliasId = availableAliases[0];
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
            // First get the favorite model
            var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
            
            // Try to fetch fresh models from API
            var alias = LLMApi.getProviderAlias(selectedAliasId);
            if (alias && alias.api_key) {
                DebugLogger.logInfo("ProviderAliasDialog", "Fetching fresh models for: " + selectedAliasId);
                LLMApi.fetchModelsForAlias(selectedAliasId);
            }
            
            // Get cached models first
            var cachedModels = LLMApi.getAliasModels(selectedAliasId);
            var rawModels = [];
            
            // If no cached models, use default models from alias
            if (cachedModels.length === 0 && alias.defaultModels) {
                rawModels = alias.defaultModels.slice(); // Copy array
                DebugLogger.logInfo("ProviderAliasDialog", "Using default models for " + selectedAliasId + ": " + rawModels.length);
            } else {
                rawModels = cachedModels;
                DebugLogger.logInfo("ProviderAliasDialog", "Using cached models for " + selectedAliasId + ": " + rawModels.length);
            }
            
            // Sort models with favorites first
            availableModels = sortModelsByFavorites(rawModels, selectedAliasId);
            DebugLogger.logVerbose("ProviderAliasDialog", "Sorted " + availableModels.length + " models with favorites first");
            
            // Set selected model with better fallback logic
            if (availableModels.length > 0) {
                // Priority: 1) Current selection if valid, 2) Favorite model, 3) First available
                if (selectedModel && availableModels.indexOf(selectedModel) !== -1) {
                    // Keep current selection if valid
                    DebugLogger.logVerbose("ProviderAliasDialog", "Keeping current selection: " + selectedModel);
                } else if (favoriteModel && availableModels.indexOf(favoriteModel) !== -1) {
                    selectedModel = favoriteModel;
                    DebugLogger.logVerbose("ProviderAliasDialog", "Selected favorite model: " + selectedModel);
                } else {
                    selectedModel = availableModels[0];
                    DebugLogger.logVerbose("ProviderAliasDialog", "Selected first available model: " + selectedModel);
                }
            } else {
                // Fallback: use favorite model even if not in list (for manual input)
                selectedModel = favoriteModel || "";
                DebugLogger.logInfo("ProviderAliasDialog", "No models available, using favorite fallback: " + selectedModel);
            }
            
            DebugLogger.logVerbose("ProviderAliasDialog", "Loaded " + availableModels.length + " models for alias: " + selectedAliasId + ", selected: " + selectedModel);
            
            // Trigger UI update for model ComboBox
            updateModelComboBox();
        }
    }
    
    function updateModelComboBox() {
        // Force model ComboBox to refresh its menu items
        if (modelComboBox) {
            modelComboBox.menuRevision++;
            // Also update the currentIndex binding
            modelComboBox.currentIndex = availableModels.indexOf(selectedModel);
        }
    }
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: "Select Provider & Model"
                acceptText: "Select"
                cancelText: "Cancel"
            }
            
            // Current selection info
            Label {
                visible: selectedAliasId && selectedModel
                text: {
                    if (selectedAliasId) {
                        var alias = LLMApi.getProviderAlias(selectedAliasId);
                        var providerName = alias ? alias.name : selectedAliasId;
                        return "Current: " + providerName + " (" + selectedModel + ")";
                    }
                    return "";
                }
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
            }
            
            SectionHeader {
                text: "Provider Alias"
            }
            
            ComboBox {
                id: aliasComboBox
                label: "Provider Alias"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: availableAliases.indexOf(selectedAliasId)
                menu: ContextMenu {
                    Repeater {
                        model: availableAliases
                        MenuItem { 
                            text: {
                                var alias = LLMApi.getProviderAlias(modelData);
                                var status = LLMApi.getAliasAvailability(modelData);
                                return (alias ? alias.name : modelData);
                            }
                            onClicked: {
                                selectedAliasId = modelData;
                                loadModels();
                            }
                        }
                    }
                }
            }
            
            Label {
                visible: selectedAliasId
                text: {
                    var alias = LLMApi.getProviderAlias(selectedAliasId);
                    if (alias) {
                        return "Type: " + alias.type + (alias.description ? "\n" + alias.description : "");
                    }
                    return "";
                }
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }
            
            SectionHeader {
                text: "Model Selection"
            }
            
            ComboBox {
                id: modelComboBox
                label: "Model"
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                currentIndex: availableModels.indexOf(selectedModel)
                
                // Update when models or selection changes
                Component.onCompleted: {
                    currentIndex = Qt.binding(function() { 
                        return availableModels.indexOf(selectedModel);
                    });
                }
                // Force menu recreation when availableModels changes
                property int menuRevision: 0
                
                onCurrentIndexChanged: {
                    // Trigger menu update when models change
                    if (availableModels && availableModels.length > 0) {
                        menuRevision++;
                    }
                }
                
                menu: ContextMenu {
                    // Force recreation when menuRevision changes
                    property int currentRevision: modelComboBox.menuRevision
                    
                    Repeater {
                        model: availableModels || []
                        MenuItem { 
                            text: {
                                var isFavorite = LLMApi.isAliasFavoriteModel(selectedAliasId, modelData);
                                var isCurrent = (modelData === selectedModel);
                                var prefix = "";
                                if (isCurrent && isFavorite) {
                                    prefix = "★✓ ";
                                } else if (isFavorite) {
                                    prefix = "★ ";
                                } else if (isCurrent) {
                                    prefix = "✓ ";
                                }
                                return prefix + modelData;
                            }
                            onClicked: {
                                selectedModel = modelData;
                            }
                        }
                    }
                }
            }
            
            Label {
                visible: selectedAliasId
                text: {
                    var favorites = LLMApi.getAliasFavoriteModels(selectedAliasId);
                    var currentModel = selectedModel;
                    var isFavorite = LLMApi.isAliasFavoriteModel(selectedAliasId, currentModel);
                    
                    if (currentModel) {
                        var currentText = "Current: " + currentModel;
                        if (isFavorite) {
                            currentText += " ★";
                        }
                        
                        if (favorites.length > 0) {
                            var favText = "Favorites: ★ " + favorites.join(", ★ ");
                            return currentText + " | " + favText;
                        } else {
                            return currentText + " | No favorites set";
                        }
                    } else if (favorites.length > 0) {
                        return "Favorites: ★ " + favorites.join(", ★ ");
                    }
                    return "No model selected";
                }
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
            }
            
            Button {
                visible: selectedAliasId
                text: "Manage Favorites"
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    var favDialog = pageStack.push(Qt.resolvedUrl("FavoriteModelsDialog.qml"), {
                        "selectedAliasId": selectedAliasId
                    });
                    favDialog.accepted.connect(function() {
                        // Refresh the display to show updated favorites
                        loadModels();
                        updateModelComboBox();
                    });
                }
            }
        }
    }
    
    canAccept: selectedAliasId.length > 0 && selectedModel.length > 0
    
    onAccepted: {
        DebugLogger.logInfo("ProviderAliasDialog", "Selected alias: " + selectedAliasId + ", model: " + selectedModel);
    }
}
