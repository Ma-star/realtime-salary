import CryptoKit
import Foundation
import Security
import SwiftUI

@MainActor
final class SalaryStore: ObservableObject {
    @Published var profile: SalaryProfile? { didSet { persist(profile, as: .profile) } }
    @Published private(set) var records: [SessionRecord] = [] { didSet { persist(records, as: .records) } }
    @Published private(set) var activeSession: WorkSessionState? { didSet { persist(activeSession, as: .session) } }
    @Published var usesDarkMode = false { didSet { UserDefaults.standard.set(usesDarkMode, forKey: Keys.darkMode) } }

    var preferredColorScheme: ColorScheme? { usesDarkMode ? .dark : nil }

    private enum Keys {
        static let legacyProfile = "salary-profile-v1"
        static let legacyRecords = "salary-records-v1"
        static let darkMode = "salary-dark-mode-v1"
    }
    private enum Record: String { case profile, records, session }
    private let vault = SecureVault()

    init() {
        profile = vault.read(SalaryProfile.self, named: Record.profile.rawValue)
        records = vault.read([SessionRecord].self, named: Record.records.rawValue) ?? []
        activeSession = vault.read(WorkSessionState.self, named: Record.session.rawValue)
        usesDarkMode = UserDefaults.standard.bool(forKey: Keys.darkMode)
        migrateLegacyPlaintextIfNeeded()
    }

    func saveActiveSession(_ session: WorkSessionState) { activeSession = session }
    func clearActiveSession() { activeSession = nil }

    func saveSettlement(_ result: DailySettlement, mood: Mood, releaseChoice: String) {
        guard result.elapsed >= 1 else { return }
        records.insert(SessionRecord(duration: result.elapsed, paidDuration: result.paid, unpaidBreakDuration: result.unpaidBreak, earnings: result.baseAccrued, overtimeEstimated: result.overtimeEstimated, bonusAccrued: result.bonusAccrued, mood: mood, releaseChoice: releaseChoice), at: 0)
        records = Array(records.prefix(90))
        activeSession = nil
    }

    func eraseAllPrivateData() {
        profile = nil; records = []; activeSession = nil
        vault.eraseAll()
        UserDefaults.standard.removeObject(forKey: Keys.legacyProfile)
        UserDefaults.standard.removeObject(forKey: Keys.legacyRecords)
    }

    private func persist<T: Encodable>(_ value: T?, as record: Record) {
        guard let value else { vault.delete(named: record.rawValue); return }
        vault.write(value, named: record.rawValue)
    }

    private func migrateLegacyPlaintextIfNeeded() {
        let defaults = UserDefaults.standard
        if profile == nil, let data = defaults.data(forKey: Keys.legacyProfile), let decoded = try? JSONDecoder().decode(SalaryProfile.self, from: data) { profile = decoded }
        if records.isEmpty, let data = defaults.data(forKey: Keys.legacyRecords), let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) { records = decoded }
        defaults.removeObject(forKey: Keys.legacyProfile)
        defaults.removeObject(forKey: Keys.legacyRecords)
    }
}

private final class SecureVault {
    private let service = "com.realtimesalary.local-vault"
    private let keyAccount = "aes-gcm-key-v1"

    func write<T: Encodable>(_ value: T, named name: String) {
        guard let encoded = try? JSONEncoder().encode(value), let sealed = try? AES.GCM.seal(encoded, using: key()), let combined = sealed.combined else { return }
        let url = fileURL(name)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? combined.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func read<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        let url = fileURL(name)
        guard let data = try? Data(contentsOf: url), let box = try? AES.GCM.SealedBox(combined: data), let clear = try? AES.GCM.open(box, using: key()) else { return nil }
        return try? JSONDecoder().decode(type, from: clear)
    }

    func delete(named name: String) { try? FileManager.default.removeItem(at: fileURL(name)) }

    func eraseAll() {
        try? FileManager.default.removeItem(at: directoryURL)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: keyAccount]
        SecItemDelete(query as CFDictionary)
    }

    private var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PrivateSalaryVault", isDirectory: true)
    }
    private func fileURL(_ name: String) -> URL { directoryURL.appendingPathComponent("\(name).vault") }

    private func key() -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: keyAccount, kSecReturnData as String: true]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data { return SymmetricKey(data: data) }
        let data = Data(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
        let insert: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: keyAccount, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        SecItemAdd(insert as CFDictionary, nil)
        return SymmetricKey(data: data)
    }
}
