Qt.include("src/js/ConfigLoader.js");
Qt.include("src/js/EndpointBuilder.js");
Qt.include("src/js/ApiAbstraction.js");

// Load configuration (contains endpoints & provider definitions)
var cfg = ConfigLoader.load("qrc:/config/api_endpoints.json");
console.log("Loaded providers: " + Object.keys(cfg.api_endpoints).join(", "));


function availableProviders(){
    return Object.keys(cfg.api_endpoints);
}

function availableModels(providerId){
    var prov = cfg.api_endpoints[providerId];
    return prov ? prov.defaultModels : [];
}

function sendMessage(providerId, model, text, onChunk, onDone, onError){
    var opts = {
        streaming: cfg.api_endpoints[providerId].features.supportsStreaming,
        apiKey: Qt.processEnvironment[providerId.toUpperCase() + "_API_KEY"]
    };
    var req = api.buildRequest(providerId, model, [{role:"user", content:text}], opts);
    api.sendRequest(req,
        function(response){ // non‑streaming success
            onChunk && onChunk(response);
            onDone && onDone();
        },
        function(err){ // error
            onError && onError(err);
        },
        onChunk // streaming callback
    );
}

// Export symbols for QML import
var Chat = {
    availableProviders: availableProviders,
    availableModels: availableModels,
    sendMessage: sendMessage
};

// Make available as "Chat" namespace (import "resources/chat_logic.js" as Chat)
