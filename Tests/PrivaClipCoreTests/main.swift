import Foundation
import CryptoKit
import AppKit
@testable import PrivaClipCore

// MARK: - Test Framework Helper

struct TestSuite {
    var passed = 0
    var failed = 0
    let name: String

    init(_ name: String) {
        self.name = name
        print("\n==========================================")
        print("▶ Running Test Suite: \(name)")
        print("==========================================")
    }

    mutating func test(_ description: String, block: () throws -> Void) {
        do {
            try block()
            passed += 1
            print("  ✅ [PASS] \(description)")
        } catch {
            failed += 1
            print("  ❌ [FAIL] \(description)")
            print("     Error: \(error)")
        }
    }

    func summarize() -> Bool {
        print("------------------------------------------")
        print("Results for \(name): \(passed) passed, \(failed) failed")
        return failed == 0
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard condition else {
        throw NSError(domain: "TestFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Assertion failed: \(message) at \(file):\(line)"])
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard a == b else {
        throw NSError(domain: "TestFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected equality, got '\(a)' != '\(b)'. \(message) at \(file):\(line)"])
    }
}

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard a != b else {
        throw NSError(domain: "TestFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected inequality, got '\(a)' == '\(b)'. \(message) at \(file):\(line)"])
    }
}

// MARK: - Main Test Execution

var allPassed = true

// 1. Crypto & Security Tests
var cryptoSuite = TestSuite("Crypto & Security Tests")
cryptoSuite.test("AES-GCM Authenticated Encryption & Decryption Round-Trip") {
    let key = SymmetricKey(size: .bits256)
    let sample = "PrivaClip top-secret clipboard item 12345! @#$%"
    let data = Data(sample.utf8)

    let encrypted = try CryptoService.encrypt(data: data, using: key)
    try assertNotEqual(encrypted, data, "Ciphertext should not equal plaintext")

    let decrypted = try CryptoService.decrypt(combinedData: encrypted, using: key)
    try assertEqual(decrypted, data, "Decrypted data must match original plaintext")
}

cryptoSuite.test("Tampered Ciphertext Rejection by AES-GCM Authentication Tag") {
    let key = SymmetricKey(size: .bits256)
    let data = Data("Confidential Message".utf8)
    var encrypted = try CryptoService.encrypt(data: data, using: key)

    // Tamper with one byte
    let mid = encrypted.count / 2
    encrypted[mid] ^= 0xFF

    var didCatch = false
    do {
        _ = try CryptoService.decrypt(combinedData: encrypted, using: key)
    } catch {
        didCatch = true
    }
    try assertTrue(didCatch, "Tampered ciphertext must be rejected")
}

cryptoSuite.test("PBKDF2 Key Derivation Consistency and Salt Isolation") {
    let password = "UserBackupPassword123"
    let salt1 = CryptoService.randomBytes(count: 16)
    let salt2 = CryptoService.randomBytes(count: 16)

    let keyA = CryptoService.deriveKey(from: password, salt: salt1, rounds: 10_000)
    let keyB = CryptoService.deriveKey(from: password, salt: salt1, rounds: 10_000)
    let keyC = CryptoService.deriveKey(from: password, salt: salt2, rounds: 10_000)

    let dataA = keyA.withUnsafeBytes { Data($0) }
    let dataB = keyB.withUnsafeBytes { Data($0) }
    let dataC = keyC.withUnsafeBytes { Data($0) }

    try assertEqual(dataA, dataB, "Identical password and salt must yield identical keys")
    try assertNotEqual(dataA, dataC, "Different salts must produce distinct keys")
}

cryptoSuite.test("SHA-256 Deduplication Hashing") {
    let d1 = Data("hello".utf8)
    let d2 = Data("hello".utf8)
    let d3 = Data("world".utf8)

    let h1 = CryptoService.sha256Hex(d1)
    let h2 = CryptoService.sha256Hex(d2)
    let h3 = CryptoService.sha256Hex(d3)

    try assertEqual(h1, h2)
    try assertNotEqual(h1, h3)
    try assertEqual(h1.count, 64)
}
if !cryptoSuite.summarize() { allPassed = false }

