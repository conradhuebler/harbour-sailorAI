import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    
    property var conversationList
    property int currentId: -1
    
    signal conversationSelected(int id)
    signal newConversation()
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: "Conversations"
            }
            
            Button {
                text: "New Conversation"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    newConversation()
                    pageStack.pop()
                }
            }
            
            ListView {
                width: parent.width
                height: Math.min(400, conversationList ? conversationList.count * Theme.itemSizeMedium : 0)
                model: conversationList
                delegate: ListItem {
                    highlighted: model.id === currentId
                    
                    onClicked: {
                        conversationSelected(model.id)
                        pageStack.pop()
                    }
                    
                    Label {
                        text: model.name || "Conversation " + model.id
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                    
                    menu: ContextMenu {
                        MenuItem {
                            text: "Rename"
                            onClicked: {
                                var renameDialog = pageStack.push(Qt.resolvedUrl("RenameDialog.qml"), {
                                    "originalName": model.name || "Conversation " + model.id
                                })
                                renameDialog.accepted.connect(function() {
                                    // Rename conversation in database
                                    console.log("Rename not implemented yet")
                                })
                            }
                        }
                        MenuItem {
                            text: "Delete"
                            onClicked: {
                                console.log("Delete not implemented yet")
                            }
                        }
                    }
                }
            }
        }
    }
    
    canAccept: false
}