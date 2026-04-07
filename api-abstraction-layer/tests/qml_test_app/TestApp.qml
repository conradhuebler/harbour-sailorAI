import QtQuick 2.0
import QtQuick.Controls 2.0
import "api_tests_qml.js" as ApiTests   // ← the test framework

ApplicationWindow {
    visible: true
    width: 640
    height: 560
    title: qsTr("API‑Abstraction‑Layer QML Test App")

    // -----------------------------------------------------------------
    // UI layout
    // -----------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: 20

        Button {
            id: runBtn
            text: qsTr("Run All Tests")
            onClicked: {
                console.log("--- Test run started ---")
                // Run the full test suite (returns true = all passed)
                var success = ApiTests.runAllTests()
                resultLabel.text = success ?
                                      "✅ All tests passed!" :
                                      "❌ Some tests failed"
            }
        }

        Label {
            id: resultLabel
            text: ""
            font.pixelSize: 20
            color: text.startsWith("✅") ? "green" : "red"
        }

        // Scrollable log output
        TextArea {
            id: logArea
            readOnly: true
            wrapMode: TextArea.Wrap
            width: parent.width * 0.9
            height: parent.height * 0.55
            font.family: "monospace"
            font.pixelSize: 12
            background: Rectangle { color: "#fafafa" }
        }
    }

    // -----------------------------------------------------------------
    // Capture console.log() output and forward it to the UI
    // -----------------------------------------------------------------
    Component.onCompleted: {
        // Preserve the original console.log implementation
        var originalLog = console.log
        console.log = function(msg) {
            originalLog(msg)                      // still goes to stdout
            logArea.append(msg + "\n")            // show inside the app
            // optional: auto‑scroll to bottom
            logArea.position = logArea.length
        }
    }
}
