import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    
    property string originalName: ""
    property alias newName: textField.text
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: "Rename Conversation"
            }
            
            TextField {
                id: textField
                width: parent.width
                label: "Conversation name"
                text: originalName
                placeholderText: "Enter new name"
                
                Component.onCompleted: {
                    selectAll()
                    forceActiveFocus()
                }
            }
        }
    }
    
    canAccept: textField.text.trim().length > 0
}