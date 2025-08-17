import QtQuick 2.0
import Sailfish.Silica 1.0
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

    initialPage: Component { ConversationListPage { } }

    allowedOrientations: defaultAllowedOrientations
    
    Component.onCompleted: {
        console.log("SailorAI: Application started successfully")
        console.log("SailorAI: ApplicationWindow size:", width, "x", height)
        console.log("SailorAI: Orientation:", orientation)

    }
    cover: Component { 
        CoverPage { 
            onNewChatRequested: {
                // Find the main page and trigger new conversation
                if (pageStack.currentPage && pageStack.currentPage.newConversation) {
                    pageStack.currentPage.newConversation()
                }
            }
        } 
    }

    onWidthChanged: console.log("SailorAI: Width changed to:", width)
    onHeightChanged: console.log("SailorAI: Height changed to:", height)
}
