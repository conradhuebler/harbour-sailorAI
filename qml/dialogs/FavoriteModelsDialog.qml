import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/DebugLogger.js" as DebugLogger
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog
    
    property string selectedAliasId: ""
    property var selectedFavorites: []
    property var allModels: []
    property bool isLoading: false
    
    canAccept: selectedFavorites.length > 0
    
    onSelectedAliasIdChanged: {
        if (selectedAliasId) {
            loadAllModels();
        }
    }
    
    function loadAllModels() {
        var alias = LLMApi.getProviderAlias(selectedAliasId);
        if (!alias) {
            DebugLogger.logError("FavoriteModelsDialog", "Alias not found: " + selectedAliasId);
            return;
        }
        
        DebugLogger.logInfo("FavoriteModelsDialog", "Loading models for: " + selectedAliasId);
        
        // Get current favorites
        selectedFavorites = LLMApi.getAliasFavoriteModels(selectedAliasId);
        
        // Start with cached models + default models
        var cachedModels = LLMApi.getAliasModels(selectedAliasId);
        var defaultModels = alias.defaultModels || [];
        
        // Combine and deduplicate
        var combinedModels = [];
        var seen = {};
        
        // Add cached models first
        for (var i = 0; i < cachedModels.length; i++) {
            if (!seen[cachedModels[i]]) {
                combinedModels.push(cachedModels[i]);
                seen[cachedModels[i]] = true;
            }
        }
        
        // Add default models
        for (var j = 0; j < defaultModels.length; j++) {
            if (!seen[defaultModels[j]]) {
                combinedModels.push(defaultModels[j]);
                seen[defaultModels[j]] = true;
            }
        }
        
        // Add favorites that might not be in other lists
        for (var k = 0; k < selectedFavorites.length; k++) {
            if (!seen[selectedFavorites[k]]) {
                combinedModels.push(selectedFavorites[k]);
                seen[selectedFavorites[k]] = true;
            }
        }
        
        allModels = combinedModels;
        DebugLogger.logInfo("FavoriteModelsDialog", "Loaded " + allModels.length + " total models (" + selectedFavorites.length + " favorites)");
        
        // Trigger fresh fetch in background if API key available
        if (alias.api_key) {
            isLoading = true;
            DebugLogger.logInfo("FavoriteModelsDialog", "Fetching fresh models from API...");
            LLMApi.fetchModelsForAlias(selectedAliasId);
            
            // We'll refresh the list when models are updated
            // TODO: Add callback mechanism for model updates
        }
    }
    
    function toggleFavorite(model) {
        var index = selectedFavorites.indexOf(model);
        var newFavorites = selectedFavorites.slice(); // Copy array
        
        if (index !== -1) {
            // Remove from favorites
            newFavorites.splice(index, 1);
        } else {
            // Add to favorites
            newFavorites.push(model);
        }
        
        selectedFavorites = newFavorites;
        DebugLogger.logVerbose("FavoriteModelsDialog", "Toggled favorite: " + model + ", total favorites: " + selectedFavorites.length);
    }
    
    function getProviderDisplayName() {
        if (selectedAliasId) {
            var alias = LLMApi.getProviderAlias(selectedAliasId);
            return alias ? alias.name : selectedAliasId;
        }
        return "";
    }
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: "Manage Favorite Models"
                acceptText: "Save (" + selectedFavorites.length + ")"
                cancelText: "Cancel"
            }
            
            Label {
                text: "Provider: " + getProviderDisplayName()
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.highlightColor
            }
            
            Label {
                text: selectedFavorites.length + " favorite models selected"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }
            
            SectionHeader {
                text: "Available Models (" + allModels.length + ")"
            }
            
            Label {
                visible: isLoading
                text: "🔄 Loading models from API..."
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
            }
            
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                
                Repeater {
                    model: allModels
                    
                    ListItem {
                        id: modelItem
                        width: parent.width
                        contentHeight: Theme.itemSizeSmall
                        
                        property bool isFavorite: selectedFavorites.indexOf(modelData) !== -1
                        
                        onClicked: {
                            toggleFavorite(modelData);
                        }
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.paddingMedium
                            
                            // Checkbox indicator
                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                radius: Theme.paddingSmall / 2
                                anchors.verticalCenter: parent.verticalCenter
                                
                                color: modelItem.isFavorite ? Theme.highlightColor : "transparent"
                                border.color: Theme.highlightColor
                                border.width: 2
                                
                                Label {
                                    visible: modelItem.isFavorite
                                    text: "✓"
                                    anchors.centerIn: parent
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.highlightBackgroundColor
                                }
                            }
                            
                            // Star indicator for existing favorites
                            Label {
                                visible: modelItem.isFavorite
                                text: "★"
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }
                            
                            // Model name
                            Label {
                                text: modelData
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelItem.isFavorite ? Theme.highlightColor : Theme.primaryColor
                                width: parent.width - Theme.iconSizeSmall - Theme.paddingMedium * 3
                                elide: Text.ElideRight
                            }
                        }
                        
                        Rectangle {
                            visible: modelItem.isFavorite
                            anchors.fill: parent
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                            radius: Theme.paddingSmall
                        }
                    }
                }
            }
            
            Item { height: Theme.paddingLarge }
        }
    }
    
    Component.onCompleted: {
        if (selectedAliasId) {
            loadAllModels();
        }
    }
    
    onAccepted: {
        // Save the selected favorites
        LLMApi.setAliasFavoriteModels(selectedAliasId, selectedFavorites);
        DebugLogger.logInfo("FavoriteModelsDialog", "Saved " + selectedFavorites.length + " favorite models for " + selectedAliasId + ": " + selectedFavorites.join(", "));
    }
}