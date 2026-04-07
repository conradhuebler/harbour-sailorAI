import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/api_tests_qml.js" as ApiTests

Page {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            PageHeader {
                title: "API Abstraction Tests"
            }

            Label {
                text: "Click button below to run comprehensive tests for the API abstraction layer."
                wrapMode: Text.WordWrap
                width: parent.width - Theme.horizontalPageMargin * 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.primaryColor
            }

            Button {
                text: "Run All Tests"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    testResults.visible = true
                    runningIndicator.visible = true
                    resultLabel.text = "Running tests..."
                    statusLabel.text = ""

                    // Use Qt.callLater to ensure UI updates before test execution
                    Qt.callLater(function() {
                        var success = ApiTests.runAllTests();

                        runningIndicator.visible = false

                        if (success) {
                            resultLabel.text = "All tests passed! ✓"
                            resultLabel.color = Theme.highlightColor
                        } else {
                            resultLabel.text = "Some tests failed! ✗"
                            resultLabel.color = Theme.errorColor
                        }

                        // Show summary
                        var summary = "Test execution completed.\n\nCheck console logs for detailed results.\n\nThe tests cover:\n• Configuration loading & validation\n• Provider configuration validation\n• Endpoint URL building\n• Authentication header generation\n• Feature detection\n• Request building & data formatting\n• Error handling\n• Edge cases\n• Cache functionality"
                        statusLabel.text = summary
                    })
                }
            }

            BusyIndicator {
                id: runningIndicator
                size: BusyIndicatorSize.Small
                anchors.horizontalCenter: parent.horizontalCenter
                running: false
                visible: false
            }

            Rectangle {
                id: testResults
                visible: false
                width: parent.width - Theme.horizontalPageMargin * 2
                height: childrenRect.height + Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.secondaryHighlightColor
                radius: Theme.paddingSmall

                Column {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.paddingLarge
                    }
                    spacing: Theme.paddingMedium

                    Label {
                        id: resultLabel
                        text: ""
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        id: statusLabel
                        text: ""
                        wrapMode: Text.WordWrap
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            SectionHeader {
                text: "Individual Test Suites"
            }

            Column {
                width: parent.width - Theme.horizontalPageMargin * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Label {
                    text: "• Configuration Loading Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Provider Configuration Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Endpoint Building Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Authentication Header Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Feature Detection Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Request Building Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Error Handling Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Edge Cases Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Cache Functionality Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Configuration Validation Tests"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }
            }

            SectionHeader {
                text: "Test Coverage"
            }

            Label {
                text: "These tests validate the API abstraction layer works correctly across all supported providers (OpenAI, Anthropic, Gemini, Ollama) and ensures proper URL construction, authentication, and request formatting."
                wrapMode: Text.WordWrap
                width: parent.width - Theme.horizontalPageMargin * 2
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            SectionHeader {
                text: "Provider Support"
            }

            Column {
                width: parent.width - Theme.horizontalPageMargin * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Label {
                    text: "• OpenAI Compatible (Streaming + Images)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Anthropic Claude (Streaming + Thinking)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Google Gemini (Streaming + Images + Thinking)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Ollama Local (Streaming)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }

                Label {
                    text: "• Custom Providers (Configurable)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primaryColor
                }
            }
        }
    }
}