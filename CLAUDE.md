# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SailorAI is a modern Sailfish OS application that provides an AI chat interface supporting multiple LLM providers with real-time streaming capabilities. The app is built using Qt Quick/QML with a pure JavaScript API layer.

## General Instructions

- Each source code dir has a CLAUDE.md with basic information of the code and logic
- **Keep CLAUDE.md files concise and focused** - avoid verbose descriptions and redundant information
- Tasks corresponding to code must be placed in the correct CLAUDE.md file
- Each CLAUDE.md has a variable part (short-term info, bugs) and preserved part (permanent knowledge)
- **Instructions blocks** contain operator-defined future tasks and visions for code development
- Only include information important for ALL subdirectories in main CLAUDE.md
- Preserve new knowledge from conversations but keep it brief
- Always suggest improvements to existing code
- Mark new functions as "Claude Generated" for traceability
- Implement comprehensive error handling and logging 

#### Copyright and File Headers
- **Copyright ownership**: All copyright remains with Conrad Hübler as AI instructor
- **Year updates**: Always update copyright year to current year when modifying files
- **Claude contributions**: Mark Claude-generated code sections but copyright stays with Conrad
- **Format**: `Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>`
- **AI acknowledgment**: Add Claude contribution notes in code comments, not copyright headers

## Architecture

### Frontend (QML)
- **harbour-sailorAI.qml**: Main application window
- **pages/ChatPage.qml**: Core chat interface with real-time streaming, conversation management, SQLite persistence, provider/model selection
- **pages/ConversationListPage.qml**: Conversation management with create/rename/delete functionality
- **pages/SettingsPage.qml**: Provider configuration UI with dynamic alias management and debug controls
- **dialogs/ProviderAliasDialog.qml**: Provider and model selection dialog
- **dialogs/AddProviderAliasDialog.qml**: Create new provider configurations
- **dialogs/ModelListDialog.qml**: Display available models with favorites-first sorting
- **cover/CoverPage.qml**: App cover for minimized state

### Backend (JavaScript)
- **js/LLMApi.js**: Pure JavaScript unified LLM interface with streaming support, alias-based provider management
- **js/DebugLogger.js**: Comprehensive logging system with configurable levels (None, Normal, Info, Verbose)
- **js/DatabaseQueries.js**: SQLite database operations via QtQuick.LocalStorage

### Key Components
- **Provider Alias System**: Dynamic provider configurations with custom names, URLs, API keys, and favorite models
- **Real-time Streaming**: Server-Sent Events processing for OpenAI-compatible, Anthropic, and Ollama providers
- **Database**: SQLite via QtQuick.LocalStorage for conversations and messages with timestamps
- **Configuration**: Nemo.Configuration for persistent settings (provider aliases, debug level, last selection)
- **Provider Support**: 
  - ✅ **OpenAI Compatible** (ChatGPT) - with streaming
  - ✅ **Anthropic Claude** - with streaming
  - ✅ **Google Gemini** - instant response (no streaming)
  - ✅ **Ollama Local** - with streaming
- **UI Features**: Live streaming responses, persistent provider/model selection, conversation history, message timestamps, copy functionality, retry mechanism, comprehensive error handling

## Dependencies

### Runtime Requirements
- sailfishsilica-qt5 >= 0.10.9
- libsailfishapp-launcher
- Nemo.Configuration (for persistent settings)

### Build Requirements
- Qt5Core, Qt5Qml, Qt5Quick
- sailfishapp >= 1.0.3
- desktop-file-utils

## Configuration

The application uses Nemo.Configuration for persistent settings:
- **Provider Aliases**: `/SailorAI/provider_aliases` - JSON of all configured provider aliases
- **Debug Level**: `/SailorAI/debug_level` - Current debug logging level (0-3)
- **Last Selection**: `/SailorAI/last_selected_alias` and `/SailorAI/last_selected_model` - User's last choice

## Key Files for Modifications

### Core Chat Interface
- **pages/ChatPage.qml:177-277**: Main chat generation logic with streaming support
- **pages/ChatPage.qml:156-159**: Provider streaming capability detection
- **pages/ChatPage.qml:50-90**: Provider/model selection persistence functions

### Provider Management  
- **js/LLMApi.js:19-51**: Provider type definitions - add new providers here
- **js/LLMApi.js:478-650**: Main generation function with streaming logic
- **js/LLMApi.js:435-475**: Server-Sent Events processing for streaming
- **js/LLMApi.js:61-143**: Provider alias management functions

