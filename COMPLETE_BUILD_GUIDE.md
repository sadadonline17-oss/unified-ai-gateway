# 🏗️ Unified AI Gateway - دليل البناء الشامل

## 📋 نظرة عامة

هذا الدليل يشرح جميع طرق البناء المتاحة لتطبيق Unified AI Gateway APK.

---

## 🚀 الطريقة 1: GitHub Actions (موصى بها)

### المميزات
- ✅ لا يحتاج تثبيت أي شيء محلياً
- ✅ بناء تلقائي عند كل push
- ✅ إصدار تلقائي عند إنشاء tag
- ✅ اختبار الكود تلقائياً

### الخطوات

#### 1.1 الدفع إلى GitHub

```bash
# التأكد من وجود جميع الملفات
git status

# إضافة الملفات الجديدة
git add .

# Commit
git commit -m "feat: merge unified gateway into Flutter APK"

# Push إلى GitHub
git push origin main
```

#### 1.2 البناء التلقائي

عند الدفع إلى `main` أو إنشاء tag، سيقوم GitHub Actions بـ:

1. التحقق من الكود (Node.js tests + ESLint)
2. التحقق من gateway assets
3. بناء Debug APK
4. بناء Release APK (universal + per-ABI)
5. بناء App Bundle
6. إنشاء إصدار GitHub (عند استخدام tag)

#### 1.3 إنشاء إصدار جديد

```bash
# إنشاء tag جديد
git tag v2.0.0

# دفع tag إلى GitHub
git push origin v2.0.0
```

سيتم إنشاء إصدار GitHub تلقائياً مع جميع ملفات APK.

#### 1.4 البناء اليدوي من GitHub

1. اذهب إلى **Actions** في GitHub
2. اختر **"Build Unified AI Gateway APK"**
3. انقر **Run workflow**
4. انتظر اكتمال البناء (~20-30 دقيقة)
5. حمّل APK من **Artifacts**

---

## 💻 الطريقة 2: Docker (للبuild المحلي)

### المميزات
- ✅ بيئة بناء معزولة
- ✅ نتائج متسقة
- ✅ لا يحتاج تثبيت Flutter/Android SDK محلياً

### المتطلبات
- Docker مثبت

### الخطوات

#### 2.1 بناء صورة Docker

```bash
cd unified-ai-gateway
docker build -f Dockerfile.build -t unified-ai-gateway-builder .
```

#### 2.2 بناء Debug APK

```bash
docker run --rm \
  -v $(pwd)/flutter_app/build:/build/flutter_app/build \
  unified-ai-gateway-builder
```

#### 2.3 بناء Release APK

```bash
# Universal APK
docker run --rm \
  -v $(pwd)/flutter_app/build:/build/flutter_app/build \
  unified-ai-gateway-builder \
  flutter build apk --release

# Split per ABI
docker run --rm \
  -v $(pwd)/flutter_app/build:/build/flutter_app/build \
  unified-ai-gateway-builder \
  flutter build apk --release --split-per-abi

# App Bundle
docker run --rm \
  -v $(pwd)/flutter_app/build:/build/flutter_app/build \
  unified-ai-gateway-builder \
  flutter build appbundle --release
```

#### 2.4 استخراج APK

```bash
mkdir -p artifacts

docker run --rm \
  -v $(pwd)/artifacts:/artifacts \
  unified-ai-gateway-builder \
  sh -c "cp -r build/app/outputs/flutter-apk/*.apk /artifacts/"

# APKs will be in ./artifacts/
ls -la artifacts/
```

---

## 🔧 الطريقة 3: البناء المحلي المباشر

### المتطلبات

