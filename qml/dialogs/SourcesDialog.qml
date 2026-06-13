import QtQuick 2.0
import Sailfish.Silica 1.0

// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Claude Generated. Popup dialog that lists the sources collected by web tools.

Dialog {
    id: dialog

    property var sources: []
    property string title: qsTr("Sources")

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
                visible: sourceRepeater.count === 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("No sources available.")
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Repeater {
                    id: sourceRepeater
                    model: dialog.sources

                    BackgroundItem {
                        width: parent.width
                        height: sourceRow.height + Theme.paddingMedium

                        Row {
                            id: sourceRow
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.paddingMedium

                            Label {
                                id: numberLabel
                                text: (index + 1) + "."
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                width: parent.width - numberLabel.width - Theme.paddingMedium
                                text: modelData
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
                            var url = String(modelData).replace(/^.* — /, "")
                            if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0)
                                Qt.openUrlExternally(url)
                        }
                    }
                }
            }
        }
    }
}
