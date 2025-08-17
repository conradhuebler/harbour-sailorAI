# SailorAI

A modern AI chat application for Sailfish OS supporting multiple LLM providers with real-time streaming capabilities.

## 🚀 Features

### Multi-Provider Support
- **OpenAI Compatible APIs** (ChatGPT etc.)
- **Anthropic Claude** - not tested
- **Google Gemini** 

### Real-Time Streaming
- **Live text streaming** for supported providers (OpenAI, Anthropic)
- **Smooth typing animation** with visual indicators
- **Real-time response** as the AI generates content
- **Robust error handling** with partial content preservation

### Advanced Provider Management
- **Dynamic provider aliases** - create custom configurations
- **Multiple instances** of the same provider type
- **Favorite model selection** per provider
- **Real-time model fetching** from provider APIs
- **Connection testing** and availability checking

### Smart Chat Experience
- **Persistent conversations** with SQLite database
- **Message history** with timestamps and copy functionality
- **Auto-scroll** during streaming responses
- **Role alternation** ensuring proper conversation flow
- **Retry functionality** for failed messages

### User Experience
- **Native Sailfish UI** with Silica components
- **Dark/Light theme** support
- **Persistent settings** - remembers last provider/model choice
- **Comprehensive debug logging** (4 levels: None, Normal, Info, Verbose)
- **Multi-language support** (German, French, Finnish)

## ⚙️ Setup

### 1. Configure Providers
1. Open **Settings** from the app menu
2. Tap **"Add Provider Alias"**
3. Choose provider type and configure:
   - **Name**: Custom name for this configuration
   - **API URL**: Provider endpoint (pre-filled defaults available)
   - **API Key**: Your provider's API key
   - **Description**: Optional description

### 2. Provider-Specific Setup

#### OpenAI Compatible (ChatGPT)
- **URL**: `https://api.openai.com/v1` (OpenAI) or any other 
- **API Key**: Your OpenAI API key or GWDG credentials
- **Streaming**: ✅ Supported

#### Anthropic Claude
- **URL**: `https://api.anthropic.com/v1`
- **API Key**: Your Anthropic API key
- **Streaming**: ✅ Supported

#### Google Gemini
- **URL**: `https://generativelanguage.googleapis.com/v1beta/models`
- **API Key**: Your Google AI Studio API key
- **Streaming**: ❌ Not supported (instant response)

## 🔧 Usage

### Starting a Chat
1. Launch SailorAI
2. Create a new conversation or select existing one
3. Choose your preferred provider and model
4. Start chatting!

### Switching Providers/Models
- Tap the provider button at the bottom of the chat
- Select different provider alias and model
- Your choice is automatically saved

### Streaming Responses
- **OpenAI/Anthropic/Ollama**: Watch responses appear in real-time
- **Gemini**: Instant full response (no streaming)
- Visual indicators show when AI is thinking vs. responding

### Debug Information
Access via Settings → Debug Level:
- **0 - None**: Production mode, minimal logging
- **1 - Normal**: Errors and important events
- **2 - Informative**: API calls and provider switches
- **3 - Verbose**: All operations, complete HTTP requests

## 🛠️ Development

### Architecture
- **Frontend**: QML/QtQuick with Sailfish Silica components
- **Backend**: JavaScript API layer with XMLHttpRequest
- **Database**: SQLite via QtQuick.LocalStorage
- **Configuration**: Nemo.Configuration for persistent settings

### Key Components
- **`LLMApi.js`**: Unified provider interface with streaming support
- **`ChatPage.qml`**: Main chat interface with real-time updates
- **`SettingsPage.qml`**: Provider configuration and debug controls
- **`DebugLogger.js`**: Comprehensive logging system

### Build Requirements
- Sailfish OS SDK
- Qt5 (Core, Qml, Quick)
- sailfishapp >= 1.0.3

### Runtime Dependencies
- sailfishsilica-qt5 >= 0.10.9
- Nemo.Configuration

## 📝 Configuration

Settings are stored in:
- **Provider Aliases**: `/SailorAI/provider_aliases`
- **Debug Level**: `/SailorAI/debug_level`
- **Last Selection**: `/SailorAI/last_selected_alias` and `/SailorAI/last_selected_model`

## 🐛 Troubleshooting

### Connection Issues
1. Check API key validity in provider settings
2. Test connection using "Test Connection" in provider menu
3. Verify network connectivity
4. Enable debug logging (Level 2-3) to see HTTP requests

### Streaming Not Working
- Ensure provider supports streaming (OpenAI, Anthropic, Ollama)
- Check debug logs for streaming enablement messages
- Gemini doesn't support streaming - this is expected

### Empty Responses
- Check API key permissions
- Verify model availability for your provider
- Review conversation history for role alternation issues

## 📄 License


## 🤝 Contributing



## 📞 Support

