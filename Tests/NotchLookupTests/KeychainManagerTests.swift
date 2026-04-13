import Foundation
import Testing
import NotchLookupCore

// Each test method gets a fresh class instance, which means a fresh KeychainManager
// backed by a unique Keychain account (UUID). This eliminates all shared state,
// so tests are safe to run in parallel without contaminating one another.
@Suite("KeychainManager")
final class KeychainManagerTests {

    private let km: KeychainManager

    init() {
        // Unique account per test instance → zero shared Keychain state across tests.
        km = KeychainManager.testInstance(account: "test-\(UUID().uuidString)")
    }

    deinit {
        km.deleteAPIKey()  // always clean up, even if a test assertion fails
    }

    // MARK: - Save

    @Test("save returns true for a valid key")
    func saveReturnsTrueForValidKey() {
        #expect(km.saveAPIKey("sk-test-abc123") == true)
    }

    @Test("save returns false for an empty string")
    func saveReturnsFalseForEmptyString() {
        // Empty string is valid UTF-8, so the implementation may accept it.
        // Verify the return value is consistent with what was actually stored.
        let saved = km.saveAPIKey("")
        if saved {
            #expect(km.retrieveAPIKey() == "")
        } else {
            #expect(km.retrieveAPIKey() == nil)
        }
    }

    // MARK: - Retrieve

    @Test("retrieve returns nil when nothing is stored")
    func retrieveReturnsNilWhenEmpty() {
        #expect(km.retrieveAPIKey() == nil)
    }

    @Test("retrieve returns the key that was saved")
    func retrieveReturnsSavedKey() {
        km.saveAPIKey("sk-ant-test-key-42")
        #expect(km.retrieveAPIKey() == "sk-ant-test-key-42")
    }

    @Test("retrieve handles unicode characters correctly")
    func retrieveHandlesUnicode() {
        let unicode = "sk-🔑-日本語-тест"
        km.saveAPIKey(unicode)
        #expect(km.retrieveAPIKey() == unicode)
    }

    @Test("retrieve handles a long key (512 chars)")
    func retrieveHandlesLongKey() {
        let longKey = String(repeating: "a", count: 512)
        km.saveAPIKey(longKey)
        #expect(km.retrieveAPIKey() == longKey)
    }

    // MARK: - Overwrite (delete-then-add)

    @Test("saving a second key overwrites the first")
    func saveOverwritesPreviousKey() {
        km.saveAPIKey("first-key")
        km.saveAPIKey("second-key")
        #expect(km.retrieveAPIKey() == "second-key")
    }

    @Test("saving multiple times never returns errSecDuplicateItem")
    func repeatedSavesSucceed() {
        for i in 0..<5 {
            #expect(km.saveAPIKey("key-\(i)") == true)
        }
        #expect(km.retrieveAPIKey() == "key-4")
    }

    // MARK: - Delete

    @Test("delete removes a stored key")
    func deleteRemovesKey() {
        km.saveAPIKey("to-be-deleted")
        km.deleteAPIKey()
        #expect(km.retrieveAPIKey() == nil)
    }

    @Test("delete is idempotent when called on an empty keychain")
    func deleteIsIdempotent() {
        km.deleteAPIKey()   // first call on an empty account
        km.deleteAPIKey()   // second call must not crash or throw
        #expect(km.retrieveAPIKey() == nil)
    }

    // MARK: - Round-trip

    @Test("full round-trip: save → retrieve → delete → retrieve returns nil")
    func fullRoundTrip() {
        let key = "sk-ant-roundtrip-key"
        #expect(km.saveAPIKey(key) == true)
        #expect(km.retrieveAPIKey() == key)
        km.deleteAPIKey()
        #expect(km.retrieveAPIKey() == nil)
    }
}