// 2. KeyManager Tests
var keySuite = TestSuite("KeyManager Tests")
keySuite.test("In-Memory Master Key Lifecycle") {
    KeyManager.shared.useInMemoryKeyForTesting = true
    let key1 = try KeyManager.shared.ensureKeyExists()
    let key2 = try KeyManager.shared.getKey()

    let d1 = key1.withUnsafeBytes { Data($0) }
    let d2 = key2.withUnsafeBytes { Data($0) }
    try assertEqual(d1, d2)

    try KeyManager.shared.deleteKey()
    let key3 = try KeyManager.shared.ensureKeyExists()
    let d3 = key3.withUnsafeBytes { Data($0) }
    try assertNotEqual(d1, d3, "New key after delete must be distinct")
}
if !keySuite.summarize() { allPassed = false }

// 3. SmartClassifier Tests
var classifierSuite = TestSuite("SmartClassifier Tests")
classifierSuite.test("Link / URL Recognition") {
    let urls = [
        "https://github.com/lighthouse-computer/Clip-Board",
        "http://example.com/page?id=123",
        "www.apple.com"
    ]
    for u in urls {
        let tags = SmartClassifier.classify(text: u)
        try assertTrue(tags.contains(.links), "Expected \(u) to be classified as .links")
    }
}

classifierSuite.test("Code Snippet Detection") {
    let snippets = [
        "func authenticateUser(token: String) -> Bool { return true; }",
        "const express = require('express'); const app = express();",
        "{\"status\": \"ok\", \"code\": 200, \"items\": []}",
        "<div class=\"container\"><p>Hello</p></div>"
    ]
    for s in snippets {
        let tags = SmartClassifier.classify(text: s)
        try assertTrue(tags.contains(.code), "Expected code snippet to be tagged .code")
    }
}

classifierSuite.test("Email Address Detection") {
    let email = "engineer@privaclip.internal"
    let tags = SmartClassifier.classify(text: email)
    try assertTrue(tags.contains(.emails), "Expected email to be tagged .emails")
}

classifierSuite.test("Hex Color Detection") {
    let colors = ["#FF5733", "#00AABB", "#FFF"]
    for c in colors {
        let tags = SmartClassifier.classify(text: c)
        try assertTrue(tags.contains(.colors), "Expected color \(c) to be tagged .colors")
    }
}
if !classifierSuite.summarize() { allPassed = false }

// 4. Snippets & Placeholder Tests
var snippetSuite = TestSuite("Snippet & Placeholders Tests")
snippetSuite.test("Placeholder Extraction and Substitution") {
    let template = "Hello {name}, your confirmation code is {code}. Regards, {team}."
    let snippet = Snippet(title: "Confirmation", content: template)

    let placeholders = snippet.placeholders
    try assertEqual(placeholders, ["name", "code", "team"])

    let resolved = snippet.resolve(with: [
        "name": "Alice",
        "code": "987654",
        "team": "PrivaClip Team"
    ])
    try assertEqual(resolved, "Hello Alice, your confirmation code is 987654. Regards, PrivaClip Team.")
}
if !snippetSuite.summarize() { allPassed = false }

// 5. Persistence & Quarantining Tests
var persistenceSuite = TestSuite("Persistence & File Safety Tests")
persistenceSuite.test("Encrypted History Save & Load Round-Trip") {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    AppPaths.customBaseDirectory = tempDir

    let testItems = [
        ClipItem(text: "Persistent item 1", pinned: true),
        ClipItem(text: "Persistent item 2", pinned: false)
    ]

    let exp = DispatchSemaphore(value: 0)
    PersistenceManager.shared.saveHistory(items: testItems) {
        exp.signal()
    }
    _ = exp.wait(timeout: .now() + 2.0)

    let loaded = PersistenceManager.shared.loadHistory()
    try assertEqual(loaded.count, 2)
    try assertEqual(loaded[0].text, "Persistent item 1")
    try assertTrue(loaded[0].pinned)
    try assertEqual(loaded[1].text, "Persistent item 2")
}

