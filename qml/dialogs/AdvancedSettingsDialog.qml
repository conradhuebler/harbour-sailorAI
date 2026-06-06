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
                title: qsTr("Advanced Settings")
            }

            SectionHeader {
                text: qsTr("Temperature")
            }

            Slider {
                id: temperatureSlider
                width: parent.width
                minimumValue: 0.0
                maximumValue: 2.0
                value: temperature
                stepSize: 0.1
                valueText: value.toFixed(1)
                onValueChanged: temperature = value
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Controls randomness: 0 = deterministic, 2 = very creative")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            SectionHeader {
                text: qsTr("Seed")
            }

            TextField {
                id: seedField
                width: parent.width
                label: qsTr("Seed (optional)")
                text: seed === -1 ? "" : seed.toString()
                placeholderText: qsTr("Leave empty for random")
                inputMethodHints: Qt.ImhDigitsOnly
                onTextChanged: {
                    var newSeed = parseInt(text)
                    seed = isNaN(newSeed) ? -1 : newSeed
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Same seed = same response (if supported). Leave empty for random.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Button {
                text: qsTr("Reset to Defaults")
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