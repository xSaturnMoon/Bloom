import Foundation
import Security

// MARK: - Keychain Helper

struct KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bloom.app",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bloom.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.bloom.app"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Supabase Response Models

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?

    struct UserMetadata: Codable {
        let name: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }
}

struct SupabaseAuthResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseSignUpResponse: Codable {
    let id: String?
    let email: String?
    let userMetadata: SupabaseUser.UserMetadata?
    let identities: [AnyCodableIgnored]?

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
        case identities
    }
}

struct AnyCodableIgnored: Codable {}

// MARK: - Supabase Event/Data Models

struct SupabaseEvent: Codable {
    let id: String
    let userId: String
    let title: String
    let date: String
    let startTime: String
    let endTime: String?
    let hasEndTime: Bool
    let isCompleted: Bool
    let reminderId: String?
    let reminders: [EventReminder]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, date
        case startTime = "start_time"
        case endTime = "end_time"
        case hasEndTime = "has_end_time"
        case isCompleted = "is_completed"
        case reminderId = "reminder_id"
        case reminders
    }

    func toBloomEvent() -> BloomEvent {
        let fmt = ISO8601DateFormatter()
        return BloomEvent(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            date: fmt.date(from: date) ?? Date(),
            startTime: fmt.date(from: startTime) ?? Date(),
            endTime: endTime.flatMap { fmt.date(from: $0) },
            hasEndTime: hasEndTime,
            isCompleted: isCompleted,
            reminderId: reminderId,
            reminders: reminders ?? []
        )
    }
}

struct SupabaseShoppingItem: Codable {
    let id: String
    let userId: String
    let name: String
    let quantity: String
    let isChecked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, quantity
        case isChecked = "is_checked"
    }

    func toShoppingItem() -> ShoppingItem {
        ShoppingItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            quantity: quantity,
            isChecked: isChecked
        )
    }
}

struct SupabaseFriend: Codable {
    let id: String
    let userId: String
    let friendName: String
    let friendCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendName = "friend_name"
        case friendCode = "friend_code"
    }

    func toFriend() -> Friend {
        Friend(
            id: UUID(uuidString: id) ?? UUID(),
            name: friendName,
            code: friendCode
        )
    }
}

struct SupabaseWeatherLocation: Codable {
    let id: String
    let userId: String
    let name: String
    let lat: Double
    let lon: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, lat, lon
    }

    func toWeatherLocation() -> WeatherLocation {
        WeatherLocation(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            lat: lat,
            lon: lon
        )
    }
}

// MARK: - Model Extensions

extension BloomEvent {
    func toSupabaseDict(userId: String) -> [String: Any] {
        let fmt = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": userId,
            "title": title,
            "date": fmt.string(from: date),
            "start_time": fmt.string(from: startTime),
            "has_end_time": hasEndTime,
            "is_completed": isCompleted
        ]
        if let et = endTime { dict["end_time"] = fmt.string(from: et) }
        if let rid = reminderId { dict["reminder_id"] = rid }

        if let remindersData = try? JSONEncoder().encode(reminders),
           let remindersVal = try? JSONSerialization.jsonObject(with: remindersData) {
            dict["reminders"] = remindersVal
        }

        return dict
    }
}

extension ShoppingItem {
    func toSupabaseDict(userId: String) -> [String: Any] {
        return [
            "id": id.uuidString,
            "user_id": userId,
            "name": name,
            "quantity": quantity,
            "is_checked": isChecked
        ]
    }
}

extension Friend {
    func toSupabaseDict(userId: String) -> [String: Any] {
        return [
            "id": id.uuidString,
            "user_id": userId,
            "friend_name": name,
            "friend_code": code
        ]
    }
}

extension WeatherLocation {
    func toSupabaseDict(userId: String) -> [String: Any] {
        return [
            "id": id.uuidString,
            "user_id": userId,
            "name": name,
            "lat": lat,
            "lon": lon
        ]
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case apiError(String)
    case httpError(Int)
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL non valido"
        case .notAuthenticated: return "Non sei autenticato"
        case .apiError(let msg): return msg
        case .httpError(let code): return "Errore HTTP \(code)"
        case .emailConfirmationRequired: return "Controlla la tua email per confermare la registrazione."
        }
    }
}

// MARK: - Supabase Manager

class SupabaseManager {
    static let shared = SupabaseManager()

    private let base = SupabaseConfig.url
    private let key  = SupabaseConfig.anonKey

    private(set) var accessToken: String?
    private(set) var userId: String?

