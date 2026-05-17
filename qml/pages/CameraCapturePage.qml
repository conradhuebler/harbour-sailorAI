// Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.0

// Claude Generated: Camera viewfinder page for photo capture actions
Page {
    id: page

    signal photoCaptured(string imagePath)

    allowedOrientations: Orientation.Portrait

    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        focus.focusMode: Camera.FocusContinuous

        imageCapture {
            onImageSaved: {
                // Emit signal only — caller handles pageStack navigation after pop
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

    Label {
        id: errorLabel
        visible: false
        text: qsTr("Camera not available")
        color: Theme.errorColor
        font.pixelSize: Theme.fontSizeLarge
        anchors.centerIn: parent
    }

    Button {
        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge * 2
            horizontalCenter: parent.horizontalCenter
        }
        text: qsTr("Take photo")
        onClicked: {
            var timestamp = new Date().getTime()
            camera.imageCapture.captureToLocation(
                "/home/defaultuser/Pictures/sailorAI_" + timestamp + ".jpg")
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) camera.start()
        if (status === PageStatus.Deactivating) camera.stop()
    }
}
