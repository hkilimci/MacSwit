import Foundation
import Combine

/// Akıllı priz yapılandırmalarının kalıcı deposu.
///
/// Priz listesini `UserDefaults` üzerinde, hassas kimlik bilgilerini (Access Secret)
/// ise `KeychainStore` üzerinde saklar. CRUD işlemleri, aktif priz seçimi ve
/// Keychain entegrasyonunu sağlar.
@MainActor
final class PlugStore: ObservableObject {
    private static let plugConfigsKey = "MacSwit.plugConfigs"
    private static let activePlugIdKey = "MacSwit.activePlugId"
    private static let accessIdMigratedKey = "MacSwit.accessIdMigrated"

    @Published var plugs: [PlugConfig] = []
    @Published var activePlugId: UUID?

    private let keychain = KeychainStore.shared
    private let defaults = UserDefaults.standard

    var activePlug: PlugConfig? {
        guard let id = activePlugId else { return nil }
        return plugs.first { $0.id == id }
    }

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ config: PlugConfig) {
        plugs.append(config)
        if activePlugId == nil {
            activePlugId = config.id
        }
        save()
    }

    func update(_ config: PlugConfig) {
        guard let index = plugs.firstIndex(where: { $0.id == config.id }) else { return }
        plugs[index] = config
        save()
    }

    func delete(_ id: UUID) {
        guard let config = plugs.first(where: { $0.id == id }) else { return }
        // Clean up keychain entries
        try? keychain.deleteSecret(account: config.keychainAccount)
        try? keychain.deleteSecret(account: config.keychainAccessIdAccount)
        plugs.removeAll { $0.id == id }
        if activePlugId == id {
            activePlugId = plugs.first?.id
        }
        save()
    }

    func setActive(_ id: UUID) {
        guard plugs.contains(where: { $0.id == id }) else { return }
        activePlugId = id
        save()
    }

    // MARK: - Secret helpers

    func readSecret(for config: PlugConfig) -> String {
        (try? keychain.readSecret(account: config.keychainAccount)) ?? ""
    }

    func saveSecret(_ secret: String, for config: PlugConfig) throws {
        if secret.isEmpty {
            try keychain.deleteSecret(account: config.keychainAccount)
        } else {
            try keychain.saveSecret(secret, account: config.keychainAccount)
        }
    }

    // MARK: - Access ID helpers

    func readAccessId(for config: PlugConfig) -> String {
        (try? keychain.readSecret(account: config.keychainAccessIdAccount)) ?? ""
    }

    func saveAccessId(_ accessId: String, for config: PlugConfig) throws {
        if accessId.isEmpty {
            try keychain.deleteSecret(account: config.keychainAccessIdAccount)
        } else {
            try keychain.saveSecret(accessId, account: config.keychainAccessIdAccount)
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Self.plugConfigsKey),
           let decoded = try? JSONDecoder().decode([PlugConfig].self, from: data) {
            plugs = decoded
        }
        if let idString = defaults.string(forKey: Self.activePlugIdKey),
           let id = UUID(uuidString: idString) {
            activePlugId = id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plugs) {
            defaults.set(data, forKey: Self.plugConfigsKey)
        }
        if let id = activePlugId {
            defaults.set(id.uuidString, forKey: Self.activePlugIdKey)
        } else {
            defaults.removeObject(forKey: Self.activePlugIdKey)
        }
    }
}
