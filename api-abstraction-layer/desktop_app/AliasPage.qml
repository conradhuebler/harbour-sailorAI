import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Page {
    id: aliasPage
    title: qsTr("Providers")

    property var api: null

    ListModel {
        id: aliasListModel
    }

    function refreshAliases() {
        if (!api) return;
        aliasListModel.clear();
        var ids = api.getAliasIds();
        for (var i = 0; i < ids.length; i++) {
            var alias = api.getAlias(ids[i]);
            var status = api.getAvailability(ids[i]);
            var models = api.getAliasModels(ids[i]);
            aliasListModel.append({
                "aliasId": ids[i],
                "aliasName": alias ? alias.name : ids[i],
                "aliasType": alias ? alias.type : "",
                "aliasUrl": alias ? alias.url : "",
                "hasKey": alias ? Boolean(alias.api_key && alias.api_key.length > 0) : false,
                "isDefault": alias ? alias.isDefault : false,
                "status": status,
                "modelCount": models.length
            });
        }
    }

    ListView {
        id: aliasList
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
        clip: true
        model: aliasListModel

        delegate: Rectangle {
            width: aliasList.width
            height: delegateCol.height + 16
            border.width: 1
            border.color: "#ddd"
            radius: 4

            Column {
                id: delegateCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    width: parent.width

                    Text {
                        text: model.aliasName
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Text {
                        text: "(" + model.aliasType + ")"
                        color: "#888"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: model.hasKey ? "Key: ***" : "No key"
                        color: "#888"
                        font.pixelSize: 11
                    }

                    Button {
                        text: "Edit"
                        font.pixelSize: 11
                        onClicked: editDialog.openForAlias(model.aliasId)
                    }

                    Button {
                        text: "Delete"
                        font.pixelSize: 11
                        enabled: !model.isDefault
                        onClicked: {
                            if (api) {
                                api.removeAlias(model.aliasId);
                                refreshAliases();
                            }
                        }
                    }
                }

                Text {
                    text: model.aliasUrl
                    color: "#666"
                    font.pixelSize: 11
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: {
                            switch (model.status) {
                                case "available": return "#4caf50";
                                case "checking": return "#ff9800";
                                case "no_key": return "#9e9e9e";
                                case "error":
                                case "timeout": return "#f44336";
                                default: return "#bdbdbd";
                            }
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: model.status || "unchecked"
                        color: "#888"
                        font.pixelSize: 11
                    }

                    Text {
                        text: model.modelCount + " models"
                        color: "#888"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    RoundButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        text: "+"
        font.pixelSize: 24
        onClicked: addDialog.open()
    }

    Dialog {
        id: addDialog
        title: "Add Provider Alias"
        modal: true
        width: 400

        property var providerTypes: api ? api.getProviderIds() : []

        onAboutToShow: {
            addTypeCombo.model = addDialog.providerTypes;
        }

        Column {
            width: parent.width
            spacing: 8

            TextField {
                id: addId
                width: parent.width
                placeholderText: "Alias ID (unique, e.g. my_ollama)"
            }

            TextField {
                id: addName
                width: parent.width
                placeholderText: "Display name (e.g. My Ollama)"
            }

            ComboBox {
                id: addTypeCombo
                width: parent.width
                model: addDialog.providerTypes
            }

            TextField {
                id: addUrl
                width: parent.width
                placeholderText: "Base URL (leave empty for default)"
            }

            TextField {
                id: addApiKey
                width: parent.width
                placeholderText: "API Key"
                echoMode: TextInput.Password
            }

            TextField {
                id: addModel
                width: parent.width
                placeholderText: "Favorite model (optional)"
            }
        }

        onAccepted: {
            if (api && addId.text.length > 0) {
                var typeIdx = addTypeCombo.currentIndex;
                var typeStr = addDialog.providerTypes.length > typeIdx ? addDialog.providerTypes[typeIdx] : "openai";
                var newAliasId = addId.text;
                api.addAlias(
                    newAliasId,
                    addName.text || addId.text,
                    typeStr,
                    addUrl.text,
                    addApiKey.text,
                    "",
                    "",
                    10000,
                    addModel.text,
                    false
                );
                refreshAliases();

                // Auto-fetch models and check availability after adding
                api.fetchModelsForAlias(newAliasId, function(models) {
                    console.log("Fetched " + models.length + " models for " + newAliasId);
                    refreshAliases();
                }, function(error) {
                    console.log("Model fetch failed for " + newAliasId + ": " + error);
                });
                api.checkAvailability(newAliasId, function(available, status) {
                    console.log("Availability for " + newAliasId + ": " + status);
                    refreshAliases();
                });

                addId.text = "";
                addName.text = "";
                addUrl.text = "";
                addApiKey.text = "";
                addModel.text = "";
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel
    }

    Dialog {
        id: editDialog
        title: "Edit Provider Alias"
        modal: true
        width: 400

        property string editAliasId: ""

        function openForAlias(aliasId) {
            editAliasId = aliasId;
            var alias = api ? api.getAlias(aliasId) : null;
            if (alias) {
                editName.text = alias.name;
                editUrl.text = alias.url;
                editApiKey.text = alias.api_key;
            }
            open();
        }

        Column {
            width: parent.width
            spacing: 8

            Text {
                text: "Editing: " + editDialog.editAliasId
                font.bold: true
            }

            TextField {
                id: editName
                width: parent.width
                placeholderText: "Display name"
            }

            TextField {
                id: editUrl
                width: parent.width
                placeholderText: "Base URL"
            }

            TextField {
                id: editApiKey
                width: parent.width
                placeholderText: "API Key"
                echoMode: TextInput.Password
            }
        }

        onAccepted: {
            if (api && editDialog.editAliasId) {
                api.updateAlias(
                    editDialog.editAliasId,
                    editName.text,
                    editUrl.text,
                    editApiKey.text,
                    "",
                    0,
                    "",
                    undefined
                );
                refreshAliases();
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel
    }

    onApiChanged: {
        refreshAliases();
    }
}