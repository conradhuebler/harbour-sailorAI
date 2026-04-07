import QtQuick 2.0
import "../api_tests_qml.js" as ApiTests

QtObject {
    // Helper that loads the same test provider JSON used by the Bash scripts
    property var config: ({})
    function loadConfig() {
        // The file lives in the same Qt resource folder (resources/config)
        var url = Qt.resolvedUrl("config/test_providers.json")
        var request = new XMLHttpRequest()
        request.open('GET', url, false)   // synchronous – fine for a tiny config file
        request.send()
        if (request.status === 200) {
            config = JSON.parse(request.responseText)
            console.log('Test config loaded, providers: ' + Object.keys(config.test_providers))
        } else {
            console.error('Failed to load test config (status ' + request.status + ')')
        }
    }

    Component.onCompleted: loadConfig()
}
