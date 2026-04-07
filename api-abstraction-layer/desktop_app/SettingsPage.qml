import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Page {
    id: settingsPage
    title: qsTr("Settings")

    property var api: null

    ListModel {
        id: providerListModel
    }

    function refreshProviders() {
        if (!api) return;
        providerListModel.clear();
        var ids = api.getProviderIds();
        for (var i = 0; i < ids.length; i++) {
            var provider = api.getProvider(ids[i]);
            providerListModel.append({
                "providerId": ids[i],
                "providerName": provider ? provider.name : ids[i],
                "providerUrl": provider ? provider.base_url : "",
                "streaming": provider ? provider.features.supportsStreaming : false,
                "images": provider ? provider.features.supportsImages : false,
                "thinking": provider ? provider.features.supportsThinking : false,
                "defaultModels": provider && provider.defaultModels ? provider.defaultModels.join(", ") : ""
            });
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        GroupBox {
            title: "Debug Logging"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                ComboBox {
                    id: debugLevelCombo
                    model: ["None (0)", "Normal (1)", "Informative (2)", "Verbose (3)"]
                    currentIndex: 1

                    onActivated: {
                        if (typeof setDebugLevel === 'function') {
                            setDebugLevel(currentIndex);
                        }
                    }
                }

                Text {
                    text: "Controls debug output verbosity.\n0=No logging  1=Errors  2=API calls  3=Streaming"
                    color: "#888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        GroupBox {
            title: "Provider Types (from config)"
            Layout.fillWidth: true

            ListView {
                id: providerList
                width: parent.width
                height: contentHeight
                model: providerListModel
                spacing: 4

                delegate: Rectangle {
                    width: providerList.width
                    height: providerInfo.height + 12
                    color: "#f9f9f9"
                    radius: 4

                    Column {
                        id: providerInfo
                        anchors.fill: parent
                        anchors.margins: 6

                        Text {
                            text: model.providerName + " [" + model.providerId + "]"
                            font.bold: true
                        }

                        Text {
                            text: "URL: " + model.providerUrl
                            color: "#888"
                            font.pixelSize: 11
                        }

                        Text {
                            text: {
                                var features = [];
                                if (model.streaming) features.push("Streaming");
                                if (model.images) features.push("Images");
                                if (model.thinking) features.push("Thinking");
                                return "Features: " + (features.length > 0 ? features.join(", ") : "none");
                            }
                            color: "#666"
                            font.pixelSize: 11
                        }

                        Text {
                            text: "Models: " + (model.defaultModels || "fetch from API")
                            color: "#888"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        GroupBox {
            title: "About"
            Layout.fillWidth: true

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "SailorAI API Abstraction Layer"
                    font.bold: true
                }
                Text {
                    text: "Desktop Proof-of-Concept v0.1"
                    color: "#888"
                }
                Text {
                    text: "Provider-agnostic REST API for LLM providers.\nSupports: OpenAI, Anthropic, Gemini, Ollama + custom providers"
                    color: "#888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    onApiChanged: {
        refreshProviders();
    }
}