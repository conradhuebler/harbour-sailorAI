import QtQuick 2.0
import Sailfish.Silica 1.0

// Copyright (C) 2024 - 2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Claude Generated. About page with app status, credits and contact links.

Page {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        VerticalScrollDecorator {}

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("About SailorAI")
            }

            SectionHeader {
                text: qsTr("Application")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("SailorAI is an AI chat interface for Sailfish OS supporting multiple LLM providers with real-time streaming.")
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Version %1").arg("0.1")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            SectionHeader {
                text: qsTr("Status")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Actively developed with agentic coding (Claude Code). Core chat, multi-provider support, streaming, image/document upload, Markdown rendering, web tools and conversation history are implemented. Some features are still evolving.")
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Best tested with remote ollama.com endpoints; other providers are supported but less regularly exercised.")
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader {
                text: qsTr("Supported providers")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("• OpenAI-compatible APIs") + "\n" +
                      qsTr("• Anthropic Claude") + "\n" +
                      qsTr("• Google Gemini") + "\n" +
                      qsTr("• Ollama (local or remote)")
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader {
                text: qsTr("Contact")
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: Qt.openUrlExternally("mailto:Conrad.Huebler@gmx.net")

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Email") + ": Conrad.Huebler@gmx.net"
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: Qt.openUrlExternally("https://github.com/conradhuebler/harbour-sailorAI")

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Source code on GitHub")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: Qt.openUrlExternally("https://github.com/conradhuebler/harbour-sailorAI/issues")

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    text: qsTr("Report an issue")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
