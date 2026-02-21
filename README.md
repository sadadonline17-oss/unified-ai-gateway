# Unified AI Gateway for Android

[![Build Unified AI Gateway](https://github.com/sadadonline17-oss/unified-ai-gateway/actions/workflows/build-unified.yml/badge.svg)](https://github.com/sadadonline17-oss/unified-ai-gateway/actions/workflows/build-unified.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.24-02569B?logo=flutter)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-22-green?logo=node.js)](https://nodejs.org/)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20LLM-blue)](https://ollama.ai/)

> **Run Ollama + OpenClaw + NullClaw locally on Android** — A unified AI gateway with local LLM inference, code generation, and multiple AI modes in a single app.

---

## 🚀 Features

### AI Capabilities
- **🤖 Local LLM Inference** — Run AI models locally using Ollama
- **💬 Multiple AI Modes** — Chat, Code Generation, Advanced Coding
- **🔧 OpenClaw Integration** — Full OpenClaw gateway functionality
- **🔗 NullClaw Binding** — Native Android capabilities for AI

### Supported Models
| Mode | Default Model | Use Case |
|------|--------------|----------|
| Core Chat | llama3 | General conversation and assistance |
| Code Generate | deepseek-coder | Code generation and debugging |
| Advanced Code | qwen2.5-coder | Complex code tasks and refactoring |

### Android App Features
- **📱 Native Flutter UI** — Modern Material Design 3 interface
- **🖥️ Built-in Terminal** — Full terminal emulator with proot support
- **📊 Web Dashboard** — Embedded WebView for gateway management
- **📦 Model Manager** — Download and manage AI models
- **⚙️ Settings** — Configure gateway, models, and preferences
- **🔔 Foreground Service** — Keep gateway running in background

---

## 📋 Requirements

| Requirement | Details |
|-------------|---------|
| **Android** | 10 or higher (API 29) |
| **Storage** | ~2GB for Ubuntu + Node.js + Ollama + Models |
| **RAM** | 4GB+ recommended for larger models |
| **Architectures** | arm64-v8a, armeabi-v7a, x86_64 |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │ AI Dashboard │ │   Terminal   │ │   Model Manager  │     │
│  │  Mode Switch │ │   Emulator   │ │   Pull/Delete    │     │
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
│  │   │  ┌─────────────┐ ┌──────────────┐               │  │  │
│  │   │  │   Ollama    │ │  OpenClaw    │               │  │  │
│  │   │  │  :11434     │ │  Gateway     │               │  │  │
│  │   │  └─────────────┘ └──────────────┘               │  │  │
│  │   │  Routes: /ai/chat, /ai/code, /ai/advanced_code  │  │  │
│  │   └─────────────────────────────────────────────────┘  │  │
│  │   Models: /root/.ollama/models                        │  │
│  └────────────────────────────────────────────────────────┘  │
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
</p>