<div align="center">
  <img src="assets/images/logo.png" alt="BuySellAdda" width="260" />

  # BuySellAdda Mobile App

  Har Deal, Ek Nayi Shuruaat

  A Flutter classifieds app for browsing local deals, posting ads, chatting with sellers, managing account settings, and staying logged in with saved tokens.

  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
  ![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
  ![Riverpod](https://img.shields.io/badge/Riverpod-State-40B5AD?style=for-the-badge)
  ![Socket.io](https://img.shields.io/badge/Socket.io-Chat-010101?style=for-the-badge&logo=socket.io&logoColor=white)
</div>

## Overview

The BuySellAdda mobile app brings the marketplace experience to Android and iOS. It uses the same backend as the web app and includes branded splash screens, token persistence, home feed, categories, product details, wishlist, account pages, language preferences, my ads, and chat screens.

## Features

| Area | Highlights |
| --- | --- |
| Splash | Smooth branded splash with BuySellAdda logo |
| Auth | Login, register, saved token session |
| Home | Product feed, categories, search-ready UI |
| Product Detail | Responsive product details with seller/contact actions |
| Chat | Buyer-seller chat flow connected to product context |
| Account | Profile, edit details, wishlist, my ads, privacy, help, language |
| Listings | Create/manage ads and view my ads |
| Media | Image picker and cached network images |
| Location | Geolocator and reverse geocoding support |

## Tech Stack

- Flutter
- Dart
- Riverpod
- Dio
- Shared Preferences
- Hive
- Socket.io Client
- Geolocator + Geocoding
- Image Picker
- Cached Network Image
- Flutter Dotenv

## Quick Start

```bash
cd deal
flutter pub get
flutter run
```

## Environment

The app reads `deal/.env`:

```env
BASE_URL=http://10.0.2.2:5000/api
SOCKET_URL=http://10.0.2.2:5000
```

For a physical device, use your computer or server IP:

```env
BASE_URL=http://YOUR_IP:5000/api
SOCKET_URL=http://YOUR_IP:5000
```

Current production-style example:

```env
BASE_URL=http://72.60.102.36:5003/api
SOCKET_URL=http://72.60.102.36:5003
```

## Scripts

```bash
flutter pub get       # Install packages
flutter run           # Run app
flutter analyze       # Static analysis
flutter test          # Run tests
flutter build apk     # Android release APK
flutter build appbundle
```

## Project Structure

```text
deal/
  lib/
    core/          App constants, language, theme, API helpers
    features/      Auth, home, product, chat, profile screens
    models/        Product, user, message models
    shared/        Reusable widgets
    main.dart      App entry point and routes
  assets/
    images/        BuySellAdda logo and app assets
    animations/    Lottie and animation files
  android/         Android platform project
  ios/             iOS platform project
  pubspec.yaml     Flutter dependencies and asset config
```

## Backend Connection

Start the backend first:

```bash
cd backend
npm install
npm run dev
```

Then update `deal/.env` so the app points to that backend.

## Build Notes

- `assets/images/logo.png` is used across splash, auth, and home branding.
- `flutter_dotenv` loads `.env`; keep it listed in `pubspec.yaml` assets.
- Android emulator uses `10.0.2.2` to reach the host machine.
- Real devices need a LAN or public server URL.

## Brand

Name: `BuySellAdda`

Tagline: `Har Deal, Ek Nayi Shuruaat`

Logo asset: `assets/images/logo.png`
