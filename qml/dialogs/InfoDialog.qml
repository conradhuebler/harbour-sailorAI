import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    
    property string title: "Information"
    property string message: ""
    
    canAccept: false
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: dialog.title
                acceptText: ""
                cancelText: "Close"
            }
            
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: message
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }
        }
    }
}