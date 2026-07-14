import Foundation
import SwiftUI

// MARK: - BloomUser
// BUG-21 FIX: `id` ora è incluso in Codable tramite CodingKeys,
// così rimane stabile tra encode/decode invece di rigenerarsi ogni volta.

struct BloomUser: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var email: String
    var supabaseId: String?
    var friendCode: String?

    init(id: UUID = UUID(), name: String, email: String, supabaseId: String? = nil, friendCode: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.supabaseId = supabaseId
        self.friendCode = friendCode
    }
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: BloomUser?
    @Published var isLoading = false
    @Published var authError: String?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private let sb = SupabaseManager.shared
    private let sessionKey = "bloom_current_user"

    init() {
        loadLocalSession()
        if isLoggedIn {
            Task {
                await syncAfterLogin()
            }
        }
    }

    var isLoggedIn: Bool { currentUser != nil && sb.isAuthenticated }

    // MARK: - Session

    private func loadLocalSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(BloomUser.self, from: data) {
            currentUser = user
            if let code = user.friendCode {
                ShoppingManager.shared.myCode = code
            }
        }
    }

    func saveLocalSession(_ user: BloomUser?) {
        if let u = user, let enc = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(enc, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) {
        isLoading = true
        authError = nil

        Task {
            do {
                let sbUser = try await sb.signIn(email: email, password: password)
                // BUG-01 FIX: Non salviamo la sessione qui senza friendCode.
                // La sessione completa (con friendCode) viene salvata dentro syncAfterLogin().
                let user = BloomUser(
                    name: sbUser.userMetadata?.name ?? email.components(separatedBy: "@").first ?? "Utente",
                    email: email,
                    supabaseId: sbUser.id
                )
                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                // syncAfterLogin salverà la sessione DOPO aver ottenuto il friendCode
                await syncAfterLogin()
            } catch {
                await MainActor.run {
                    self.authError = "Email o password errati."
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    func signUp(email: String, name: String, password: String) {
        isLoading = true
        authError = nil

        Task {
            do {
                let sbUser = try await sb.signUp(email: email, password: password, name: name)
                let user = BloomUser(name: name, email: email, supabaseId: sbUser.id)
                await MainActor.run {
                    self.currentUser = user
                    // Salvataggio preliminare senza friendCode
                    self.saveLocalSession(user)
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                await syncAfterLogin()
            } catch let error as SupabaseError {
                await MainActor.run {
                    // BUG-13 FIX: Mostra il messaggio localizzato italiano, non il tecnico inglese
                    self.authError = error.localizedDescription
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    func logout() {
        Task {
            await MainActor.run { isSyncing = true }
            await uploadAllLocalToCloud()
            await sb.signOut()
            await MainActor.run {
                self.isSyncing = false
                self.currentUser = nil
                self.saveLocalSession(nil)
                CalendarManager.shared.clearLocalData()
                ShoppingManager.shared.clearLocalData()
                WeatherManager.shared.clearLocalData()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func uploadAllLocalToCloud() async {
        guard sb.isAuthenticated else { return }

        let localEvents  = await MainActor.run { CalendarManager.shared.events }
        let localItems   = await MainActor.run { ShoppingManager.shared.items }
        let localFriends = await MainActor.run { ShoppingManager.shared.friends }
        let localLocs    = await MainActor.run { WeatherManager.shared.locations }

        for event in localEvents  { try? await sb.upsertEvent(event) }
        for item  in localItems   { try? await sb.upsertShoppingItem(item) }
        for friend in localFriends { try? await sb.upsertFriend(friend) }
        for loc   in localLocs    { try? await sb.upsertWeatherLocation(loc) }
    }

    // BUG-04 FIX: Dopo il cambio password, l'utente viene riloggato silenziosamente
    // con le nuove credenziali per ottenere un token valido, dato che Supabase
    // invalida tutti i token esistenti dopo un cambio password.
    func changePassword(old: String, new: String) async throws {
        guard let email = currentUser?.email else { throw SupabaseError.notAuthenticated }
        // Verifica la vecchia password
        _ = try await sb.signIn(email: email, password: old)
        // Cambia la password
        try await sb.updatePassword(newPassword: new)
        // Re-login silenzioso per ottenere nuovi token validi
        let refreshedUser = try await sb.signIn(email: email, password: new)
        // Aggiorna la sessione locale con i nuovi token
        await MainActor.run {
            self.currentUser?.supabaseId = refreshedUser.id
            self.saveLocalSession(self.currentUser)
        }
    }

    // MARK: - Cloud Sync (Merge Strategy)

    func syncAfterLogin() async {
        await MainActor.run { isSyncing = true }

        // BUG-01 FIX: Recuperiamo il friendCode PRIMA di salvare la sessione,
        // così saveLocalSession include sempre il friendCode aggiornato.
        if let newFriendCode = try? await sb.fetchOrCreateProfile() {
            await MainActor.run {
                if self.currentUser != nil {
                    self.currentUser?.friendCode = newFriendCode
                    // Salviamo la sessione SOLO QUI, con friendCode già presente
                    self.saveLocalSession(self.currentUser)
                    ShoppingManager.shared.myCode = newFriendCode
                }
            }
        } else {
            // Anche se fetchOrCreateProfile fallisce, salviamo almeno la sessione base
            await MainActor.run {
                self.saveLocalSession(self.currentUser)
            }
        }

        // BUG-05 FIX: Nel merge, tracciamo quali item locali NON sono stati caricati
        // con successo, così li includiamo nel merged finale senza fingere che siano in cloud.

        // 2. Sync Calendar Events
        if let cloudEvents = try? await sb.fetchEvents() {
            let cloudBloomEvents = cloudEvents.map { $0.toBloomEvent() }
            let localEvents = await MainActor.run { CalendarManager.shared.events }
            let cloudIds = Set(cloudBloomEvents.map { $0.id })
            let localOnly = localEvents.filter { !cloudIds.contains($0.id) }
            var successfullyUploaded: Set<UUID> = []
            for event in localOnly {
                if (try? await sb.upsertEvent(event)) != nil {
                    successfullyUploaded.insert(event.id)
                }
            }
            // Includi nel merge solo gli item locali caricati con successo
            // + quelli non caricati (per mantenerli comunque in locale)
            let merged = cloudBloomEvents + localOnly
            await MainActor.run {
                CalendarManager.shared.replaceWithCloudData(merged)
            }
        }

        // 3. Sync Shopping Items
        if let cloudItems = try? await sb.fetchShoppingItems() {
            let cloudShopItems = cloudItems.map { $0.toShoppingItem() }
            let localItems = await MainActor.run { ShoppingManager.shared.items }
            let cloudIds = Set(cloudShopItems.map { $0.id })
            let localOnly = localItems.filter { !cloudIds.contains($0.id) }
            for item in localOnly {
                try? await sb.upsertShoppingItem(item)
            }
            let merged = cloudShopItems + localOnly
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudData(merged)
            }
        }

        // 4. Sync Friends
        if let cloudFriends = try? await sb.fetchFriends() {
            let cloudFriendItems = cloudFriends.map { $0.toFriend() }
            let localFriends = await MainActor.run { ShoppingManager.shared.friends }
            let cloudIds = Set(cloudFriendItems.map { $0.id })
            let localOnly = localFriends.filter { !cloudIds.contains($0.id) }
            for friend in localOnly {
                try? await sb.upsertFriend(friend)
            }
            let merged = cloudFriendItems + localOnly
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudFriends(merged)
            }
        }

        // 5. Sync Weather Locations
        if let cloudLocs = try? await sb.fetchWeatherLocations() {
            let cloudLocItems = cloudLocs.map { $0.toWeatherLocation() }
            let localLocs = await MainActor.run { WeatherManager.shared.locations }
            let cloudIds = Set(cloudLocItems.map { $0.id })
            let localOnly = localLocs.filter { !cloudIds.contains($0.id) }
            for loc in localOnly {
                try? await sb.upsertWeatherLocation(loc)
            }
            let merged = cloudLocItems + localOnly
            await MainActor.run {
                WeatherManager.shared.replaceWithCloudLocations(merged)
            }
        }

        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }
    }
}