    // BUG-03 FIX: Serializza il refresh token per evitare invalidazioni reciproche
    // quando più chiamate 401 arrivano in parallelo.
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<Void, Error>] = []

    private init() {
        accessToken = KeychainHelper.read(key: "sb_access_token")
        userId      = KeychainHelper.read(key: "sb_user_id")
    }

    var isAuthenticated: Bool { accessToken != nil && userId != nil }

    // MARK: - Session helpers

    private func saveSession(token: String, refresh: String, uid: String) {
        accessToken = token
        userId      = uid
        KeychainHelper.save(key: "sb_access_token", value: token)
        KeychainHelper.save(key: "sb_user_id", value: uid)
        KeychainHelper.save(key: "sb_refresh_token", value: refresh)
    }

    func clearSession() {
        accessToken = nil
        userId      = nil
        KeychainHelper.delete(key: "sb_access_token")
        KeychainHelper.delete(key: "sb_user_id")
        KeychainHelper.delete(key: "sb_refresh_token")
    }

    // MARK: - Auth

    /// BUG-13/23 FIX: Se Supabase non restituisce un token (email non confermata),
    /// lancia un errore esplicito invece di tentare un login silenzioso.
    func signUp(email: String, password: String, name: String) async throws -> SupabaseUser {
        // Validazione locale prima della chiamata di rete
        guard email.contains("@"), email.contains(".") else {
            throw SupabaseError.apiError("Inserisci un'email valida.")
        }
        guard password.count >= 6 else {
            throw SupabaseError.apiError("La password deve essere di almeno 6 caratteri.")
        }

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["name": name]
        ]

        var req = try makeRequest(path: "/auth/v1/signup", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)

        // Risposta con sessione completa (email confirmation disabilitata)
        if let r = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data),
           let token = r.accessToken, !token.isEmpty,
           let refresh = r.refreshToken, !refresh.isEmpty,
           let user = r.user {
            saveSession(token: token, refresh: refresh, uid: user.id)
            return user
        }

        // Risposta senza token → conferma email richiesta. NON fare signIn silenzioso.
        if let r = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data),
           let user = r.user {
            // L'utente esiste ma non ha token: email non confermata
            throw SupabaseError.emailConfirmationRequired
        }

        throw SupabaseError.apiError("Registrazione non riuscita. Riprova.")
    }

    func signIn(email: String, password: String) async throws -> SupabaseUser {
        let body: [String: Any] = ["email": email, "password": password]

        var req = try makeRequest(path: "/auth/v1/token?grant_type=password", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)

        let r = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        guard let token = r.accessToken, !token.isEmpty,
              let refresh = r.refreshToken, !refresh.isEmpty,
              let user = r.user else {
            throw SupabaseError.apiError("Risposta non valida dal server")
        }
        saveSession(token: token, refresh: refresh, uid: user.id)
        return user
    }

    // BUG-03 FIX: Token refresh serializzato. Se un refresh è già in corso,
    // le nuove chiamate attendono invece di invalidare il refresh token.
    func refreshSession() async throws {
        // Se stiamo già refreshando, aspetta che finisca
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        }

        isRefreshing = true
        defer {
            let result: Result<Void, Error>
            // Questo viene eseguito quando usciamo dalla funzione
            // ma Swift non ha un modo diretto di catturare l'errore nel defer
            // Usiamo il pattern di rilascio delle continuations dopo il blocco
            isRefreshing = false
        }

        do {
            guard let refreshToken = KeychainHelper.read(key: "sb_refresh_token") else {
                let error = SupabaseError.notAuthenticated
                resumeContinuations(with: .failure(error))
                throw error
            }

            let body: [String: Any] = ["refresh_token": refreshToken]
            var req = try makeRequest(path: "/auth/v1/token?grant_type=refresh_token", method: "POST")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)

            guard let http = resp as? HTTPURLResponse, http.statusCode < 400 else {
                let error = SupabaseError.notAuthenticated
                resumeContinuations(with: .failure(error))
                throw error
            }

            let r = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
            guard let token = r.accessToken, !token.isEmpty,
                  let newRefresh = r.refreshToken, !newRefresh.isEmpty,
                  let user = r.user else {
                let error = SupabaseError.apiError("Risposta non valida al refresh")
                resumeContinuations(with: .failure(error))
                throw error
            }
            saveSession(token: token, refresh: newRefresh, uid: user.id)
            resumeContinuations(with: .success(()))
        } catch {
            resumeContinuations(with: .failure(error))
            throw error
        }
    }

    private func resumeContinuations(with result: Result<Void, Error>) {
        let pending = refreshContinuations
        refreshContinuations = []
        for continuation in pending {
            continuation.resume(with: result)
        }
    }

    func signOut() async {
        guard let token = accessToken else { clearSession(); return }
        var req = (try? makeRequest(path: "/auth/v1/logout", method: "POST")) ?? URLRequest(url: URL(string: base)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
        clearSession()
    }

    func updatePassword(newPassword: String) async throws {
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        let body: [String: Any] = ["password": newPassword]
        var req = try makeRequest(path: "/auth/v1/user", method: "PUT")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)
    }

    // MARK: - Calendar Events CRUD

    func fetchEvents() async throws -> [SupabaseEvent] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await get(path: "/rest/v1/calendar_events?user_id=eq.\(uid)&select=*&order=date.asc")
    }

    func upsertEvent(_ event: BloomEvent) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = event.toSupabaseDict(userId: uid)
        try await postVoid(
            path: "/rest/v1/calendar_events",
            body: body,
            prefer: "resolution=merge-duplicates"
        )
    }

    func deleteEvent(id: UUID) async throws {
        try await delete(path: "/rest/v1/calendar_events?id=eq.\(id.uuidString)")
    }

    // MARK: - Shopping Items CRUD

    func fetchShoppingItems() async throws -> [SupabaseShoppingItem] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await fetchShoppingItems(forUserId: uid)
    }

    func fetchShoppingItems(forUserId targetUserId: String) async throws -> [SupabaseShoppingItem] {
        return try await get(path: "/rest/v1/shopping_items?user_id=eq.\(targetUserId)&select=*&order=created_at.asc")
    }

    func upsertShoppingItem(_ item: ShoppingItem) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = item.toSupabaseDict(userId: uid)
        try await postVoid(
            path: "/rest/v1/shopping_items",
            body: body,
            prefer: "resolution=merge-duplicates"
        )
    }

    func deleteShoppingItem(id: UUID) async throws {
        try await delete(path: "/rest/v1/shopping_items?id=eq.\(id.uuidString)")
    }

    // MARK: - Friends CRUD

    func fetchFriends() async throws -> [SupabaseFriend] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await get(path: "/rest/v1/user_friends?user_id=eq.\(uid)&select=*")
    }

    func upsertFriend(_ friend: Friend) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = friend.toSupabaseDict(userId: uid)
        try await postVoid(
            path: "/rest/v1/user_friends",
            body: body,
            prefer: "resolution=merge-duplicates"
        )
    }

    func deleteFriend(id: UUID) async throws {
        try await delete(path: "/rest/v1/user_friends?id=eq.\(id.uuidString)")
    }

    // MARK: - Weather Locations CRUD

    func fetchWeatherLocations() async throws -> [SupabaseWeatherLocation] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await get(path: "/rest/v1/weather_locations?user_id=eq.\(uid)&select=*")
    }

    func upsertWeatherLocation(_ loc: WeatherLocation) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = loc.toSupabaseDict(userId: uid)
        try await postVoid(
            path: "/rest/v1/weather_locations",
            body: body,
            prefer: "resolution=merge-duplicates"
        )
    }

    func deleteWeatherLocation(id: UUID) async throws {
        try await delete(path: "/rest/v1/weather_locations?id=eq.\(id.uuidString)")
    }

    // MARK: - HTTP Helpers

    /// BUG-02 FIX: makeRequest ora lancia un errore invece di fare crash con !
    private func makeRequest(path: String, method: String = "GET") throws -> URLRequest {
        // Costruisce la URL in modo sicuro, codificando i caratteri speciali
        let rawURLString = base + path
        guard let encodedString = rawURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            throw SupabaseError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func performRequest<T>(req: URLRequest, attempt: Int = 1, handler: (Data) throws -> T) async throws -> T {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            try checkStatus(data: data, response: resp)
            return try handler(data)
        } catch SupabaseError.httpError(401) where attempt == 1 {
            // Token scaduto → refresh serializzato (BUG-03 fixed)
            try await refreshSession()
            var newReq = req
            if let token = self.accessToken {
                newReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return try await performRequest(req: newReq, attempt: 2, handler: handler)
        }
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let req = try makeRequest(path: path)
        return try await performRequest(req: req) { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }

    private func postVoid(path: String, body: [String: Any], prefer: String? = nil) async throws {
        var req = try makeRequest(path: path, method: "POST")
        if let p = prefer { req.setValue(p, forHTTPHeaderField: "Prefer") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let _: Data = try await performRequest(req: req) { $0 }
    }

    private func delete(path: String) async throws {
        let req = try makeRequest(path: path, method: "DELETE")
        let _: Data = try await performRequest(req: req) { $0 }
    }

    private func checkStatus(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 {
            throw SupabaseError.httpError(401)
        }
        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = json["message"] as? String ?? json["msg"] as? String ?? json["error_description"] as? String
                if let m = msg { throw SupabaseError.apiError(m) }
            }
            throw SupabaseError.httpError(http.statusCode)
        }
    }

    // MARK: - Profile / Friend Code

    func fetchOrCreateProfile() async throws -> String {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }

        let existing: [[String: Any]] = try await getRaw(
            path: "/rest/v1/profiles?user_id=eq.\(uid)&select=friend_code"
        )
        if let first = existing.first, let code = first["friend_code"] as? String {
            return code
        }

        let newCode = String((0..<8).map { _ in
            "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()!
        })
        let body: [String: Any] = ["user_id": uid, "friend_code": newCode]
        try await postVoid(path: "/rest/v1/profiles", body: body, prefer: "resolution=ignore-duplicates")
        return newCode
    }

    /// BUG-12 FIX: Restituisce userId nel campo userId, non nel campo name.
    func findProfileByCode(_ code: String) async throws -> (userId: String, friendCode: String)? {
        let results: [[String: Any]] = try await getRaw(
            path: "/rest/v1/profiles?friend_code=eq.\(code.uppercased())&select=user_id"
        )
        guard let first = results.first, let uid = first["user_id"] as? String else {
            return nil
        }
        return (userId: uid, friendCode: code.uppercased())
    }

    private func getRaw(path: String) async throws -> [[String: Any]] {
        let req = try makeRequest(path: path)
        return try await performRequest(req: req) { data in
            (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        }
    }
}
