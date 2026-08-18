import Foundation
import Combine
import SwiftUI

class ShoppingManager: ObservableObject {
    static let shared = ShoppingManager()

    @Published var items: [ShoppingItem] = []
    @Published var friends: [Friend] = []
    @Published var observingFriend: Friend?
    @Published var observingItems: [ShoppingItem] = []
    @Published var friendListStatus: String = ""
    @Published var myCode: String = ""

    private let itemsKey = "bloom_shopping_items"
    private let friendsKey = "bloom_friends"
    private let sb = SupabaseManager.shared

    init() {
        loadLocalItems()
        loadFriends()
        generateMyCode()
    }

    // MARK: - Local Persistence

    private func loadLocalItems() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = decoded
        }
    }

    private func saveLocalItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
    }

    func loadFriends() {
        if let data = UserDefaults.standard.data(forKey: friendsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            self.friends = decoded
        }
    }

    func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(encoded, forKey: friendsKey)
        }
    }

    private func generateMyCode() {
        if let savedCode = UserDefaults.standard.string(forKey: "bloom_my_code") {
            self.myCode = savedCode
        } else {
            let newCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            UserDefaults.standard.set(newCode, forKey: "bloom_my_code")
            self.myCode = newCode
        }
    }

    /// Called after login to replace local data with cloud data
    func replaceWithCloudData(_ cloudItems: [ShoppingItem]) {
        items = cloudItems
        saveLocalItems()
    }

    func replaceWithCloudFriends(_ cloudFriends: [Friend]) {
        friends = cloudFriends
        saveFriends()
    }

    /// Clears all local user data — called on logout to prevent cross-user data leakage
    func clearLocalData() {
        items = []
        friends = []
        observingFriend = nil
        observingItems = []
        myCode = ""
        UserDefaults.standard.removeObject(forKey: itemsKey)
        UserDefaults.standard.removeObject(forKey: friendsKey)
        UserDefaults.standard.removeObject(forKey: "bloom_my_code")
    }

    // MARK: - CRUD (Local + Cloud)

    func addItem(name: String, quantity: String) {
        let newItem = ShoppingItem(name: name, quantity: quantity)
        items.insert(newItem, at: 0)
        saveLocalItems()
        syncToCloud(newItem)
    }

    func toggleItem(_ item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
            saveLocalItems()
            syncToCloud(items[index])
        }
    }

    func deleteItem(_ item: ShoppingItem) {
        items.removeAll(where: { $0.id == item.id })
        saveLocalItems()
        Task { try? await sb.deleteShoppingItem(id: item.id) }
    }

    func clearChecked() {
        let toDelete = items.filter { $0.isChecked }
        items.removeAll(where: { $0.isChecked })
        saveLocalItems()
        for item in toDelete {
            Task { try? await sb.deleteShoppingItem(id: item.id) }
        }
    }

    func clearAll() {
        let toDelete = items
        items.removeAll()
        saveLocalItems()
        for item in toDelete {
            Task { try? await sb.deleteShoppingItem(id: item.id) }
        }
    }

    func addFriend(code: String, name: String) {
        let newFriend = Friend(name: name, code: code)
        if !friends.contains(where: { $0.code == code }) {
            friends.append(newFriend)
            saveFriends()
            syncFriendToCloud(newFriend)
        }
    }

    func removeFriend(_ friend: Friend) {
        friends.removeAll(where: { $0.id == friend.id })
        saveFriends()
        Task { try? await sb.deleteFriend(id: friend.id) }
    }

    func updateFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index] = friend
            saveFriends()
            syncFriendToCloud(friend)
        }
    }

    func fetchItemsForFriend(_ friend: Friend) {
        observingFriend = friend
        observingItems = []
        friendListStatus = "In caricamento..."
        Task {
            do {
                if let profile = try await sb.findProfileByCode(friend.code) {
                    let sbItems = try await sb.fetchShoppingItems(forUserId: profile.userId)
                    let domainItems = sbItems.map { $0.toShoppingItem() }
                    await MainActor.run {
                        self.observingItems = domainItems
                        if domainItems.isEmpty {
                            self.friendListStatus = "La lista è vuota (oppure i permessi Supabase bloccano la lettura)."
                        } else {
                            self.friendListStatus = ""
                        }
                    }
                } else {
                    await MainActor.run {
                        self.friendListStatus = "Errore: Codice amico non trovato nel database."
                    }
                }
            } catch {
                await MainActor.run {
                    self.friendListStatus = "Errore di rete o permessi (RLS): \(error.localizedDescription)"
                }
                print("Errore fetch lista amico: \(error)")
            }
        }
    }

    func toggleObservingItem(_ item: ShoppingItem) {
        if let index = observingItems.firstIndex(where: { $0.id == item.id }) {
            observingItems[index].isChecked.toggle()
            let updated = observingItems[index]
            Task {
                try? await sb.updateShoppingItemChecked(id: updated.id, isChecked: updated.isChecked)
            }
        }
    }

    // MARK: - Live Realtime Sync

    private var syncTimer: AnyCancellable?

    func startLiveSync() {
        fetchFromCloudSilently()
        if let friend = observingFriend {
            fetchItemsForFriendSilently(friend)
        }
        syncTimer?.cancel()
        syncTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchFromCloudSilently()
                if let friend = self?.observingFriend {
                    self?.fetchItemsForFriendSilently(friend)
                }
            }
    }

    func stopLiveSync() {
        syncTimer?.cancel()
        syncTimer = nil
    }

    func fetchFromCloudSilently() {
        guard sb.isAuthenticated else { return }
        Task {
            do {
                let sbItems = try await sb.fetchShoppingItems()
                let cloudItems = sbItems.map { $0.toShoppingItem() }
                await MainActor.run {
                    if self.items != cloudItems {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.items = cloudItems
                        }
                        self.saveLocalItems()
                    }
                }
            } catch {
                // Silently ignore background polling errors
            }
        }
    }

    func fetchItemsForFriendSilently(_ friend: Friend) {
        guard sb.isAuthenticated else { return }
        Task {
            do {
                if let profile = try await sb.findProfileByCode(friend.code) {
                    let sbItems = try await sb.fetchShoppingItems(forUserId: profile.userId)
                    let domainItems = sbItems.map { $0.toShoppingItem() }
                    await MainActor.run {
                        if self.observingItems != domainItems {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.observingItems = domainItems
                            }
                        }
                    }
                }
            } catch {
                // Silently ignore background polling errors
            }
        }
    }

    // MARK: - Cloud Sync

    private func syncToCloud(_ item: ShoppingItem) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertShoppingItem(item) }
    }

    private func syncFriendToCloud(_ friend: Friend) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertFriend(friend) }
    }
}
