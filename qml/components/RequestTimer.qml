import QtQuick 2.0

Timer {
    id: timer
    property var callback: null
    property var request: null
    
    function startTimeout(timeoutMs, xhr, timeoutCallback) {
        request = xhr;
        callback = timeoutCallback;
        interval = timeoutMs;
        restart();
    }
    
    function stopTimeout() {
        stop();
        callback = null;
        request = null;
    }
    
    onTriggered: {
        if (request) {
            request.abort();
        }
        if (callback) {
            callback();
        }
        stopTimeout();
    }
}