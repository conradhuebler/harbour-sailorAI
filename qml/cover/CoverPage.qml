// CoverPage.qml
import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/LLMApi.js" as LLMApi

CoverBackground {
    id: coverBackground
    
    property int activeProviderCount: 0
    property int conversationCount: 0
    property bool hasActiveProviders: false
    
    // Background logo with multiple fallback options
    Image {
        id: backgroundIcon
        anchors.centerIn: parent
        width: parent.width * 0.75
        height: width
        fillMode: Image.PreserveAspectFit
        opacity: 1

        property var iconPaths: [
            "/usr/share/icons/hicolor/172x172/apps/harbour-sailorAI.png",
            "image://theme/icon-l-chat"
        ]
        property int currentPathIndex: 0

        Component.onCompleted: {
            source = iconPaths[0];
        }

        onStatusChanged: {
            if (status === Image.Error && currentPathIndex < iconPaths.length - 1) {
                currentPathIndex++;
                console.log("Icon not found at:", iconPaths[currentPathIndex - 1], "trying:", iconPaths[currentPathIndex]);
                source = iconPaths[currentPathIndex];
            } else if (status === Image.Ready) {
                console.log("Successfully loaded icon from:", source);
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium
        
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SailorAI"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.primaryColor
            font.bold: true
        }
        
        // Provider and conversation stats
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium
                
                Label {
                    text: "🤖 " + activeProviderCount
                    font.pixelSize: Theme.fontSizeSmall
                    color: activeProviderCount > 0 ? Theme.highlightColor : Theme.secondaryColor
                }
                
                Label {
                    text: "💬 " + conversationCount
                    font.pixelSize: Theme.fontSizeSmall
                    color: conversationCount > 0 ? Theme.highlightColor : Theme.secondaryColor
                }
            }
            
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: activeProviderCount > 0 ? 
                    (activeProviderCount + " provider" + (activeProviderCount > 1 ? "s" : "") + " • " + conversationCount + " chat" + (conversationCount !== 1 ? "s" : "")) :
                    "No providers configured"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    CoverActionList {
        enabled: hasActiveProviders
        
        CoverAction {
            iconSource: hasActiveProviders ? "image://theme/icon-cover-new" : "image://theme/icon-cover-cancel"
            onTriggered: {
                console.log("Cover New Chat triggered, hasActiveProviders:", hasActiveProviders);
                if (hasActiveProviders) {
                    // Signal to create new conversation
                    console.log("Emitting newChatRequested signal");
                    newChatRequested()
                } else {
                    console.log("New Chat disabled - no active providers");
                }
            }
        }
    }
    
    signal newChatRequested()
}
