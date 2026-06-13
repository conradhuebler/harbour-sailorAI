import QtQuick 2.0
import Sailfish.Silica 1.0

// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Claude Generated. Popup dialog that lists the web-tool calls (search / read)
// that were collapsed in a chat bubble.

Dialog {
    id: dialog

    property var toolCalls: []
    property string title: qsTr("Web-Tools log")

    canAccept: false

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: dialog.title
                cancelText: qsTr("Close")
            }

            Label {
                visible: toolRepeater.count === 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("No web-tool calls recorded.")
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Repeater {
                    id: toolRepeater
                    model: dialog.toolCalls

                    BackgroundItem {
                        width: parent.width
                        height: toolRow.height + Theme.paddingMedium

                        Row {
                            id: toolRow
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.paddingMedium

                            Label {
                                id: iconLabel
                                text: modelData.type === "search" ? "🔍" : "📄"
                                font.pixelSize: Theme.fontSizeMedium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                width: parent.width - iconLabel.width - Theme.paddingMedium
                                text: modelData.value
                                color: Theme.primaryColor
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                                linkColor: Theme.highlightColor
                                onLinkActivated: {
                                    if (link.indexOf("http://") === 0 || link.indexOf("https://") === 0)
                                        Qt.openUrlExternally(link)
                                }
                            }
                        }

                        onClicked: {
                            if (modelData.value.indexOf("http://") === 0 || modelData.value.indexOf("https://") === 0)
                                Qt.openUrlExternally(modelData.value)
                        }
                    }
                }
            }
        }
    }
}
