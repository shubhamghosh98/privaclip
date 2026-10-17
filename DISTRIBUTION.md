# PrivaClip: Distribution & Packaging Guide

This guide details the procedures for compiling, code-signing, notarizing, and distributing **PrivaClip** for macOS.

---

## 1. Quick Local Build (Ad-Hoc Signing)

For local development and testing on your own Apple Silicon Mac, run:

```bash
./scripts/build_app.sh
```

This script performs the following automated steps:
1. Compiles the native ARM64 binary with optimizations (`swift build -c release --product PrivaClip`).
2. Creates the standard macOS bundle directory layout:
   ```
   PrivaClip.app/
   └── Contents/
       ├── Info.plist
       ├── MacOS/
       │   └── PrivaClip
       └── Resources/
           └── AppIcon.icns
   ```
3. Injects `Resources/Info.plist` with `LSUIElement = true` (Menu Bar utility mode).
4. Embeds the multi-resolution `Resources/AppIcon.icns`.
5. Signs the bundle with hardened runtime and zero-network entitlements (`Resources/PrivaClip.entitlements`).
6. Archives the application into `build/PrivaClip-macOS-arm64.zip`.

---

## 2. Production Developer ID Signing & Notarization

To distribute PrivaClip to external macOS users without Gatekeeper warnings, sign the app with an Apple Developer ID Application certificate and submit it to Apple's Notary Service.

### Step 1: Sign with Developer ID
Set your Developer ID certificate identity and run the build script:
```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
./scripts/build_app.sh
```

### Step 2: Submit to Apple Notarization Service
Using `notarytool` (included with Xcode):
```bash
xcrun notarytool submit build/PrivaClip-macOS-arm64.zip \
    --keychain-profile "AC_PASSWORD" \
    --wait
```

### Step 3: Staple the Notarization Ticket
Once notarization succeeds, staple the ticket to the `.app` bundle:
```bash
xcrun stapler staple build/PrivaClip.app
```

### Step 4: Verify Gatekeeper Assessment
```bash
spctl -a -vvv -t install build/PrivaClip.app
```
*Expected Output*: `build/PrivaClip.app: accepted, source=Notarized Developer ID`.

---

## 3. Creating a Distributable Disk Image (.dmg)

To package PrivaClip into a drag-and-drop `.dmg` installer:
```bash
# 1. Prepare staging folder
mkdir -p build/dmg_stage
cp -R build/PrivaClip.app build/dmg_stage/
ln -s /Applications build/dmg_stage/Applications

# 2. Create DMG
hdiutil create -volname "PrivaClip" \
    -srcfolder build/dmg_stage \
    -ov -format UDZO \
    build/PrivaClip.dmg

# 3. Clean up staging folder
rm -rf build/dmg_stage

# 4. Sign and notarize DMG
codesign --sign "$DEVELOPER_ID" build/PrivaClip.dmg
xcrun notarytool submit build/PrivaClip.dmg --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple build/PrivaClip.dmg
```
