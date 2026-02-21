# Unified AI Gateway - دليل البناء

## دمج المستودع في APK واحد

تم دمج جميع ملفات unified-ai-gateway في تطبيق Flutter APK واحد.

## التغييرات المطبقة

### 1. ملفات Gateway المدمجة
تم نسخ جميع الملفات من `/lib/` إلى `flutter_app/assets/gateway/`:
- `lib/gateway/unified-gateway.js` - Unified Gateway HTTP + WebSocket
- `lib/ollama/index.js` - Ollama Provider مع دعم السحاب
- `lib/installer.js` - مثبت التبعيات
- `lib/bionic-bypass.js` - تجاوز Bionic على Android
- `lib/test.js` - اختبارات
- `package.json` و `package-lock.json`
- `bin/unified-ai` - CLI

### 2. تحديثات Flutter
- **pubspec.yaml**: إضافة assets/gateway/
- **GatewayService.kt**: 
  - نسخ الملفات من assets عند البدء
  - تثبيت dependencies عبر npm
  - تشغيل gateway باستخدام Node.js في proot
  - دعم إعادة التشغيل التلقائي

### 3. التحسينات
- دعم 30+ نموذج سحابي مجاني (Qwen3.5, DeepSeek-V3, GLM-5)
- إصلاح `spawn` import في ollama/index.js
- واجهة إشعارات محسنة
- إدارة الطاقة عبر WakeLock

## كيفية البناء

### المتطلبات
- Flutter SDK 3.2.0 أو أحدث
- Android SDK (API 29+)
- Node.js 18+ (للتحقق من الكود)
- proot-distro (على Termux)

### خطوات البناء

```bash
# 1. الانتقال إلى مجلد Flutter
cd flutter_app

# 2. تثبيت تبعيات Flutter
flutter pub get

# 3. التحقق من الكود
flutter analyze

# 4. بناء APK للتطوير
flutter build apk --debug

# 5. بناء APK للإصدار
flutter build apk --release

# 6. بناء App Bundle (للنشر على Play Store)
flutter build appbundle --release
```

### البناء من سطر الأوامر مباشرة

```bash
# تطوير سريع
flutter build apk --debug --target-platform android-arm64

# إصدار محسّن
flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi
```

## هيكل المشروع

```
unified-ai-gateway/
├── lib/                          # Node.js Gateway (المصدر)
│   ├── gateway/
│   │   └── unified-gateway.js
│   ├── ollama/
│   │   └── index.js
│   ├── bin/
│   │   └── unified-ai
│   ├── installer.js
│   ├── bionic-bypass.js
│   └── test.js
├── flutter_app/                  # تطبيق Android
│   ├── assets/
│   │   └── gateway/             # Gateway المدمج
│   │       ├── lib/
│   │       ├── bin/
│   │       ├── package.json
│   │       └── start-gateway.sh
│   ├── android/
│   │   └── app/src/main/kotlin/
│   │       └── com/sadadonline17/cloudai/
│   │           ├── GatewayService.kt      # خدمة Gateway
│   │           ├── MainActivity.kt        # النشاط الرئيسي
│   │           └── ProcessManager.kt      # إدارة العمليات
│   └── lib/
│       ├── screens/
│       ├── services/
│       └── main.dart
└── package.json                  # تبعيات Node.js
```

## نقاط النهاية للـ API

### HTTP (Port 18789)
- `GET /status` - حالة Gateway و Ollama
- `POST /ai/chat` - إكمال المحادثة (streaming)
- `POST /ai/code` - إنشاء الكود
- `POST /ai/advanced_code` - مهام كود متقدمة
- `POST /ai/opencode` - أوضاع OpenCode/Claude/Codex
- `GET /models` - قائمة النماذج المتاحة
- `POST /models/pull` - سحب نموذج جديد
- `GET/POST /routing` - إعداد توجيه النماذج

### WebSocket (Port 18790)
```javascript
// رسالة محادثة
{ "type": "chat", "content": "مرحباً!", "history": [], "options": {} }

// إنشاء كود
{ "type": "code", "prompt": "اكتب دالة للترتيب", "options": {} }

// Ping
{ "type": "ping" }
```

## النماذج السحابية المجانية

### المحادثة (14 نموذج)
- Qwen3.5 (397B) - الأفضل بشكل عام
- Kimi-K2.5 - متعدد الوسائط
- GLM-5 (744B) - الاستدلال والوكلاء
- MiniMax-M2.5 - الإنتاجية والبرمجة
- Nemotron-3-Nano (30B) - الأدوات والتفكير
- Llama3.2:7b/3b - سريع
- Gemma2:9b - Google
- Mistral:7b
- Phi3:14b - Microsoft

### البرمجة (15 نموذج)
- Qwen3-Coder-Next - الأفضل للبرمجة
- DeepSeek-V3/V3.2/R1 (671B) - ممتاز
- GLM-5/4.7/4.6 - برمجة وكلاء
- Qwen2.5-Coder:32b/7b
- CodeLlama:7b
- Devstral-Small-2/2
- MiniMax-M2/M2.1
- Cogito-2.1 (671B)

### الرؤية (5 نماذج)
- Qwen3-VL:32b/8b/4b
- Llama3.2-Vision:11b/90b

## الترخيص

MIT License - راجع LICENSE للتفاصيل.

## المساهمة

المساهمات مرحب بها! يرجى قراءة إرشادات المساهمة قبل إرسال PR.

---

Made with ❤️ for the Android AI community
