import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog
    
    property string title: "Models"
    property string message: ""
    property string aliasId: ""
    property bool canRefresh: false
    
    canAccept: false
    
    function updateModelList() {
        var alias = LLMApi.getProviderAlias(aliasId);
        var models = LLMApi.getAliasModels(aliasId);
        
        if (alias && models.length > 0) {
            var modelText = "Available models for " + alias.name + ":\\n\\n";
            
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
            
            messageLabel.text = modelText;
            dialogHeader.title = alias.name + " Models (" + models.length + ")";
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
                id: dialogHeader
                title: dialog.title
                acceptText: ""
                cancelText: "Close"
            }
            
            Label {
                id: messageLabel
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: message
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }
            
            Button {
                visible: canRefresh
                text: "Refresh Models"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    messageLabel.text = "Refreshing models from API...\\nPlease wait...";
                    
                    LLMApi.checkAliasAvailability(aliasId, function(available, status) {
                        if (available) {
                            LLMApi.fetchModelsForAlias(aliasId);
                            // Update after fetch
                            var timer = Qt.createQmlObject(
                                "import QtQuick 2.0; Timer { interval: 3000; running: true; repeat: false }",
                                dialog, "updateTimer"
                            );
                            timer.triggered.connect(function() {
                                updateModelList();
                                timer.destroy();
                            });
                        } else {
                            messageLabel.text = "Failed to connect to provider:\\n" + status;
                        }
                    });
                }
            }
        }
    }
}