// Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/LLMApi.js" as LLMApi

Dialog {
    id: dialog

    property string title: "Models"
    property string aliasId: ""
    property bool canRefresh: false

    canAccept: false

    property var _sortedModels: []

    function updateModelList() {
        var alias = LLMApi.getProviderAlias(aliasId);
        var models = LLMApi.getAliasModels(aliasId);

        if (!alias || models.length === 0) {
            _sortedModels = [];
            dialogHeader.title = dialog.title;
            return;
        }

        dialogHeader.title = alias.name + " Models (" + models.length + ")";

        var favorites = LLMApi.getAliasFavoriteModels(aliasId);
        var favoriteList = [];
        var otherList = [];

        for (var i = 0; i < models.length; i++) {
            if (favorites.indexOf(models[i]) !== -1) {
                favoriteList.push(models[i]);
            } else {
                otherList.push(models[i]);
            }
        }

        // Favorites sorted by user preference order, others alphabetically
        favoriteList.sort(function(a, b) {
            return favorites.indexOf(a) - favorites.indexOf(b);
        });
        otherList.sort();

        // Build model list with section markers
        var result = [];
        for (var j = 0; j < favoriteList.length; j++) {
            result.push({name: favoriteList[j], isFavorite: true});
        }
        for (var k = 0; k < otherList.length; k++) {
            result.push({name: otherList[k], isFavorite: false});
        }

        _sortedModels = result;
    }

    Component.onCompleted: {
        updateModelList();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                id: dialogHeader
                title: dialog.title
                acceptText: ""
                cancelText: "Close"
            }

            SilicaListView {
                id: modelListView
                width: parent.width
                height: contentHeight
                interactive: false

                model: _sortedModels

                section.property: "isFavorite"
                section.delegate: SectionHeader {
                    text: section === "true" ? "Favorites" : "All Models"
                    visible: _sortedModels.length > 0
                }

                delegate: ListItem {
                    width: modelListView.width
                    contentHeight: itemColumn.height + Theme.paddingSmall

                    Column {
                        id: itemColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: Theme.horizontalPageMargin
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }

                        Label {
                            width: parent.width
                            text: (modelData.isFavorite ? "★ " : "• ") + modelData.name
                            color: modelData.isFavorite ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            text: LLMApi.getModelInfo(aliasId, modelData.name)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                            height: visible ? implicitHeight : 0
                        }
                    }
                }

                ViewPlaceholder {
                    enabled: _sortedModels.length === 0
                    text: "No models loaded"
                    hintText: canRefresh ? "Tap 'Refresh Models' to fetch from provider" : ""
                }
            }

            Button {
                visible: canRefresh
                text: "Refresh Models"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    dialogHeader.title = "Fetching models…";
                    LLMApi.checkAliasAvailability(aliasId, function(available, status) {
                        if (available) {
                            LLMApi.fetchModelsForAlias(aliasId);
                            var timer = Qt.createQmlObject(
                                "import QtQuick 2.0; Timer { interval: 3000; running: true; repeat: false }",
                                dialog, "updateTimer"
                            );
                            timer.triggered.connect(function() {
                                updateModelList();
                                timer.destroy();
                            });
                        } else {
                            dialogHeader.title = dialog.title;
                        }
                    });
                }
            }

            Item { height: Theme.paddingLarge }
        }
    }
}
