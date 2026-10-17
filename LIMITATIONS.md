# PrivaClip: Known Limitations & Technical Constraints

This document records the architectural constraints, macOS platform limitations, and deliberately deferred features in **PrivaClip**.

---

## 1. Operating System & Platform Constraints

### 1.1 Synthetic Keystrokes & Accessibility Permissions
- **Constraint**: Injecting synthetic keystrokes (`⌘V`) into external applications requires the macOS Accessibility permission (`AXIsProcessTrusted`).
- **Impact**: If a user declines Accessibility permission, PrivaClip cannot auto-paste.
- **Mitigation**: PrivaClip implements a seamless fallback: it copies the item to the system clipboard and notifies the user to press `⌘V` manually.

### 1.2 Terminal & TUI Applications (vim, nano, tmux)
- **Constraint**: Certain command-line utilities operating in raw terminal mode may intercept or remap `⌘V` depending on terminal profile configurations (e.g., bracketed paste mode).
- **Mitigation**: PrivaClip allows adding terminal emulators (`com.apple.Terminal`, `com.googlecode.iterm2`) to the exclusion list or utilizing manual paste.

### 1.3 DRM & Secure Input Fields
- **Constraint**: When a macOS application enables `EnableSecureEventInput()` (such as password entry boxes in Safari or terminal `sudo` prompts), the system disables global hotkeys and clipboard event observation for that specific field.
- **Impact**: This is standard macOS behavior designed to protect master credentials from keystroke loggers.

---

## 2. Cryptographic & Security Boundaries

### 2.1 Process Memory Isolation
- **Boundary**: While all data at rest is encrypted with AES-256-GCM, data currently loaded into memory for user interaction in the PrivaClip process is plaintext in RAM.
- **Security Reality**: Under POSIX and macOS process models, any process running as root or with debugging entitlements under the same user UID could inspect process memory. PrivaClip makes no false claims of zero-knowledge protection against an already compromised host operating system.

### 2.2 iCloud Keychain Independence
- **Design Decision**: Master encryption keys are stored with `kSecAttrSynchronizable = false`.
- **Trade-off**: Backups exported to other Macs require entering the passphrase set during export, rather than silently unlocking via iCloud. This prevents cloud exposure of the master encryption key.

---

## 3. Deliberately Deferred & Unimplemented Features

### 3.1 Cloud Synchronization
- **Status**: **Deliberately Deferred.**
- **Rationale**: Cloud synchronization inherently increases the attack surface for clipboard credentials. PrivaClip strictly adheres to a Zero-Network architecture.

### 3.2 On-Device OCR Image Text Indexing (Apple Vision)
- **Status**: **Planned for Pro v2.**
- **Rationale**: While Apple Silicon's Neural Engine supports offline text recognition via `VNRecognizeTextRequest`, executing OCR over large image histories introduces background battery drain and processing spikes. This is queued for a future release with user-configurable background indexing schedules.

### 3.3 StoreKit 2 In-App Purchases
- **Status**: **Planned for App Store Distribution.**
- **Rationale**: For independent open-source and direct DMG distribution, PrivaClip provides an entitlement toggle (`isProUnlocked`) rather than requiring Apple App Store connectivity.
