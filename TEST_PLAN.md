# PrivaClip: Test Plan & Acceptance Criteria

This document describes the automated test suite and the reproducible manual test procedures for verifying **PrivaClip** on macOS 14+ (Apple Silicon).

---

## 1. Automated Test Suite

PrivaClip includes an automated test runner written in Swift that verifies all non-UI subsystems: cryptography, Keychain abstraction, classification heuristics, persistence, corrupted file quarantine, backup/restore, and entitlement gating.

### Running the Automated Tests
```bash
swift run PrivaClipTests
```

### Verified Test Matrix (100% Pass Rate)

| Test Suite | Test Case | Target Verification | Status |
|---|---|---|---|
| **Crypto & Security** | `testAESGCMEncryptionRoundTrip` | Verifies plaintext encrypts to AES-GCM ciphertext and decrypts identically. | ✅ PASS |
| **Crypto & Security** | `testTamperedCiphertextRejection` | Flips bits in ciphertext and verifies AES-GCM tag rejection. | ✅ PASS |
| **Crypto & Security** | `testPBKDF2KeyDerivation` | Derives 256-bit key using PBKDF2 (100k rounds) with salt isolation. | ✅ PASS |
| **Crypto & Security** | `testSHA256Hashing` | Verifies consistent SHA-256 generation for duplicate detection. | ✅ PASS |
| **KeyManager** | `testInMemoryMasterKeyLifecycle` | Tests in-memory master key generation, persistence, and retrieval. | ✅ PASS |
| **SmartClassifier** | `testLinkClassification` | Validates detection of `https://` and `http://` URLs. | ✅ PASS |
| **SmartClassifier** | `testCodeClassification` | Validates heuristic detection of code snippets (Swift, JS, Python). | ✅ PASS |
| **SmartClassifier** | `testEmailClassification` | Validates RFC-5322 regex extraction of email addresses. | ✅ PASS |
| **SmartClassifier** | `testHexColorClassification` | Validates extraction of `#RRGGBB` hex color codes. | ✅ PASS |
| **Snippet Placeholders** | `testPlaceholderExpansion` | Validates `{date}`, `{time}`, `{clipboard}`, and `{cursor}` substitution. | ✅ PASS |
| **Persistence Safety** | `testEncryptedHistorySaveLoad` | Tests full serialization, at-rest encryption, and loading of history. | ✅ PASS |
| **Persistence Safety** | `testCorruptedHistoryQuarantine` | Writes invalid bytes, verifies graceful quarantine to `.corrupted.<timestamp>`. | ✅ PASS |
| **Backup & Restore** | `testEncryptedBackupExportRestore` | Exports `.privaclip` encrypted archive and restores into clean database. | ✅ PASS |
| **Entitlement Gating** | `testProEntitlementGating` | Verifies Pro feature access controls toggle correctly via local flag. | ✅ PASS |
| **Application Exclusion** | `testApplicationExclusionFilter` | Verifies blacklisted application bundle IDs are excluded from capture. | ✅ PASS |

---

## 2. Reproducible Manual Test Plan

Because certain macOS features (Accessibility keystroke injection, Carbon hotkeys, and menu-bar display) interact with the window server, perform the following manual test procedures:

### Manual Test 1: Menu Bar & Global Hotkey Activation
- **Procedure**:
  1. Launch PrivaClip: `open build/PrivaClip.app`.
  2. Observe the macOS menu bar: confirm the clipboard icon appears.
  3. Switch to any third-party application (e.g. Safari, Notes, or Terminal).
  4. Press the default global hotkey: `⌥V` (Option + V).
- **Expected Result**: The PrivaClip history panel opens immediately at the cursor location with search focused.

### Manual Test 2: Clipboard Capture & Deduplication
- **Procedure**:
  1. Copy a line of text in TextEdit: `Hello World 123`.
  2. Press `⌥V`. Confirm `Hello World 123` appears at the top of the history.
  3. Copy the exact same text again: `Hello World 123`.
  4. Press `⌥V`.
- **Expected Result**: No duplicate row is created. The existing item's timestamp is refreshed and remains at the top.

### Manual Test 3: Password Manager Transient Marker Compliance
- **Procedure**:
  1. In a password manager (1Password, Bitwarden, or KeePassXC), copy a password.
  2. Alternatively, copy text with transient markers using the command line:
     ```bash
     osascript -e 'set the clipboard to "super_secret_password"'
     ```
  3. Open PrivaClip (`⌥V`).
- **Expected Result**: Transient or concealed clipboard items are dropped and do not appear in history.

### Manual Test 4: Auto-Paste into Target Application
- **Procedure**:
  1. Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**.
  2. Open a text editor (e.g. Notes or TextEdit) and place the cursor in an empty line.
  3. Press `⌥V` to display PrivaClip.
  4. Use the `↓` arrow key to highlight an earlier clipboard item.
  5. Press `Return` (`↩`).
- **Expected Result**: PrivaClip hides, reactivates the text editor, and synthesizes `⌘V`, pasting the selected text into the editor.

### Manual Test 5: Manual Paste Fallback (Accessibility Denied)
- **Procedure**:
  1. Revoke Accessibility permission for PrivaClip in System Settings.
  2. Open PrivaClip (`⌥V`) and select an item by pressing `Return`.
- **Expected Result**: PrivaClip does not crash or hang. It copies the item to the pasteboard and displays a notification indicating that manual `⌘V` can be pressed.

### Manual Test 6: Smart Collections & Color Swatch Rendering
- **Procedure**:
  1. Copy a URL: `https://developer.apple.com`.
  2. Copy a Hex color: `#3B82F6`.
  3. Copy a Swift function: `func test() { return 42 }`.
  4. Open PrivaClip (`⌥V`).
  5. Click the **Links** chip: only the URL appears.
  6. Click the **Colors** chip: only `#3B82F6` appears, showing a rendered blue color swatch.
  7. Click the **Code** chip: only the Swift function appears with monospace code styling.
- **Expected Result**: Filter chips accurately isolate classified content types.

### Manual Test 7: Snippet Template Expansion
- **Procedure**:
  1. Open PrivaClip Preferences (`⌘,` or menu item) → **Snippets**.
  2. Create a snippet named `Daily Standup` with content:
     ```
     Standup Update: {date}
     Clipboard: {clipboard}
     ```
  3. Select and copy the word `Release Candidate`.
  4. Open PrivaClip (`⌥V`), switch to the Snippets tab, and select `Daily Standup`.
- **Expected Result**: The snippet expands today's date and the current clipboard text into the active application.

### Manual Test 8: POSIX Storage Security Audit
- **Procedure**:
  Run in Terminal:
  ```bash
  ls -ld ~/Library/Application\ Support/com.privaclip.app
  ls -la ~/Library/Application\ Support/com.privaclip.app
  ```
- **Expected Result**:
  - Directory permissions are `drwx------` (`0700`).
  - File permissions are `-rw-------` (`0600`).
  - All `.encrypted` files contain unreadable AES-GCM ciphertext.
