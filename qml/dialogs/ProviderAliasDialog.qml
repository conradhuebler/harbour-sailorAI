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
            
            // Use current models (will be updated by background fetch)
            availableModels = LLMApi.getAliasModels(selectedAliasId);
            
            if (availableModels.length > 0) {
                if (favoriteModel && availableModels.indexOf(favoriteModel) !== -1) {
                    selectedModel = favoriteModel;
                    DebugLogger.logVerbose("ProviderAliasDialog", "Selected favorite model: " + selectedModel);
                } else if (availableModels.indexOf(selectedModel) === -1) {
                    selectedModel = availableModels[0];
                    DebugLogger.logVerbose("ProviderAliasDialog", "Selected first available model: " + selectedModel);
                } else {
                    DebugLogger.logVerbose("ProviderAliasDialog", "Keeping current model: " + selectedModel);
                }
            }
            
            DebugLogger.logVerbose("ProviderAliasDialog", "Loaded " + availableModels.length + " models for alias: " + selectedAliasId + ", selected: " + selectedModel);
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
                text: "Current: " + getProviderDisplayName() + " (" + selectedModel + ")"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
            }
            
            function getProviderDisplayName() {
                if (selectedAliasId) {
                    var alias = LLMApi.getProviderAlias(selectedAliasId);
                    return alias ? alias.name : selectedAliasId;
                }
                return "";
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
                menu: ContextMenu {
                    Repeater {
                        model: availableModels
                        MenuItem { 
                            text: {
                                var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
                                var isFavorite = (modelData === favoriteModel);
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
                    var favoriteModel = LLMApi.getAliasFavoriteModel(selectedAliasId);
                    var currentModel = selectedModel;
                    
                    if (currentModel && favoriteModel) {
                        if (currentModel === favoriteModel) {
                            return "★ " + currentModel + " is your favorite model";
                        } else {
                            return "Current: " + currentModel + " | Favorite: ★ " + favoriteModel;
                        }
                    } else if (currentModel) {
                        return "Current: " + currentModel + " | No favorite set";
                    } else if (favoriteModel) {
                        return "Favorite: ★ " + favoriteModel;
                    }
                    return "No model selected";
                }
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
            }
        }
    }
    
    canAccept: selectedAliasId.length > 0 && selectedModel.length > 0
    
    onAccepted: {
        DebugLogger.logInfo("ProviderAliasDialog", "Selected alias: " + selectedAliasId + ", model: " + selectedModel);
    }
}
