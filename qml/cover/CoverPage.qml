// CoverPage.qml
import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: coverBackground
    
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium
        
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SailorAI"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.primaryColor
        }
        
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AI Chat Assistant"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                // Signal to create new conversation
                if (Qt.application.state === Qt.ApplicationActive) {
                    // App is already active, create new chat directly
                    newChatRequested()
                } else {
                    // App is not active, activate and then create new chat
                    Qt.application.state = Qt.ApplicationActive
                    newChatRequested()
                }
            }
        }
    }
    
    signal newChatRequested()
}
