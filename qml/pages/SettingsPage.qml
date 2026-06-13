// Copyright (C) 2024 - 2026 Conrad Hübler <Conrad.Huebler@gmx.net>
// Settings page: provider management, photo/vision defaults, image and debug options.
// Restructured & translated with assistance from Claude (Claude Generated sections noted inline).

import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../js/LLMApi.js" as LLMApi
import "../js/DebugLogger.js" as DebugLogger

Page {
    id: settingsPage

    property string currentAliasId: ""
    property var availableAliases: []
    property var currentAlias: null

    // Configuration for debug level
    ConfigurationValue {
        id: debugLevelConfig
        key: "/SailorAI/debug_level"
        defaultValue: "1"
        onValueChanged: {
            DebugLogger.setDebugLevel(parseInt(value) || 1);
            DebugLogger.logInfo("SettingsPage", "Debug level changed to " + value);
        }
    }

    // Configuration for provider aliases
    ConfigurationValue {
        id: providerAliasesConfig
        key: "/SailorAI/provider_aliases"
        defaultValue: ""
    }

    ConfigurationValue {
        id: imageMaxDimensionConfig
        key: "/SailorAI/image_max_dimension"
        defaultValue: 1280
    }

    // Claude Generated: max Ollama web-tool iterations before a final answer is forced
    ConfigurationValue {
        id: maxToolIterConfig
        key: "/SailorAI/max_tool_iter"
        defaultValue: 8
    }

    // Claude Generated: photo-action behaviour and dedicated vision model
    ConfigurationValue {
        id: photoActionAutoSendConfig
        key: "/SailorAI/photo_action_auto_send"
        defaultValue: true
    }

    ConfigurationValue {
        id: visionProviderAliasConfig
        key: "/SailorAI/vision_provider_alias"
        defaultValue: ""
    }

    ConfigurationValue {
        id: visionModelConfig
        key: "/SailorAI/vision_model"
        defaultValue: ""
    }

    // Claude Generated: general default model for new chats (any provider)
    ConfigurationValue {
        id: defaultProviderAliasConfig
        key: "/SailorAI/default_provider_alias"
        defaultValue: ""
    }

    ConfigurationValue {
        id: defaultModelConfig
        key: "/SailorAI/default_model"
        defaultValue: ""
    }

    function loadAvailableAliases() {
        availableAliases = [];
        availableAliases = LLMApi.getProviderAliases();
        DebugLogger.logInfo("SettingsPage", "Loaded " + availableAliases.length + " provider aliases");

        if (availableAliases.length > 0) {
            if (!currentAliasId || availableAliases.indexOf(currentAliasId) === -1) {
                currentAliasId = availableAliases[0];
            }
            loadCurrentAlias();
        }
    }

    function loadCurrentAlias() {
        if (currentAliasId) {
            currentAlias = LLMApi.getProviderAlias(currentAliasId);
            if (currentAlias) {
                DebugLogger.logVerbose("SettingsPage", "Loaded alias: " + currentAliasId);
            }
        }
    }

    function showProviderModels(aliasId) {
        var alias = LLMApi.getProviderAlias(aliasId);

        if (alias) {
            // Open the favorite management dialog
            var favDialog = pageStack.push(Qt.resolvedUrl("../dialogs/FavoriteModelsDialog.qml"), {
                "selectedAliasId": aliasId
            });
            favDialog.accepted.connect(function() {
                providerAliasesConfig.value = LLMApi.saveProviderAliases();
                loadAvailableAliases();
                loadCurrentAlias();
                DebugLogger.logInfo("SettingsPage", "Favorites updated for provider: " + aliasId);
            });
        }
    }

    function createNewAlias() {
        var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/AddProviderAliasDialog.qml"));
        dialog.accepted.connect(function() {
            DebugLogger.logInfo("SettingsPage", "Attempting to create alias: " + dialog.aliasId);
            if (LLMApi.addProviderAlias(dialog.aliasId, dialog.aliasName, dialog.providerType, dialog.apiUrl, dialog.apiKey, "", dialog.description, 10000, dialog.favoriteModel)) {
                var savedConfig = LLMApi.saveProviderAliases();
                providerAliasesConfig.value = savedConfig;
                DebugLogger.logInfo("SettingsPage", "Saved config length: " + savedConfig.length);
                loadAvailableAliases();
                currentAliasId = dialog.aliasId;
                loadCurrentAlias();
                DebugLogger.logInfo("SettingsPage", "Created new alias: " + dialog.aliasId + " with API key: " + (dialog.apiKey ? "***set***" : "empty") + " and favorite model: " + dialog.favoriteModel);
            } else {
                DebugLogger.logError("SettingsPage", "Failed to create alias: " + dialog.aliasId);
            }
        });
    }

    function editAlias(aliasId) {
        var alias = LLMApi.getProviderAlias(aliasId);
        if (!alias) return;
        var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/EditProviderAliasDialog.qml"), {
            "aliasId": aliasId,
            "aliasName": alias.name,
            "providerType": alias.type,
            "apiUrl": alias.url,
            "apiKey": alias.api_key,
            "description": alias.description,
            "favoriteModel": alias.favoriteModel
        });
        dialog.accepted.connect(function() {
            if (LLMApi.updateProviderAlias(aliasId, dialog.aliasName, dialog.apiUrl, dialog.apiKey, dialog.description, 10000, dialog.favoriteModel)) {
                providerAliasesConfig.value = LLMApi.saveProviderAliases();
                loadAvailableAliases();
                DebugLogger.logInfo("SettingsPage", "Updated alias: " + aliasId);
            }
        });
    }

    function deleteAlias(aliasId) {
        if (LLMApi.removeProviderAlias(aliasId)) {
            providerAliasesConfig.value = LLMApi.saveProviderAliases();
            loadAvailableAliases();
            DebugLogger.logInfo("SettingsPage", "Deleted alias: " + aliasId);
        }
    }

    function testAliasConnection(aliasId) {
        var alias = LLMApi.getProviderAlias(aliasId);
        LLMApi.checkAliasAvailability(aliasId, function(available, status) {
            var resultMessage = qsTr("Provider: %1").arg(alias ? alias.name : aliasId) + "\n";
            resultMessage += qsTr("Status: %1").arg(available ? qsTr("✓ Available") : "✗ " + status) + "\n";
            resultMessage += qsTr("URL: %1").arg(alias ? alias.url : qsTr("Unknown"));

            pageStack.push(Qt.resolvedUrl("../dialogs/InfoDialog.qml"), {
                "title": qsTr("Connection Test"),
                "message": resultMessage
            });
        });
    }

    Component.onCompleted: {
        DebugLogger.setDebugLevel(parseInt(debugLevelConfig.value) || 1);
        DebugLogger.logNormal("SettingsPage", "Settings page loaded");
        loadAvailableAliases();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Add provider")
                onClicked: createNewAlias()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Settings")
            }

            // --- Providers (most important, on top) ---
            SectionHeader {
                text: qsTr("Providers")
            }

            Label {
                visible: availableAliases.length === 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("No providers yet. Pull down to add one and choose its type.")
            }

            Repeater {
                model: availableAliases

                delegate: ListItem {
                    id: providerItem
                    width: parent.width
                    contentHeight: Theme.itemSizeMedium

                    onClicked: {
                        currentAliasId = modelData;
                        loadCurrentAlias();
                        showProviderModels(modelData);
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingMedium

                        Label {
                            id: statusIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSizeSmall
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeMedium
                            text: {
                                var status = LLMApi.getAliasAvailability(modelData);
                                switch (status) {
                                    case "available": return "✓";
                                    case "checking": return "⚠";
                                    case "no_key": return "⚷";
                                    case "error":
                                    case "timeout": return "✗";
                                    default: return "○";
                                }
                            }
                            color: {
                                var status = LLMApi.getAliasAvailability(modelData);
                                switch (status) {
                                    case "available": return Theme.primaryColor;
                                    case "checking": return Theme.highlightColor;
                                    case "error":
                                    case "timeout": return Theme.errorColor;
                                    default: return Theme.secondaryColor;
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.iconSizeSmall - Theme.paddingMedium

                            Label {
                                text: {
                                    var alias = LLMApi.getProviderAlias(modelData);
                                    return alias ? alias.name : modelData;
                                }
                                color: providerItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                width: parent.width
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                text: {
                                    var alias = LLMApi.getProviderAlias(modelData);
                                    if (!alias) return "";
                                    var parts = [];
                                    parts.push(qsTr("Type: %1").arg(alias.type));
                                    var favorites = LLMApi.getAliasFavoriteModels(modelData);
                                    if (favorites && favorites.length > 0) {
                                        if (favorites.length === 1) {
                                            parts.push(qsTr("Favorite: ★ %1").arg(favorites[0]));
                                        } else {
                                            parts.push(qsTr("Favorites: ★ %1").arg(favorites.length));
                                        }
                                    }
                                    if (alias.api_key) {
                                        parts.push(qsTr("API key set"));
                                    }
                                    return parts.join("  ·  ");
                                }
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                width: parent.width
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    menu: ContextMenu {
                        MenuItem {
                            text: qsTr("Manage favorites")
                            onClicked: showProviderModels(modelData)
                        }
                        MenuItem {
                            text: qsTr("Edit")
                            onClicked: editAlias(modelData)
                        }
                        MenuItem {
                            text: qsTr("Test connection")
                            onClicked: testAliasConnection(modelData)
                        }
                        MenuItem {
                            text: qsTr("Delete")
                            onClicked: {
                                var alias = LLMApi.getProviderAlias(modelData);
                                var nm = alias ? alias.name : modelData;
                                providerItem.remorseAction(qsTr("Deleting %1").arg(nm), function() {
                                    deleteAlias(modelData);
                                }, 5000);
                            }
                        }
                    }
                }
            }

            // --- Default model (general, any provider) ---
            SectionHeader {
                text: qsTr("Default model")
            }

            ValueButton {
                id: defaultModelButton
                width: parent.width
                label: qsTr("Model for new chats")
                value: {
                    var a = defaultProviderAliasConfig.value;
                    var m = defaultModelConfig.value;
                    if (a && m) {
                        var alias = LLMApi.getProviderAlias(a);
                        return (alias ? alias.name : a) + " · " + m;
                    }
                    return qsTr("Not set");
                }
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": defaultProviderAliasConfig.value,
                        "selectedModel": defaultModelConfig.value
                    });
                    dialog.accepted.connect(function() {
                        defaultProviderAliasConfig.value = dialog.selectedAliasId;
                        defaultModelConfig.value = dialog.selectedModel;
                        DebugLogger.logInfo("SettingsPage", "Default model set: " + dialog.selectedAliasId + " / " + dialog.selectedModel);
                    });
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("New chats start with this model, regardless of provider.")
            }

            // --- Photo & Vision ---
            SectionHeader {
                text: qsTr("Photo & Vision")
            }

            TextSwitch {
                id: autoSendSwitch
                width: parent.width
                text: qsTr("Send photo actions immediately")
                description: qsTr("When off, the chat opens with the photo and prompt ready for you to send.")
                automaticCheck: false
                checked: photoActionAutoSendConfig.value === true || photoActionAutoSendConfig.value === "true"
                onClicked: photoActionAutoSendConfig.value = !checked
            }

            ValueButton {
                id: visionModelButton
                width: parent.width
                label: qsTr("Default model for photo actions")
                value: {
                    var a = visionProviderAliasConfig.value;
                    var m = visionModelConfig.value;
                    if (a && m) {
                        var alias = LLMApi.getProviderAlias(a);
                        return (alias ? alias.name : a) + " · " + m;
                    }
                    return qsTr("Not set");
                }
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("../dialogs/ProviderAliasDialog.qml"), {
                        "selectedAliasId": visionProviderAliasConfig.value,
                        "selectedModel": visionModelConfig.value
                    });
                    dialog.accepted.connect(function() {
                        visionProviderAliasConfig.value = dialog.selectedAliasId;
                        visionModelConfig.value = dialog.selectedModel;
                        DebugLogger.logInfo("SettingsPage", "Vision default set: " + dialog.selectedAliasId + " / " + dialog.selectedModel);
                    });
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: (visionProviderAliasConfig.value && visionModelConfig.value)
                    ? qsTr("Used for cover, share and photo actions. Pick a vision-capable model.")
                    : qsTr("Not set — photo actions use the last chat model. Pick a vision-capable model.")
            }

            // --- Images ---
            SectionHeader {
                text: qsTr("Images")
            }

            ComboBox {
                id: imageMaxDimensionComboBox
                label: qsTr("Max image size")
                width: parent.width
                currentIndex: {
                    var v = imageMaxDimensionConfig.value;
                    if (v <= 512) return 0;
                    if (v <= 768) return 1;
                    if (v <= 1024) return 2;
                    if (v <= 1280) return 3;
                    if (v <= 1920) return 4;
                    return 5;
                }
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("512 px — compact")
                        onClicked: imageMaxDimensionConfig.value = 512;
                    }
                    MenuItem {
                        text: qsTr("768 px — medium")
                        onClicked: imageMaxDimensionConfig.value = 768;
                    }
                    MenuItem {
                        text: qsTr("1024 px — good quality")
                        onClicked: imageMaxDimensionConfig.value = 1024;
                    }
                    MenuItem {
                        text: qsTr("1280 px — default")
                        onClicked: imageMaxDimensionConfig.value = 1280;
                    }
                    MenuItem {
                        text: qsTr("1920 px — high quality")
                        onClicked: imageMaxDimensionConfig.value = 1920;
                    }
                    MenuItem {
                        text: qsTr("Original — no resize")
                        onClicked: imageMaxDimensionConfig.value = 99999;
                    }
                }
            }

            // --- Advanced ---
            SectionHeader {
                text: qsTr("Advanced")
            }

            ComboBox {
                id: debugLevelComboBox
                label: qsTr("Debug level")
                width: parent.width
                currentIndex: parseInt(debugLevelConfig.value) || 1
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("0 — None (Production)")
                        onClicked: debugLevelConfig.value = "0";
                    }
                    MenuItem {
                        text: qsTr("1 — Normal (Errors & Important)")
                        onClicked: debugLevelConfig.value = "1";
                    }
                    MenuItem {
                        text: qsTr("2 — Informative (API Calls)")
                        onClicked: debugLevelConfig.value = "2";
                    }
                    MenuItem {
                        text: qsTr("3 — Verbose (All Operations)")
                        onClicked: debugLevelConfig.value = "3";
                    }
                }
            }

            // Claude Generated: cap for the Ollama web_search / web_fetch agent loop
            ComboBox {
                id: maxToolIterComboBox
                label: qsTr("Max web tool iterations")
                description: qsTr("How many web_search / web_fetch rounds an Ollama model may run before a final answer is forced.")
                width: parent.width
                currentIndex: {
                    var v = parseInt(maxToolIterConfig.value) || 8;
                    if (v <= 3) return 0;
                    if (v <= 5) return 1;
                    if (v <= 8) return 2;
                    if (v <= 10) return 3;
                    return 4;
                }
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("3 — minimal")
                        onClicked: maxToolIterConfig.value = 3;
                    }
                    MenuItem {
                        text: qsTr("5 — low")
                        onClicked: maxToolIterConfig.value = 5;
                    }
                    MenuItem {
                        text: qsTr("8 — default")
                        onClicked: maxToolIterConfig.value = 8;
                    }
                    MenuItem {
                        text: qsTr("10 — high")
                        onClicked: maxToolIterConfig.value = 10;
                    }
                    MenuItem {
                        text: qsTr("15 — maximum")
                        onClicked: maxToolIterConfig.value = 15;
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }
    }
}
