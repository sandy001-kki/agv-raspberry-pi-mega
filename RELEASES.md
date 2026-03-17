# AGV Flutter App - APK Releases

## Latest Release

You can download the latest APK for the AGV Flutter app from the [GitHub Releases](https://github.com/sandy001-kki/agv-raspberry-pi-mega/releases) page.

### 📥 Quick Download

[![Download AGV Controller APK](https://img.shields.io/badge/Download-AGV_controller.apk-brightgreen?style=for-the-badge&logo=android)](https://github.com/sandy001-kki/agv-raspberry-pi-mega/releases/download/v1.0.0/AGV-controller.apk)

### Installation Instructions

1. **Download the APK** from the latest release
2. **Enable Installation from Unknown Sources** (if not already enabled):
   - Go to Settings → Security → Unknown Sources → Enable
3. **Install the APK**:
   - Open the downloaded file and tap "Install"
   - Grant any requested permissions
4. **Connect to your AGV**:
   - Open the app
   - Enter your Raspberry Pi IP address (e.g., `192.168.1.100` or `agv-pi.local`)
   - Tap "Connect"

## Release History

| Version | Date | Download | Notes |
|---------|------|----------|-------|
| v1.0.0 | 2026-03-17 | [![Download](https://img.shields.io/badge/Download-brightgreen)](https://github.com/sandy001-kki/agv-raspberry-pi-mega/releases/download/v1.0.0/AGV-controller.apk) | Initial Flutter app release |

## Building the APK Locally

If you want to build the APK yourself:

```bash
cd app

# Get dependencies
flutter pub get

# Build APK (debug)
flutter build apk

# Build APK (release - recommended for distribution)
flutter build apk --release

# Output location
# build/app/outputs/flutter-apk/app-release.apk
```

## Publishing a New Release on GitHub

1. **Build the APK** (see above)
2. **Go to your GitHub repository** → Releases
3. **Click "Create a new release"**
4. **Set version tag** (e.g., `v1.0.0`)
5. **Upload the APK file** from `build/app/outputs/flutter-apk/app-release.apk`
6. **Add release notes** describing changes
7. **Publish release**

Users can then download from the Releases page.

## Supported Devices

- **Minimum SDK**: Android 5.0 (API Level 21)
- **Target SDK**: Android 13+ (Latest)
- **Architectures**: ARM, ARM64, x86, x86_64

---

For setup instructions on the Raspberry Pi and Arduino Mega hardware, see [README.md](README.md).
