import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    
    property real temperature: 0.7
    property int seed: -1
    
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        
        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            
            DialogHeader {
                title: "Advanced Settings"
            }
            
            Slider {
                id: temperatureSlider
                width: parent.width
                label: "Temperature"
                minimumValue: 0.0
                maximumValue: 2.0
                value: temperature
                stepSize: 0.1
                valueText: value.toFixed(1)
                
                onValueChanged: {
                    temperature = value
                }
                
                Label {
                    parent: temperatureSlider
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    text: "Controls randomness: 0 = deterministic, 2 = very creative"
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
                    width: parent.width - 2 * Theme.horizontalPageMargin
                }
            }
            
            TextField {
                id: seedField
                width: parent.width
                label: "Seed (optional)"
                text: seed === -1 ? "" : seed.toString()
                placeholderText: "Random seed for reproducible results"
                inputMethodHints: Qt.ImhDigitsOnly
                
                onTextChanged: {
                    var newSeed = parseInt(text)
                    seed = isNaN(newSeed) ? -1 : newSeed
                }
                
                Label {
                    parent: seedField
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    text: "Same seed = same response (if available). Leave empty for random."
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    wrapMode: Text.WordWrap
                    width: parent.width - 2 * Theme.horizontalPageMargin
                }
            }
            
            Button {
                text: "Reset to Defaults"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    temperatureSlider.value = 0.7
                    seedField.text = ""
                }
            }
        }
    }
    
    canAccept: true
}