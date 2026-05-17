import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import "../js/ExportFunctions.js" as ExportFunctions

// Copyright (C) 2024-2025 Conrad Hübler <Conrad.Huebler@gmx.net>

Dialog {
    id: exportDialog

    property int conversationId: -1
    property string format: "markdown"
    property string exportText: ""

    onConversationIdChanged: regenerateExport()
    onFormatChanged: regenerateExport()

    function regenerateExport() {
        if (conversationId > 0 && app && app.database) {
            var msgs = app.database.loadMessages(conversationId)
            exportText = ExportFunctions.formatMessages(msgs, format)
        } else {
            exportText = ""
        }
    }

    Column {
        width: parent.width
        spacing: Theme.paddingMedium

        DialogHeader {
            title: qsTr("Export Conversation")
        }

        ComboBox {
            id: formatBox
            label: qsTr("Format")
            currentIndex: format === "markdown" ? 0 : 1
            model: ["Markdown", qsTr("Plain text")]
            onCurrentIndexChanged: {
                format = currentIndex === 0 ? "markdown" : "text"
            }
        }

        TextArea {
            id: exportArea
            width: parent.width
            readOnly: true
            text: exportDialog.exportText
            wrapMode: TextEdit.WrapAnywhere
            height: Math.min(400, contentHeight + Theme.paddingMedium)
        }

        Row {
            spacing: Theme.paddingMedium
            Button {
                text: qsTr("Copy")
                onClicked: {
                    Clipboard.text = exportDialog.exportText
                }
            }
            Button {
                text: qsTr("Share")
                enabled: exportText.length > 0
                onClicked: {
                    // Qt.labs.platform / StandardPaths is not available on Sailfish;
                    // use /tmp for a transient share file (cleared on reboot, world-writable).
                    var ext = format === "markdown" ? "md" : "txt"
                    var fileUrl = "file:///tmp/harbour-sailorAI-export." + ext
                    var xhr = new XMLHttpRequest()
                    xhr.open("PUT", fileUrl, false)
                    xhr.send(exportText)
                    pageStack.push("Sailfish.Pickers.SharePage", {
                        "source": fileUrl,
                        "mimeType": format === "markdown" ? "text/markdown" : "text/plain"
                    })
                }
            }
        }
    }
}