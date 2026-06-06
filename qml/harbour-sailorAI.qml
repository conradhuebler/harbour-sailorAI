import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import Sailfish.Share 1.0
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

    // Claude Generated: Single pending photo action, consumed exactly once by ConversationListPage.
    // Shape: { mode: "camera" | "share", prompt: string, imagePath: string }
    property var pendingPhotoAction: null

    // Claude Generated: D-Bus adaptor — handles "Open with" (X-Maemo-* MIME open).
    DBusAdaptor {
        service: "harbour.sailorAI"
        path: "/harbour/sailorAI"
        iface: "harbour.sailorAI"

        function openUrl(url) {
            var path = url.toString()
            if (path.indexOf("file://") === 0) path = path.substring(7)
            if (path !== "") dispatchPhotoAction({ "mode": "share", "imagePath": path, "prompt": "" })
        }
    }

    // Claude Generated: Share target. The Sailfish share framework calls the convention service
    // <OrganizationName>.<ApplicationName> = harbour.harbour-sailorAI on org.sailfishos.share
    // (the custom Service= in the desktop [X-Share Method] is ignored), so we register a
    // ShareProvider here. Autostart is provided by dbus/harbour.harbour-sailorAI.service.
    // 'method' must match the X-Share-Methods name in the .desktop file.
    ShareProvider {
        method: "sailorAI_share"
        registerName: true
        capabilities: ["image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp"]

        onTriggered: {
            if (!resources || resources.length === 0) return
            var r = resources[0]
            var path = ""
            if (typeof r === "string") {
                path = r
            } else if (r) {
                path = (r.filePath || r.url || r.path || r.data || "").toString()
            }
            if (path.indexOf("file://") === 0) path = path.substring(7)
            if (path !== "") dispatchPhotoAction({ "mode": "share", "imagePath": path, "prompt": "" })
        }
    }

    // Claude Generated: Activate the app, return to the conversation list (root), and queue the
    // photo action. ConversationListPage consumes it (deferred) via onStatusChanged(Active) /
    // onPendingPhotoActionChanged. Idempotent: the consumer clears it before dispatching.
    function dispatchPhotoAction(action) {
        app.activate()
        app.pendingPhotoAction = action
        if (pageStack.depth > 1) {
            pageStack.pop(null, PageStackAction.Immediate)
        }
    }

    initialPage: Component { ConversationListPage { } }

    allowedOrientations: defaultAllowedOrientations

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
                dispatchPhotoAction({ "mode": "camera", "imagePath": "",
                    "prompt": qsTr("Please describe this photo in %1.").arg(Qt.locale().nativeLanguageName) })
            }

            onTranslateTextRequested: {
                dispatchPhotoAction({ "mode": "camera", "imagePath": "",
                    "prompt": qsTr("Please translate all text visible in this photo to %1.").arg(Qt.locale().nativeLanguageName) })
            }
        }
    }

}
