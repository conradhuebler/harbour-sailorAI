// Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import Sailfish.Silica 1.0

// Claude Generated: Page shown when an image is shared/opened with SailorAI.
// User chooses whether to describe the photo or translate text from it.
Page {
    id: page

    property string imagePath: ""

    signal actionSelected(string prompt)

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

            Button {
                text: qsTr("Describe photo")
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    page.actionSelected(
                        qsTr("Please describe this photo in %1.").arg(Qt.locale().nativeLanguageName))
                    pageStack.pop()
                }
            }

            Button {
                text: qsTr("Translate text from photo")
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    page.actionSelected(
                        qsTr("Please translate all text visible in this photo to %1.").arg(Qt.locale().nativeLanguageName))
                    pageStack.pop()
                }
            }
        }
    }
}
