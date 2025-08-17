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
    
    // Cover statistics
    property int activeProviderCount: 0
    property int conversationCount: 0
    property bool hasActiveProviders: false

    initialPage: Component { ConversationListPage { } }

    allowedOrientations: defaultAllowedOrientations
    
    Component.onCompleted: {
        console.log("SailorAI: Application started successfully")
        console.log("SailorAI: ApplicationWindow size:", width, "x", height)
        console.log("SailorAI: Orientation:", orientation)

    }
    cover: Component { 
        CoverPage { 
            id: coverPage
            activeProviderCount: app.activeProviderCount
            conversationCount: app.conversationCount
            hasActiveProviders: app.hasActiveProviders
            
            onNewChatRequested: {
                console.log("Main app received newChatRequested signal");
                
                // First activate the app to bring it to foreground
                app.activate();
                
                console.log("Current page:", pageStack.currentPage ? pageStack.currentPage.objectName || "unnamed" : "null");
                
                // Find the main page and trigger new conversation
                if (pageStack.currentPage && pageStack.currentPage.newConversation) {
                    console.log("Current page has newConversation, calling it");
                    pageStack.currentPage.newConversation()
                } else {
                    console.log("Need to navigate to conversation list page");
                    
                    // Simple approach: pop all pages to go to root
                    console.log("Popping all pages to root");
                    pageStack.pop(null, PageStackAction.Immediate);
                    
                    // Wait a moment for navigation to complete, then call newConversation
                    Qt.callLater(function() {
                        console.log("After navigation, current page:", pageStack.currentPage ? pageStack.currentPage.objectName || "unnamed" : "null");
                        if (pageStack.currentPage && pageStack.currentPage.newConversation) {
                            console.log("Found newConversation method, calling it");
                            pageStack.currentPage.newConversation();
                        } else {
                            console.log("Still no newConversation method found");
                        }
                    });
                }
            }
        } 
    }

    onWidthChanged: console.log("SailorAI: Width changed to:", width)
    onHeightChanged: console.log("SailorAI: Height changed to:", height)
}