### UI Components
- **pages/SettingsPage.qml:298-466**: Provider alias list with edit/delete/test functionality
- **dialogs/ProviderAliasDialog.qml**: Provider and model selection dialog
- **dialogs/AddProviderAliasDialog.qml**: New provider creation with real-time model fetching
- **dialogs/ModelListDialog.qml**: Model display with favorites-first sorting

### Database & Settings
- **pages/ChatPage.qml:90-102**: Message saving to SQLite database
- **pages/SettingsPage.qml:25-55**: Configuration persistence setup

## Translation Support


Translation files are in the `translations/` directory using Qt's `.ts` format.

## Streaming Implementation

### How Streaming Works
1. **Detection**: `ChatPage.qml` checks if provider supports streaming via `providerTypes[alias.type].supportsStreaming`
2. **Request Setup**: `LLMApi.js` adds `"stream": true` to request data for supported providers
3. **Response Processing**: `XMLHttpRequest.LOADING` state triggers `processStreamChunk()` function
4. **Chunk Parsing**: Server-Sent Events format (`data: {...}`) parsed for content deltas
5. **UI Updates**: Real-time text updates via `chatModel.setProperty()` calls
6. **Completion**: `finalizeStreamingMessage()` saves complete content to database

### Provider-Specific Streaming Formats
- **OpenAI/Ollama**: `data: {"choices": [{"delta": {"content": "text"}}]}`
- **Anthropic**: `data: {"type": "content_block_delta", "delta": {"text": "text"}}`
- **Gemini**: No streaming - instant full response

### Error Handling
- **Partial content preservation**: Streamed text saved even on connection failures
- **Role alternation**: Duplicate consecutive roles filtered out to prevent API errors
- **Clean state management**: All streaming variables reset on completion or error

## Debug System

### Debug Levels (DebugLogger.js)
- **0 - None**: Production mode, no logging
- **1 - Normal**: Errors and important events only
- **2 - Informative**: API calls, HTTP responses, provider switches
- **3 - Verbose**: Complete HTTP requests, streaming chunks, all operations

### Key Debug Output
- **HTTP Requests**: Full URL, headers, request body, curl equivalent
- **Streaming**: Individual chunk processing and content assembly
- **Provider Management**: Alias creation, model fetching, availability checks
- **Database**: Message saving and loading operations

## Database Schema

### Conversations Table
- `id`: INTEGER PRIMARY KEY
- `name`: TEXT (conversation title)
- `created_at`: DATETIME
- `updated_at`: DATETIME

### Messages Table
- `id`: INTEGER PRIMARY KEY
- `conversation_id`: INTEGER (foreign key)
- `role`: TEXT ('user', 'bot', 'error')
- `message`: TEXT (content)
- `timestamp`: INTEGER (Unix timestamp)

## Adding New Providers

### 1. Define Provider Type (LLMApi.js:19-51)
```javascript
"newprovider": {
    "name": "New Provider Name",
    "defaultUrl": "https://api.newprovider.com/v1",
    "defaultModels": ["model1", "model2"],
    "authHeader": "Authorization",
    "authPrefix": "Bearer ",
    "supportsStreaming": true
}
```

### 2. Add URL Construction Logic (LLMApi.js:520-590)
Handle provider-specific URL patterns and authentication headers.

### 3. Add Streaming Format (LLMApi.js:458-463)
If provider supports streaming, add response parsing logic in `processStreamChunk()`.

### 4. Update Settings UI (SettingsPage.qml)
Add provider to the available types in the provider creation dialog.

## Common Issues and Solutions

### Model Selection Not Persisting
- Check `saveCurrentSelection()` calls in `ProviderAliasDialog.accepted`
- Verify `ConfigurationValue` keys are correct
- Ensure `restoreLastSelection()` runs on app startup

### Streaming Not Working
- Verify `typeInfo.supportsStreaming` is `true` for provider
- Check for proper `streamCallback` parameter in `generateContent()` calls
- Enable verbose logging to see streaming enablement messages

### 404/403 API Errors
- Use verbose logging to see complete HTTP requests
- Verify API key format and headers for provider
- Check URL construction for provider-specific patterns

### Empty Chat Messages
- Ensure `finalizeStreamingMessage()` is called in both success and error cases
- Check database saving with `saveMessage()` calls
- Verify message roles are alternating properly
