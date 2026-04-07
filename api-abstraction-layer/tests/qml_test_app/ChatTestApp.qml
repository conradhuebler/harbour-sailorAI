import QtQuick 2.12
import QtQuick.Controls 2.5
import "resources/chat_logic.js" as Chat

ApplicationWindow {
    visible: true
    width: 640
    height: 560
    title: qsTr("API‑Abstraction‑Demo‑Chat")

    ListModel { id: msgModel }

    Column {
        anchors.fill: parent
        spacing: 8
        padding: 8

        // Debug: show loaded providers
        Text {
            text: "Providers: " + Chat.availableProviders().join(", ")
            color: "gray"
            wrapMode: Text.Wrap
        }

        ComboBox {
            id: providerBox
            model: Chat.availableProviders()
            onCurrentTextChanged: {
                modelBox.model = Chat.availableModels(providerBox.currentText)
            }
        }

        // Model‑Auswahl
        ComboBox {
            id: modelBox
            model: []
        }

        // Chat‑Anzeige
        ListView {
            id: chatView
            model: msgModel
            delegate: Text {
                text: role + ": " + content
                wrapMode: Text.Wrap
                color: role === "assistant" ? "steelblue" : "black"
            }
            height: parent.height - inputRow.height - 100
            clip: true
        }

        // Eingabereihe
        Row {
            id: inputRow
            spacing: 4
            width: parent.width

            TextField {
                id: userInput
                placeholderText: "Nachricht eingeben…"
                width: parent.width - sendBtn.width - 20
            }

            Button {
                id: sendBtn
                text: "Senden"
                onClicked: {
                    const prov = providerBox.currentText
                    const mdl  = modelBox.currentText
                    const txt  = userInput.text
                    if (!txt) return
                    msgModel.append({role:"user", content:txt})
                    userInput.text = ""

                    // API‑Aufruf (Streaming‑Callback)
                    Chat.sendMessage(prov, mdl, txt,
                        function(chunk){ // streaming piece
                            var last = msgModel.get(msgModel.count-1)
                            if (last && last.role === "assistant")
                                last.content += chunk
                            else
                                msgModel.append({role:"assistant", content:chunk})
                        },
                        function(){ /* finished */ },
                        function(err){ msgModel.append({role:"error", content:err}) })
                }
            }
        }
    }
}
