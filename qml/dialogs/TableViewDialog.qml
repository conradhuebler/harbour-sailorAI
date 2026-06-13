import QtQuick 2.0
import Sailfish.Silica 1.0

// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Claude Generated. Popup dialog that renders a single Markdown table cleanly
// with horizontal scrolling, so wide tables stay readable without breaking the
// chat bubble layout. A slider lets the user dynamically enlarge the table so
// cell text wraps instead of being squeezed into tiny columns.

Dialog {
    id: dialog

    property string tableHtml: ""
    property string originalMessage: ""
    property int tableIndex: 0

    canAccept: false

    // Claude Generated: column-count hint used to compute a sensible default
    // table width (roughly one readable column width per cell).
    property int _columnCount: {
        var matches = tableHtml.match(/<th>/g)
        return matches ? matches.length : 1
    }

    // Claude Generated: default width gives each column enough room to wrap.
    property int _defaultTableWidth: Math.max(dialog.width,
                                                Theme.itemSizeHuge * 1.5 * _columnCount)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Table")
                cancelText: qsTr("Close")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Drag the slider to make the table wider or narrower. Swipe left/right to view all columns.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                wrapMode: Text.WordWrap
            }

            // Claude Generated: dynamic width control for the table.
            Slider {
                id: widthSlider
                width: parent.width
                minimumValue: dialog.width
                maximumValue: Math.max(dialog.width * 2.5, dialog._defaultTableWidth * 1.5)
                value: dialog._defaultTableWidth
                stepSize: Theme.itemSizeSmall
                label: qsTr("Table width")
            }

            Flickable {
                id: tableFlickable
                width: parent.width
                height: tableContainer.height + Theme.paddingMedium
                contentWidth: tableContainer.width
                contentHeight: tableContainer.height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Rectangle {
                    id: tableContainer
                    width: widthSlider.value
                    height: tableLabel.height
                    color: "transparent"

                    Label {
                        id: tableLabel
                        width: parent.width
                        text: dialog.tableHtml
                        textFormat: Text.RichText
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        linkColor: Theme.highlightColor
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: {
                            if (link.indexOf("http://") === 0 || link.indexOf("https://") === 0)
                                Qt.openUrlExternally(link)
                        }
                    }
                }

                HorizontalScrollDecorator {
                    anchors.bottom: parent.bottom
                }
            }
        }
    }
}
