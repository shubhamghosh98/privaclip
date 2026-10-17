# PrivaClip: Free vs. Pro Feature Entitlements

PrivaClip is designed with a principled monetization architecture: **fundamental security and privacy protections are never paywalled.** The free version of PrivaClip provides an enterprise-secure clipboard history experience, while Pro unlocks advanced productivity workflows.

---

## 1. Feature Entitlement Matrix

| Feature | Free Tier | Pro Tier | Implementation Status |
|---|:---:|:---:|---|
| **AES-256-GCM At-Rest Encryption** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Hardware Keychain Master Key** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Password Manager Marker Filtering** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Zero Network Isolation** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Menu Bar & Global Hotkey (`⌥V`)** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Auto-Paste Target Restore** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Manual Paste Fallback Mode** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Clipboard Pinning & Deletion** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Configurable History Limits** | ✅ Included | ✅ Included | **Fully Implemented & Verified** |
| **Smart Collections (Links, Code, Emails, Colors)** | ❌ | ✅ | **Fully Implemented & Verified** |
| **Snippet Vault with Dynamic Expansions** | ❌ | ✅ | **Fully Implemented & Verified** |
| **Application Exclusion Rules (Blacklist)** | ❌ | ✅ | **Fully Implemented & Verified** |
| **Encrypted Backup & Restore (.privaclip)** | ❌ | ✅ | **Fully Implemented & Verified** |
| **Advanced Collection Filter Chips** | ❌ | ✅ | **Fully Implemented & Verified** |
| **Local Vision OCR Image Search** | ❌ | Planned | *Roadmap (Planned for Pro v2)* |
| **Private Zero-Knowledge CloudKit Sync** | ❌ | Deferred | *Roadmap (Deferred to protect zero-network policy)* |

---

## 2. Details of Implemented Pro Features

### 1. Smart Collections
- **Links & URLs**: Automatically parses and validates web addresses (`https://`, `http://`).
- **Code Snippets**: Heuristic syntax scoring identifies programming language constructs (curly braces, indentation, keywords like `func`, `class`, `import`, `const`).
- **Email Addresses**: Regex identification of standard email addresses.
- **Hex Colors**: Recognizes `#RRGGBB` and `#RGB` codes and renders a dynamic, live visual color swatch directly within the row.
- **Images**: Fast thumbnail preview of copied screenshots and images.

### 2. Snippet Library & Dynamic Placeholder Engine
Enables users to save frequently used text templates and paste them with one keystroke. Supports real-time substitution tokens:
- `{clipboard}`: Replaced with the current system pasteboard string.
- `{date}`: Replaced with today's date formatted as `YYYY-MM-DD`.
- `{time}`: Replaced with the current time formatted as `HH:mm:ss`.
- `{cursor}`: Directs cursor placement if the target editor supports synthetic caret positioning.

### 3. Application Exclusion Rules
Users can blacklist specific application bundle IDs (e.g., `com.apple.Terminal`, `com.googlecode.iterm2`, `com.tinyspeck.slackmacgap`, or banking apps). When an excluded application is in the foreground, `ClipboardWatcher` ignores all copy events.

### 4. Encrypted Backup & Restore
Users can export their complete history and snippet vault into a portable `.privaclip` encrypted file. The file is encrypted using PBKDF2 (100,000 iterations of HMAC-SHA256) and AES-GCM-256 with a user-specified passphrase.

---

## 3. Testing Entitlements in Development

PrivaClip strictly avoids mock payment dialogs or fake purchase success routines. Feature access is mediated by `EntitlementManager.swift`:

```swift
public enum EntitlementManager {
    public static var isProActive: Bool {
        AppPreferences.shared.isProUnlocked
    }
}
```

### How to Toggle Pro Status:
1. **Preferences UI**: In the PrivaClip Preferences panel, navigate to the **Pro** tab to toggle between Free and Pro mode for testing.
2. **Terminal / Defaults**:
   ```bash
   # Enable Pro features (default in development)
   defaults write com.privaclip.app privaclip.proUnlocked -bool true

   # Test Free mode restrictions
   defaults write com.privaclip.app privaclip.proUnlocked -bool false
   ```
3. **Automated Test Suite**:
   Run `swift run PrivaClipTests` to execute `testProEntitlementGating`, which programmatically tests both states.
