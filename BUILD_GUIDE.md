# Unified AI Gateway - Quick Build Guide

## Overview

The unified-ai-gateway repository has been fully merged into a single Flutter APK. All Node.js gateway code is embedded in the app's assets and runs inside a proot Ubuntu environment on Android.

## What's Included

### Embedded Gateway Files
All files from `lib/` are copied to `flutter_app/assets/gateway/`:
- `unified-gateway.js` - HTTP + WebSocket server
- `ollama/index.js` - Cloud LLM provider (30+ free models)
- `installer.js` - Dependency installer
- `bionic-bypass.js` - Android network workaround
- `package.json` - Node.js dependencies

### Kotlin Service Integration
`GatewayService.kt` has been updated to:
1. Copy gateway files from assets on first run
2. Install npm dependencies automatically
3. Start the gateway in proot Ubuntu
4. Handle auto-restart on crashes
5. Show foreground notification with uptime

## Build Instructions

### Prerequisites
- Flutter SDK 3.2.0+
- Android SDK (API 29+)
- Java JDK 11+
- Node.js 18+ (for verification)

### Quick Build

```bash
# Navigate to flutter app
cd flutter_app

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build release APKs per ABI (smaller files)
flutter build apk --release --split-per-abi
```

### Using the Build Script

```bash
# From repository root
chmod +x build-apk.sh
./build-apk.sh
```

## APK Output Locations

| Build Type | Output Path |
|------------|-------------|
| Debug | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release | `build/app/outputs/flutter-apk/app-release.apk` |
| Release (arm64) | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Release (armv7) | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` |
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |

## Installation

```bash
# Install via ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Or transfer APK to device and install manually
```

## Testing

### Verify Gateway Integration

```bash
# Check assets are copied
ls flutter_app/assets/gateway/lib/

# Verify package.json
cat flutter_app/assets/gateway/package.json

# Run Node.js tests
cd unified-ai-gateway
npm test
```

### Runtime Verification

After installing the APK:
1. Open the app
2. Go to Settings → Advanced
3. Enable "Developer Mode"
4. Check gateway logs for startup messages

## API Endpoints

Once the gateway is running:

### HTTP (Port 18789)

```bash
# Status check
curl http://localhost:18789/status

# Chat completion
curl -X POST http://localhost:18789/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!", "history": []}'

# Code generation
curl -X POST http://localhost:18789/ai/code \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a sort function", "language": "JavaScript"}'

# List models
curl http://localhost:18789/models
```

### WebSocket (Port 18790)

```javascript
const ws = new WebSocket('ws://localhost:18790');

ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'chat',
    content: 'Hello!',
    history: []
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(data);
};
```

## Free Cloud Models

### Chat Models (14)
- Qwen3.5 (397B) - Best overall
- Kimi-K2.5 - Multimodal
- GLM-5 (744B) - Reasoning
- MiniMax-M2.5 - Productivity
- Llama3.2:7b/3b - Fast
- Gemma2:9b - Google
- Mistral:7b
- Phi3:14b - Microsoft

### Code Models (15)
- Qwen3-Coder-Next - Best coding
- DeepSeek-V3/V3.2/R1 (671B)
- GLM-5/4.7/4.6
- Qwen2.5-Coder:32b/7b
- CodeLlama:7b

### Vision Models (5)
- Qwen3-VL:32b/8b/4b
- Llama3.2-Vision:11b/90b

## Troubleshooting

### Gateway Won't Start

```bash
# Check logs
adb logcat | grep -i "unified\|gateway"

# Clear app data
adb shell pm clear com.sadadonline17.cloudai_gateway

# Reinstall
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Models Not Loading

1. Check internet connection
2. Verify Ollama Cloud API is accessible
3. Try pulling models manually:
   ```bash
   curl -X POST http://localhost:18789/models/pull \
     -H "Content-Type: application/json" \
     -d '{"name": "qwen3.5"}'
   ```

### High Battery Usage

1. Disable battery optimization for the app
2. Use "Power Save" mode in settings
3. Reduce model context size

## Architecture

```
┌─────────────────────────────────────┐
│       Flutter App (Dart)            │
│  ┌──────────┐ ┌──────────┐         │
│  │Dashboard │ │ Terminal │         │
│  └────┬─────┘ └────┬─────┘         │
│       │             │               │
│  ┌────┴─────────────┴────┐         │
│  │  GatewayService (Kotlin) │       │
│  └────────────┬────────────┘       │
└───────────────┼───────────────────┘
                │
┌───────────────┼───────────────────┐
│  proot Ubuntu │  Node.js 22       │
│  ┌────────────┴────────────┐      │
│  │  Unified Gateway        │      │
│  │  - HTTP :18789          │      │
│  │  - WS   :18790          │      │
│  └─────────────────────────┘      │
└───────────────────────────────────┘
                │
              Internet
                │
┌───────────────┴───────────────────┐
│     Ollama Cloud API (Free)       │
└───────────────────────────────────┘
```

## License

MIT License - see LICENSE file.

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push and open PR

## Support

- Issues: https://github.com/sadadonline17-oss/unified-ai-gateway/issues
- Discussions: https://github.com/sadadonline17-oss/unified-ai-gateway/discussions

---

**Made with ❤️ for the Android AI community**
