// Copyright (C) 2024 - 2026 Conrad Hübler <Conrad.Huebler@gmx.net>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import Sailfish.Silica 1.0

// Claude Generated: Page shown when an image is shared/opened with SailorAI.
// User chooses whether to describe the photo or translate text from it.
Page {
    id: page

    property string imagePath: ""

    signal actionSelected(string prompt, string name)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Use photo in AI chat")
            }

            Image {
                source: imagePath.length > 0 ? "file://" + imagePath : ""
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.min(width, page.height * 0.4)
                fillMode: Image.PreserveAspectFit
                asynchronous: true

                BusyIndicator {
                    anchors.centerIn: parent
                    running: parent.status === Image.Loading
                    size: BusyIndicatorSize.Medium
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("What would you like to do with this photo?")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
            }

            // Claude Generated: action buttons styled like the start-page quick actions.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.itemSizeMedium

                Column {
                    spacing: Theme.paddingSmall
                    IconButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon.source: "image://theme/icon-m-image"
                        onClicked: {
                            page.actionSelected(
                                qsTr("Please describe this photo in %1.").arg(Qt.locale().nativeLanguageName),
                                "Describe photo")
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Describe")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.primaryColor
                    }
                }

                Column {
                    spacing: Theme.paddingSmall
                    IconButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon.source: "image://theme/icon-m-region"
                        onClicked: {
                            page.actionSelected(
                                qsTr("Please translate all text visible in this photo to %1.").arg(Qt.locale().nativeLanguageName),
                                "Translate photo")
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Translate")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.primaryColor
                    }
                }
            }
        }
    }
}
