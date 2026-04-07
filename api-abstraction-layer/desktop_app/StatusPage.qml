import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Page {
    id: statusPage
    title: qsTr("Status")

    property var api: null

    ListModel {
        id: statusListModel
    }

    function refreshStatus() {
        if (!api) return;
        statusListModel.clear();
        var ids = api.getAliasIds();
        for (var i = 0; i < ids.length; i++) {
            var alias = api.getAlias(ids[i]);
            var status = api.getAvailability(ids[i]);
            var modelCount = api.getAliasModels(ids[i]).length;
            statusListModel.append({
                "aliasId": ids[i],
                "aliasName": alias ? alias.name : ids[i],
                "aliasType": alias ? alias.type : "",
                "aliasUrl": alias ? alias.url : "",
                "status": status,
                "modelCount": modelCount
            });
        }
    }

    function checkSingleAlias(aliasId) {
        if (!api) return;
        api.checkAvailability(aliasId, function(available, status) {
            refreshStatus();
        });
    }

    function checkAllAliases() {
        if (!api) return;
        var ids = api.getAliasIds();
        for (var i = 0; i < ids.length; i++) {
            checkSingleAlias(ids[i]);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: "Check All"
                enabled: api && api.getAliasIds().length > 0
                onClicked: checkAllAliases()
            }

            Button {
                text: "Refresh"
                onClicked: refreshStatus()
            }

            Text {
                text: api ? (api.getAliasIds().length + " provider(s)") : "No API"
                color: "#888"
            }
        }

        ListView {
            id: statusList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            clip: true
            model: statusListModel

            delegate: Rectangle {
                width: statusList.width
                height: 70
                border.width: 1
                border.color: "#ddd"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
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
                    }

                    Column {
                        Layout.fillWidth: true

                        Text {
                            text: model.aliasName + " (" + model.aliasType + ")"
                            font.bold: true
                        }

                        Text {
                            text: model.aliasUrl
                            color: "#888"
                            font.pixelSize: 11
                        }

                        Text {
                            text: model.modelCount + " models cached"
                            color: "#888"
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        text: model.status
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
                        font.bold: true
                    }

                    Button {
                        text: "Check"
                        font.pixelSize: 11
                        onClicked: checkSingleAlias(model.aliasId)
                    }
                }
            }
        }
    }

    onApiChanged: {
        refreshStatus();
    }
}