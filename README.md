# CloudAI Gateway for Android

[![Build CloudAI Gateway Android](https://github.com/sadadonline17-oss/unified-ai-gateway/actions/workflows/build-android.yml/badge.svg)](https://github.com/sadadonline17-oss/unified-ai-gateway/actions/workflows/build-android.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.24-02569B?logo=flutter)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-22-green?logo=node.js)](https://nodejs.org/)
[![Ollama](https://img.shields.io/badge/Ollama-Cloud%20LLM-blue)](https://ollama.ai/)

> **Free Cloud LLM Access on Android** — 30+ free cloud AI models (Qwen3.5, DeepSeek-V3, GLM-5) with local terminal, all in one unified Android app.

---

## 📢 Latest: Full Repository Merged into Single APK

✅ **All gateway code is now embedded in the Flutter app!**

The entire `unified-ai-gateway` Node.js codebase has been merged into a single APK:
- Gateway files copied to `flutter_app/assets/gateway/`
- Auto-installs npm dependencies on first run
- Runs in proot Ubuntu environment
- Foreground service with notifications

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for build instructions.

---

## 🚀 Features

### AI Capabilities - FREE Cloud Models
- **🌐 30+ Free Cloud Models** - Access via Ollama Cloud API
- **💬 Multiple AI Modes** - Chat, Code Generation, Advanced Coding
- **🤖 Latest Models** - Qwen3.5 (397B), DeepSeek-V3 (671B), GLM-5 (744B)
- **🔧 No Local Setup** - Cloud inference, no local model downloads

### Supported Free Cloud Models
| Mode | Default Model | Size | Use Case |
|------|--------------|------|----------|
| Core Chat | Qwen3.5 | 397B-A17B | Best overall chat, vision support |
| Code Generate | Qwen3-Coder-Next | — | Agentic coding workflows |
| Advanced Code | GLM-5 | 744B (40B active) | Agentic coding, reasoning |

### All Available Free Models
**Chat Models (14):** Qwen3.5, Kimi-K2.5, MiniMax-M2.5, GLM-5, Qwen3-Next, Nemotron-3-Nano, Ministral:14b/8b, RNJ-1, Llama3.2:7b/3b, Gemma2:9b, Mistral:7b, Phi3:14b

**Code Models (15):** Qwen3-Coder-Next, DeepSeek-V3/V3.2/R1, GLM-5/4.7/4.6, Qwen2.5-Coder:32b/7b, CodeLlama:7b, Devstral-Small-2/2, MiniMax-M2/M2.1, Cogito-2.1

**Vision Models (5):** Qwen3-VL:32b/8b/4b, Llama3.2-Vision:11b/90b

### Android App Features
- **📱 Native Flutter UI** — Modern Material Design 3 interface
- **🖥️ Built-in Terminal** — Full terminal emulator with Node.js runtime
- **📊 Web Dashboard** — Embedded WebView for gateway management
- **⚙️ Settings** — Configure cloud models and preferences
- **🔔 Foreground Service** — Keep gateway running in background
- **🎯 All-in-One** — Complete AI gateway in single APK

---

## 📋 Requirements

| Requirement | Details |
|-------------|---------|
| **Android** | 10 or higher (API 29) |
| **Storage** | ~500MB for app (no local models needed) |
| **RAM** | 2GB+ recommended |
| **Internet** | Required for cloud model access |
| **Architectures** | arm64-v8a, armeabi-v7a, x86_64 |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │ AI Dashboard │ │   Terminal   │ │   Model Selector │     │
│  │  Mode Switch │ │   Emulator   │ │   Cloud Models   │     │
│  └──────┬───────┘ └──────┬───────┘ └────────┬─────────┘     │
│         │                │                  │                │
│  ┌──────┴────────────────┴──────────────────┴─────────────┐ │
│  │              Native Bridge (Kotlin)                     │ │
│  │  OllamaService │ GatewayService │ TerminalService       │ │
│  └──────────────────────┬──────────────────────────────────┘ │
└─────────────────────────┼────────────────────────────────────┘
                          │
┌─────────────────────────┼────────────────────────────────────┐
│  proot-distro           │              Ubuntu                │
│  ┌──────────────────────┴─────────────────────────────────┐  │
│  │   Node.js 22 + Unified Gateway                         │  │
│  │   ┌─────────────────────────────────────────────────┐  │  │
│  │   │  Unified Gateway (HTTP:18789, WS:18790)         │  │  │
│  │   │  ┌─────────────────────────────────────────┐    │  │  │
│  │   │  │  OllamaProvider (Cloud Models API)      │    │  │  │
│  │   │  │  - Qwen3.5, DeepSeek-V3, GLM-5          │    │  │  │
│  │   │  │  - 30+ Free Cloud Models                │    │  │  │
│  │   │  └─────────────────────────────────────────┘    │  │  │
│  │   │  Routes: /ai/chat, /ai/code, /ai/advanced_code  │  │  │
│  │   └─────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                          │
                    ☁️ Internet
                          │
┌─────────────────────────┼────────────────────────────────────┐
│            Ollama Cloud API (Free Tier)                      │
│  - Qwen3.5, DeepSeek-V3, GLM-5, and 30+ more models         │
│  - No authentication required for public models             │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔌 API Endpoints

### HTTP API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | Gateway and Ollama status |
| `/ai/chat` | POST | Chat completion (streaming) |
| `/ai/code` | POST | Code generation |
| `/ai/advanced_code` | POST | Advanced code tasks |
| `/ai/opencode` | POST | OpenCode/Claude/Codex modes |
| `/models` | GET | List available models |
| `/models/pull` | POST | Pull a new model |
| `/routing` | GET/POST | Get/set model routing |

### WebSocket API

Connect to `ws://localhost:18790`

```javascript
// Chat message
{ "type": "chat", "content": "Hello!", "history": [], "options": {} }

// Code generation
{ "type": "code", "prompt": "Write a function to sort an array", "options": {} }

// Ping
{ "type": "ping" }
```

---

## 📥 Installation

### Download APK

Download the latest release from [GitHub Releases](https://github.com/sadadonline17-oss/unified-ai-gateway/releases).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/sadadonline17-oss/unified-ai-gateway.git
cd unified-ai-gateway

# Build Flutter APK
cd flutter_app
flutter pub get
flutter build apk --release
```

### Termux CLI

```bash
# Install via npm
npm install -g unified-ai-gateway

# Run setup
unified-ai setup

# Start gateway
unified-ai start
```

---

## 🎯 Quick Start

1. **Install the APK** on your Android device
2. **Open the app** and tap "Begin Setup"
3. **Wait for setup** to complete (downloads Ubuntu, Node.js, Ollama)
4. **Pull models** from the Models screen
5. **Select AI mode** (Chat, Code, or Advanced Code)
6. **Start Gateway** and begin using!

---

## 🔧 Configuration

### Model Routing

Configure which model to use for each mode:

```json
{
  "core_chat": "llama3",
  "code_generate": "deepseek-coder",
  "advanced_code": "qwen2.5-coder"
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | 127.0.0.1:11434 | Ollama API endpoint |
| `OLLAMA_MODELS` | /root/.ollama/models | Model storage path |
| `GATEWAY_PORT` | 18789 | HTTP API port |
| `WS_PORT` | 18790 | WebSocket port |

---

## 🧪 Development

### Project Structure

```
unified-ai-gateway/
├── lib/                          # Node.js backend
│   ├── ollama/                   # Ollama integration
│   │   └── index.js              # Ollama provider
│   └── gateway/                  # Unified gateway
│       └── unified-gateway.js    # HTTP + WS server
├── flutter_app/                  # Flutter Android app
│   ├── lib/
│   │   ├── models/               # Data models
│   │   │   └── ai_mode.dart      # AI modes and state
│   │   ├── providers/            # State management
│   │   │   └── ai_gateway_provider.dart
│   │   └── screens/              # UI screens
│   │       ├── ai_dashboard_screen.dart
│   │       └── models_screen.dart
│   └── android/
│       └── app/src/main/kotlin/  # Kotlin native bridge
│           └── OllamaService.kt
├── scripts/                      # Setup scripts
│   └── setup-ollama.sh
└── .github/workflows/            # CI/CD
    └── build-unified.yml
```

### Running Tests

```bash
# Node.js tests
npm test

# Flutter tests
cd flutter_app
flutter test
```

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [OpenClaw](https://github.com/anthropics/openclaw) - AI Gateway
- [Ollama](https://ollama.ai/) - Local LLM inference
- [NullClaw](https://github.com/mithun50/nullclaw) - Android bindings
- [openclaw-termux](https://github.com/mithun50/openclaw-termux) - Base project

---

<p align="center">
  Made with ❤️ for the Android AI community
</p># unified-ai-gateway
