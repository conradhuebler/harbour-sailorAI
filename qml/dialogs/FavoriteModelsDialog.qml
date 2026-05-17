import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/DebugLogger.js" as DebugLogger
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog
    
    property string selectedAliasId: ""
    property var selectedFavorites: []
    property var allModels: []
    
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
        
        // Sort: favorites first (by preference order), then others alphabetically
        var favoritesOrdered = [];
        var othersOrdered = [];
        for (var fi = 0; fi < combinedModels.length; fi++) {
            if (selectedFavorites.indexOf(combinedModels[fi]) !== -1) {
                favoritesOrdered.push(combinedModels[fi]);
            } else {
                othersOrdered.push(combinedModels[fi]);
            }
        }
        favoritesOrdered.sort(function(a, b) {
            return selectedFavorites.indexOf(a) - selectedFavorites.indexOf(b);
        });
        othersOrdered.sort();
        allModels = favoritesOrdered.concat(othersOrdered);

        DebugLogger.logInfo("FavoriteModelsDialog", "Loaded " + allModels.length + " total models (" + selectedFavorites.length + " favorites)");
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
            
            Column {
                width: parent.width
                spacing: 0

                Repeater {
                    model: allModels

                    ListItem {
                        id: modelItem
                        width: parent.width
                        contentHeight: itemRow.height + Theme.paddingSmall

                        property bool isFavorite: selectedFavorites.indexOf(modelData) !== -1

                        onClicked: {
                            toggleFavorite(modelData);
                        }

                        Row {
                            id: itemRow
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

                            Column {
                                width: parent.width - Theme.iconSizeSmall - Theme.paddingMedium
                                anchors.verticalCenter: parent.verticalCenter

                                Label {
                                    text: (modelItem.isFavorite ? "★ " : "") + modelData
                                    width: parent.width
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: modelItem.isFavorite ? Theme.highlightColor : Theme.primaryColor
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    text: LLMApi.getModelInfo(selectedAliasId, modelData)
                                    width: parent.width
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                    wrapMode: Text.WordWrap
                                    visible: text !== ""
                                    height: visible ? implicitHeight : 0
                                }
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