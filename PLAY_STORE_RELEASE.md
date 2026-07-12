# Play Store Release Build

This Flutter app is configured for a signed Android App Bundle using package:

```text
com.buyselladda.app
```

## One-Time Signing Setup

Run this from the project root:

```powershell
cd C:\Deal\deal\android\app
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `C:\Deal\deal\android\key.properties` from `key.properties.example`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Keep these files private and backed up safely:

```text
C:\Deal\deal\android\key.properties
C:\Deal\deal\android\app\upload-keystore.jks
```

They are already ignored by git.

## Version Code

Android release builds use `android/version.properties`:

```properties
VERSION_CODE=1
```

Whenever a release build is requested, Gradle automatically increases `VERSION_CODE` before creating the bundle. This prevents Play Console duplicate versionCode errors for normal future uploads.

If Play Console already has a higher uploaded versionCode, set `VERSION_CODE` in `android/version.properties` to that latest Play Console number before building again.

The visible app version still comes from `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

## Build App Bundle

Run this from `C:\Deal\deal`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Final AAB path:

```text
C:\Deal\deal\build\app\outputs\bundle\release\app-release.aab
```

## Important

Release builds now fail if signing is missing or wrong. This prevents accidentally uploading a debug-signed bundle to Play Store.
