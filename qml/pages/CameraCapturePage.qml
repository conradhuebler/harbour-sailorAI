// Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import QtMultimedia 5.0

// Claude Generated: Camera viewfinder page for photo capture actions
Page {
    id: page

    signal photoCaptured(string imagePath)

    // Holds a gallery-picked path until CameraCapturePage is Active again (picker fully gone)
    property string _pendingGalleryImage: ""

    allowedOrientations: Orientation.Portrait

    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        focus.focusMode: Camera.FocusContinuous

        imageCapture {
            onImageSaved: {
                photoCaptured(path)
            }
            onCaptureFailed: {
                console.log("CameraCapturePage: Capture failed:", requestId, message)
                errorLabel.visible = true
            }
        }
    }

    VideoOutput {
        source: camera
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // Subtle dark gradient so bottom controls stay readable over any scene
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: bottomBar.height + Theme.paddingLarge * 4
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#99000000" }
        }
    }

    Label {
        id: errorLabel
        visible: false
        text: qsTr("Camera not available")
        color: Theme.errorColor
        font.pixelSize: Theme.fontSizeLarge
        anchors.centerIn: parent
    }

    Component {
        id: imagePickerComponent
        ImagePickerPage {}
    }

    // Bottom control bar: [gallery] ——— [shutter] ——— [spacer]
    Row {
        id: bottomBar
        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge * 2
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Theme.itemSizeLarge
        height: Theme.itemSizeExtraLarge

        // Gallery picker button
        Rectangle {
            width: Theme.itemSizeMedium
            height: Theme.itemSizeMedium
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.18)
            border.color: Qt.rgba(1, 1, 1, 0.5)
            border.width: 2
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                source: "image://theme/icon-m-image"
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var picker = pageStack.push(imagePickerComponent)
                    picker.selectedContentChanged.connect(function() {
                        if (!picker.selectedContent) return
                        var path = picker.selectedContent.toString()
                        if (path.indexOf("file://") === 0) path = path.substring(7)
                        _pendingGalleryImage = path
                    })
                }
            }
        }

        // Shutter button — classic double-ring style
        Rectangle {
            id: shutterOuter
            width: Theme.itemSizeExtraLarge
            height: Theme.itemSizeExtraLarge
            radius: width / 2
            color: "transparent"
            border.color: "white"
            border.width: 3
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.paddingLarge
                height: parent.width - Theme.paddingLarge
                radius: width / 2
                color: shutterMouse.pressed ? Qt.rgba(1, 1, 1, 0.7) : "white"

                Behavior on color { ColorAnimation { duration: 80 } }
            }

            MouseArea {
                id: shutterMouse
                anchors.fill: parent
                onClicked: {
                    var timestamp = new Date().getTime()
                    camera.imageCapture.captureToLocation(
                        "/home/defaultuser/Pictures/sailorAI_" + timestamp + ".jpg")
                }
            }
        }

        // Symmetry spacer (same size as gallery button)
        Item {
            width: Theme.itemSizeMedium
            height: Theme.itemSizeMedium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            camera.start()
            if (_pendingGalleryImage !== "") {
                var path = _pendingGalleryImage
                _pendingGalleryImage = ""
                photoCaptured(path)
            }
        }
        if (status === PageStatus.Deactivating) camera.stop()
    }
}
