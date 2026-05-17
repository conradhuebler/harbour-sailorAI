import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import "pages"
import "cover"
import "components"

ApplicationWindow
{
    id: app

    // Global simple database instance
    property alias database: simpleDb
    SimpleDatabase {
        id: simpleDb
    }

    // Cover statistics
    property int activeProviderCount: 0
    property int conversationCount: 0
    property bool hasActiveProviders: false

    // Pending shared image path (set by DBusAdaptor, consumed by ConversationListPage)
    property string pendingSharedImage: ""

    // Claude Generated: D-Bus adaptor — handles "Open with" (X-Maemo-*) and share() from AppShareMethodPlugin.
    DBusAdaptor {
        service: "harbour.sailorAI"
        path: "/harbour/sailorAI"
        iface: "harbour.sailorAI"

        function openUrl(url) {
            app.activate()
            var path = url.toString()
            if (path.indexOf("file://") === 0) path = path.substring(7)
            app.pendingSharedImage = path
            pageStack.pop(null, PageStackAction.Immediate)
            shareActionTimer.restart()
        }

        // Called by Sailfish AppShareMethodPlugin when app is selected from share sheet
        function share(configuration) {
            app.activate()
            var resources = configuration["resources"]
            if (!resources || resources.length === 0) return
            var res = resources[0]
            var path = ""
            if (res["filePath"] && res["filePath"] !== "") {
                path = res["filePath"]
            } else if (res["url"]) {
                path = res["url"].toString()
            } else if (res["data"]) {
                path = res["data"].toString()
            }
            if (path.indexOf("file://") === 0) path = path.substring(7)
            if (path !== "") {
                app.pendingSharedImage = path
                pageStack.pop(null, PageStackAction.Immediate)
                shareActionTimer.restart()
            }
        }
    }

    Timer {
        id: shareActionTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (app.pendingSharedImage !== "" && pageStack.currentPage && pageStack.currentPage.handleSharedImage) {
                var path = app.pendingSharedImage
                app.pendingSharedImage = ""
                pageStack.currentPage.handleSharedImage(path)
            }
        }
    }

    initialPage: Component { ConversationListPage { } }

    allowedOrientations: defaultAllowedOrientations

    Component.onCompleted: {
        console.log("SailorAI: Application started successfully")
        console.log("SailorAI: ApplicationWindow size:", width, "x", height)
        console.log("SailorAI: Orientation:", orientation)
    }

    // Qt.callLater is not available in Qt 5.6 (Sailfish) — use zero-interval Timers instead

    Timer {
        id: newChatTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (pageStack.currentPage && pageStack.currentPage.newConversation) {
                pageStack.currentPage.newConversation()
            }
        }
    }

    // Claude Generated: Step 1 — push CameraCapturePage after app activation + pop to root
    Timer {
        id: cameraLaunchTimer
        interval: 50
        repeat: false
        property string pendingPrompt: ""
        onTriggered: {
            if (pageStack.currentPage && pageStack.currentPage.openPhotoAction) {
                pageStack.currentPage.openPhotoAction(pendingPrompt)
            }
        }
    }

    // Claude Generated: Activate app, navigate to root, then delegate to ConversationListPage.openPhotoAction
    function launchCameraAction(prompt) {
        app.activate()
        pageStack.pop(null, PageStackAction.Immediate)
        cameraLaunchTimer.pendingPrompt = prompt
        cameraLaunchTimer.restart()
    }

    cover: Component {
        CoverPage {
            id: coverPage
            activeProviderCount: app.activeProviderCount
            conversationCount: app.conversationCount
            hasActiveProviders: app.hasActiveProviders

            onNewChatRequested: {
                app.activate()
                if (pageStack.currentPage && pageStack.currentPage.newConversation) {
                    pageStack.currentPage.newConversation()
                } else {
                    pageStack.pop(null, PageStackAction.Immediate)
                    newChatTimer.restart()
                }
            }

            onDescribePhotoRequested: {
                launchCameraAction(qsTr("Please describe this photo in %1.").arg(Qt.locale().nativeLanguageName))
            }

            onTranslateTextRequested: {
                launchCameraAction(qsTr("Please translate all text visible in this photo to %1.").arg(Qt.locale().nativeLanguageName))
            }
        }
    }

    onWidthChanged: console.log("SailorAI: Width changed to:", width)
    onHeightChanged: console.log("SailorAI: Height changed to:", height)
}
