import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.Configuration 1.0
import "../js/ExportFunctions.js" as ExportFunctions
import "../js/DebugLogger.js" as DebugLogger

// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>

Dialog {
    id: exportDialog

    property int conversationId: -1
    property string conversationName: ""
    property string format: "markdown"
    property string exportText: ""
    property string targetDir: ""
    property string lastSavedPath: ""

    canAccept: exportText.length > 0 && targetDir.length > 0
    onAccepted: performSave()

    ConfigurationValue {
        id: exportDirConfig
        key: "/SailorAI/export_dir"
        defaultValue: ""
    }

    Component.onCompleted: {
        targetDir = exportDirConfig.value && exportDirConfig.value.length > 0
                    ? exportDirConfig.value
                    : StandardPaths.documents
        DebugLogger.logInfo("ExportDialog", "opened: convId=" + conversationId
                            + " convName='" + conversationName + "'"
                            + " targetDir=" + targetDir)
        regenerateExport()
    }

    onFormatChanged: regenerateExport()

    function regenerateExport() {
        if (conversationId > 0 && app && app.database) {
            var msgs = app.database.loadMessages(conversationId)
            exportText = ExportFunctions.formatMessages(msgs, format)
            DebugLogger.logInfo("ExportDialog", "regenerated: msgs=" + msgs.length
                                + " textLen=" + exportText.length + " format=" + format)
        } else {
            exportText = ""
        }
    }

    // For local file:// URLs, Qt5 XHR returns status 0 on success (no HTTP layer).
    // Treat 0 and 200 alike; a real failure throws.
    function pathExists(path) {
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("GET", "file://" + path, false)
            xhr.send()
            return xhr.responseText !== undefined && xhr.responseText.length > 0
                   && (xhr.status === 200 || xhr.status === 0)
        } catch (e) {
            return false
        }
    }

    function performSave() {
        if (!exportText) return
        var ext = format === "markdown" ? "md" : "txt"
        var base = ExportFunctions.makeFilenameBase(conversationName)
        var path = ExportFunctions.findFreePath(targetDir, base, ext, pathExists)
        var xhr = new XMLHttpRequest()
        var putException = ""
        try {
            xhr.open("PUT", "file://" + path, false)
            xhr.setRequestHeader("Content-Type",
                format === "markdown" ? "text/markdown; charset=utf-8" : "text/plain; charset=utf-8")
            xhr.setRequestHeader("Content-Length", String(exportText.length))
            xhr.send(exportText)
        } catch (e) {
            putException = String(e)
        }
        if (putException === "") {
            exportDirConfig.value = targetDir
            lastSavedPath = path
            DebugLogger.logInfo("ExportDialog", "Saved to " + path)
        } else {
            DebugLogger.logError("ExportDialog", "Save failed for " + path + ": " + putException)
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        PullDownMenu {
            MenuItem {
                text: qsTr("Copy to clipboard")
                enabled: exportDialog.exportText.length > 0
                onClicked: Clipboard.text = exportDialog.exportText
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Export Conversation")
                acceptText: qsTr("Save")
            }

            ComboBox {
                id: formatBox
                label: qsTr("Format")
                currentIndex: format === "markdown" ? 0 : 1
                menu: ContextMenu {
                    MenuItem { text: "Markdown"; onClicked: format = "markdown" }
                    MenuItem { text: qsTr("Plain text"); onClicked: format = "text" }
                }
            }

            TextField {
                id: dirField
                width: parent.width
                label: qsTr("Save to")
                text: exportDialog.targetDir
                readOnly: true
            }

            Button {
                text: qsTr("Change folder...")
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    var picker = pageStack.push("Sailfish.Pickers.FolderPickerDialog", {
                        "title": qsTr("Select export folder"),
                        "path": exportDialog.targetDir || StandardPaths.documents
                    })
                    picker.selectedPathChanged.connect(function() {
                        if (picker.selectedPath && picker.selectedPath.length > 0) {
                            exportDialog.targetDir = picker.selectedPath
                        }
                    })
                }
            }

            TextArea {
                width: parent.width
                readOnly: true
                text: exportDialog.exportText
                wrapMode: TextEdit.WrapAnywhere
                label: qsTr("Preview")
            }
        }
    }
}