| البرنامج | الإصدار | التثبيت |
|---------|---------|---------|
| Flutter | 3.24.0+ | [flutter.dev](https://flutter.dev) |
| Java | 17+ | `sudo apt install openjdk-17-jdk` |
| Android SDK | API 34 | [Android Studio](https://developer.android.com/studio) |
| Node.js | 18+ | `nvm install 22` |

### الخطوات

#### 3.1 إعداد البيئة

```bash
# تثبيت Flutter (Linux)
sudo snap install flutter --classic

# تثبيت Java
sudo apt install openjdk-17-jdk

# تثبيت Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# التحقق من التثبيت
flutter --version
java -version
node --version
```

#### 3.2 إعداد Android SDK

```bash
# في Android Studio:
# 1. Tools → SDK Manager
# 2. Install:
#    - Android SDK Platform 34
#    - Android SDK Build-Tools 34.0.0
#    - Android SDK Command-line Tools

# أو يدوياً:
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

sdkmanager "platforms;android-34"
sdkmanager "build-tools;34.0.0"
```

#### 3.3 إعداد Keystore للتوقيع

```bash
# تشغيل سكريبت الإعداد
cd unified-ai-gateway
./scripts/setup-keystore.sh

# اتبع التعليمات وأدخل المعلومات المطلوبة
# احفظ بيانات الاعتماد في مكان آمن!
```

#### 3.4 بناء APK

```bash
cd flutter_app

# تثبيت التبعيات
flutter pub get

# تحليل الكود
flutter analyze

# بناء Debug APK
flutter build apk --debug

# بناء Release APK
flutter build apk --release

# بناء Release APK per ABI
flutter build apk --release --split-per-abi

# بناء App Bundle
flutter build appbundle --release
```

#### 3.5 مواقع الملفات

```
flutter_app/build/outputs/
├── apk/
│   └── release/
│       ├── app-release.apk              # Universal APK
│       ├── app-arm64-v8a-release.apk    # ARM 64-bit
│       ├── app-armeabi-v7a-release.apk  # ARM 32-bit
│       └── app-x86_64-release.apk       # x86_64
└── bundle/
    └── release/
        └── app-release.aab              # App Bundle
```

---

## 📊 مقارنة طرق البناء

| الطريقة | السرعة | التعقيد | التكلفة | موصى بها |
|---------|--------|---------|---------|----------|
| **GitHub Actions** | ⭐⭐⭐⭐ | ⭐ | مجاناً | ✅ نعم |
| **Docker** | ⭐⭐⭐ | ⭐⭐ | مجاناً | ⭐ نعم |
| **محلي** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | مجاناً | للمطورين |

---

## 🔍 التحقق من صحة APK

### 1. التحقق من التوقيع

```bash
# للـ APK المشفر
jarsigner -verify -verbose -certs app-release.apk

# يجب أن ترى: "jar verified"
```

### 2. التحقق من المحتوى

```bash
# عرض محتويات APK
unzip -l app-release.apk | head -50

# التحقق من وجود gateway assets
unzip -l app-release.apk | grep gateway
```

### 3. اختبار التثبيت

```bash
# تثبيت على جهاز متصل عبر ADB
adb install -r app-release.apk

# أو محاكي
adb -e install -r app-release.apk
```

### 4. اختبار التشغيل

```bash
# تشغيل التطبيق
adb shell am start -n com.sadadonline17.cloudai_gateway/.MainActivity

# عرض السجلات
adb logcat | grep -i "unified\|gateway"
```

---

## 🐛 استكشاف الأخطاء

### خطأ: Flutter not found

```bash
# إضافة Flutter إلى PATH
export PATH=$PATH:/path/to/flutter/bin

# أو إعادة تثبيت Flutter
sudo snap install flutter --classic
```

### خطأ: Android SDK not found

```bash
# تعيين متغيرات البيئة
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
```

### خطأ: License not accepted

```bash
# قبول تراخيص Android SDK
sdkmanager --licenses
```

### خطأ: Build failed - Out of memory

```bash
# زيادة ذاكرة Gradle
echo "org.gradle.jvmargs=-Xmx4g" >> flutter_app/android/gradle.properties
```

### خطأ: Keystore not found

```bash
# التأكد من وجود key.properties
cat flutter_app/android/key.properties

# إعادة إنشاء keystore
./scripts/setup-keystore.sh
```

---

## 📦 حجم الملفات المتوقع

| نوع APK | الحجم التقريبي |
|---------|----------------|
| Debug APK | ~80-100 MB |
| Release (universal) | ~60-80 MB |
| Release (arm64-v8a) | ~40-50 MB |
| Release (armeabi-v7a) | ~35-45 MB |
| Release (x86_64) | ~45-55 MB |
| App Bundle | ~50-70 MB |

---

## 🎯 الخطوات التالية بعد البناء

### 1. الاختبار

```bash
# تثبيت على جهاز الاختبار
adb install -r artifacts/unified-ai-gateway-v2.0.0-arm64-v8a.apk

# اختبار الوظائف
# - فتح التطبيق
# - اكمل الإعداد
# - اسحب النماذج
# - اختبر المحادثة
```

### 2. التوقيع للإصدار

```bash
# للتوزيع العام، استخدم keystore مشفر
# راجع scripts/setup-keystore.sh
```

### 3. النشر

#### GitHub Releases
```bash
# إنشاء tag
git tag v2.0.0
git push origin v2.0.0

# سيتم إنشاء الإصدار تلقائياً
```

#### Google Play Store
```bash
# رفع App Bundle
# flutter_app/build/app/outputs/bundle/release/app-release.aab
```

#### التوزيع المباشر
```bash
# رفع APK إلى موقعك
# أو مشاركته مباشرة
```

---

## 📚 موارد إضافية

- [Flutter Documentation](https://flutter.dev/docs)
- [Android Build Documentation](https://developer.android.com/studio/build)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)

---

## 🤝 الدعم

للأسئلة والمشاكل:
- **GitHub Issues**: https://github.com/sadadonline17-oss/unified-ai-gateway/issues
- **Discussions**: https://github.com/sadadonline17-oss/unified-ai-gateway/discussions

---

**Made with ❤️ for the Android AI community**
