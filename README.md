# TrustFundMe Mobile (Flutter)

Flutter mobile app for TrustFundMe.

## Requirements

- **Flutter SDK**: 3.11+
- **Android Studio** (or VS Code) with Flutter/Dart extensions
- **Android Emulator** (recommended) or a real device

## Environment variables

This app reads environment variables from `.env` (loaded in `lib/main.dart`).

1. Create your local env file:

- Copy `.env.example` → `.env`

1. Configure base URL:

- **Android Emulator**: `API_BASE_URL=http://10.0.2.2`
- **iOS Simulator**: `API_BASE_URL=http://127.0.0.1`
- **Real device**: `API_BASE_URL=http://<YOUR_LAN_IP>`

1. Ports (defaults):

- `IDENTITY_PORT=8081`
- `CAMPAIGN_PORT=8082`
- `MEDIA_PORT=8083`
- `PAYMENT_PORT=8087`

## Run backend services

Donate flow uses these backend services:

- **identity-service** (login)
- **campaign-service** (campaigns + expenditure items)
- **payment-service** (create PayOS payment link + pre-check item limits)

Make sure your backend is running locally and accessible from the emulator/device.

## Install dependencies

From `TrustFundMe-Mobile/`:

```bash
flutter pub get
```

## Run the app

```bash
flutter run
```

If you have multiple devices:

```bash
flutter devices
flutter run -d <device_id>
```

## Donate flow (what to test)

1. Login
2. Go to **Chiến dịch**
3. Tap a campaign
4. Select expenditure items + quantities
5. Tap **Quyên góp ngay**
6. PayOS checkout opens in **WebView**

## Security notes (important)

- **Do not commit secrets** in `.env` (Supabase service role key, API keys, etc.).
- This repo now ignores `.env` via `.gitignore`. Use `.env.example` as a template.