persistenceSuite.test("Corrupted History Quarantine") {
    let file = AppPaths.historyFile
    // Overwrite history file with garbage data
    let garbage = Data("This is invalid encrypted garbage data".utf8)
    try garbage.write(to: file)

    let loaded = PersistenceManager.shared.loadHistory()
    try assertEqual(loaded.count, 0, "Corrupted file should load empty array")

    // Verify quarantined file was created
    let contents = try FileManager.default.contentsOfDirectory(atPath: AppPaths.base.path)
    let quarantined = contents.filter { $0.hasPrefix("history.corrupted") }
    try assertTrue(!quarantined.isEmpty, "A quarantined file should have been generated")
}
if !persistenceSuite.summarize() { allPassed = false }

// 6. Encrypted Backup & Restore Tests
var backupSuite = TestSuite("Encrypted Backup & Restore Tests")
backupSuite.test("Archive Export and Restore Round-Trip with Passphrase") {
    let backupURL = AppPaths.backupsFolder.appendingPathComponent("test_archive.privaclip")
    let pass = "SecurePass123!"

    let sampleItems = [
        ClipItem(text: "Backup item 1", pinned: true),
        ClipItem(text: "Backup item 2", pinned: false)
    ]
    let sampleSnippets = [
        Snippet(title: "Test Snippet", content: "Snippet content")
    ]

    try BackupService.exportArchive(
        items: sampleItems,
        snippets: sampleSnippets,
        password: pass,
        destinationURL: backupURL
    )
    try assertTrue(FileManager.default.fileExists(atPath: backupURL.path))

    // Restore with correct password
    let (restoredItems, restoredSnippets) = try BackupService.importArchive(
        sourceURL: backupURL,
        password: pass
    )
    try assertEqual(restoredItems.count, 2)
    try assertEqual(restoredItems[0].text, "Backup item 1")
    try assertEqual(restoredSnippets.count, 1)
    try assertEqual(restoredSnippets[0].title, "Test Snippet")

    // Restore with WRONG password must fail
    var failedAsExpected = false
    do {
        _ = try BackupService.importArchive(sourceURL: backupURL, password: "WrongPassword")
    } catch {
        failedAsExpected = true
    }
    try assertTrue(failedAsExpected, "Import with wrong password must throw error")
}
if !backupSuite.summarize() { allPassed = false }

// 7. Entitlement & Preference Tests
var entitlementSuite = TestSuite("Entitlement & Preference Tests")
entitlementSuite.test("Pro Feature Entitlement Gating") {
    AppPreferences.shared.isProUnlocked = true
    try assertTrue(EntitlementManager.isProActive)
    try assertTrue(EntitlementManager.isFeatureAvailable(.smartCollections))
    try assertTrue(EntitlementManager.isFeatureAvailable(.snippetVault))
    try assertTrue(EntitlementManager.isFeatureAvailable(.encryptedBackup))

    AppPreferences.shared.isProUnlocked = false
    try assertTrue(!EntitlementManager.isProActive)
    try assertTrue(!EntitlementManager.isFeatureAvailable(.smartCollections))

    // Restore to true
    AppPreferences.shared.isProUnlocked = true
}

entitlementSuite.test("Application Exclusion Filter") {
    var excluded = AppPreferences.shared.excludedBundleIDs
    excluded.insert("com.agilebits.onepassword-osx")
    AppPreferences.shared.excludedBundleIDs = excluded

    try assertTrue(AppPreferences.shared.excludedBundleIDs.contains("com.agilebits.onepassword-osx"))
}
if !entitlementSuite.summarize() { allPassed = false }

// Final Summary
print("\n==========================================")
if allPassed {
    print("🎉 ALL TESTS PASSED SUCCESSFULLY! (100% PASS RATE)")
    print("==========================================\n")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED.")
    print("==========================================\n")
    exit(1)
}
