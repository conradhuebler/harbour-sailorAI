import QtQuick 2.12
import QtQuick.Controls 2.5
import "test_config.js" as TestConfig
import "src/js/ApiAbstraction.js" as ApiModule

ApplicationWindow {
    id: window
    visible: true
    width: 900
    height: 700
    title: "SailorAI API Abstraction Layer - Desktop PoC"

    property var api: null

    Component.onCompleted: {
        api = new ApiModule.ApiAbstraction(TestConfig.testConfig);
        if (api) {
            console.log("API initialized - providers: " + api.getProviderIds());
        } else {
            console.error("Failed to initialize API");
        }
    }

    header: TabBar {
        id: tabBar
        TabButton { text: qsTr("Chat") }
        TabButton { text: qsTr("Providers") }
        TabButton { text: qsTr("Status") }
        TabButton { text: qsTr("Settings") }
    }

    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: tabBar.currentIndex
        onCurrentIndexChanged: {
            // Refresh the active page when switching tabs
            if (currentIndex === 0) chatPage.refreshAll();
            if (currentIndex === 1) aliasPage.refreshAliases();
            if (currentIndex === 2) statusPage.refreshStatus();
            if (currentIndex === 3) settingsPage.refreshProviders();
        }

        ChatPage {
            id: chatPage
            api: window.api
        }

        AliasPage {
            id: aliasPage
            api: window.api
        }

        StatusPage {
            id: statusPage
            api: window.api
        }

        SettingsPage {
            id: settingsPage
            api: window.api
        }
    }
}