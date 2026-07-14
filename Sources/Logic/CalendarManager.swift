import Foundation
import Combine
import UserNotifications

struct EventReminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var time: Date
    var notificationId: String
}

struct BloomEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var startTime: Date
    var endTime: Date?
    var hasEndTime: Bool = false
    var isCompleted: Bool = false
    var reminderId: String? // Legacy
    var reminderTime: Date? // Legacy
    var reminderSound: String? = "Predefinito" // Legacy
    var reminders: [EventReminder] = []
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var events: [BloomEvent] = []

    private let eventsKey = "bloom_calendar_events"
    private let sb = SupabaseManager.shared

    init() {
        loadLocalEvents()
        requestNotificationPermission()
    }

    // MARK: - Local Persistence

    func loadLocalEvents() {
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([BloomEvent].self, from: data) {
            self.events = decoded
        }
    }

    private func saveLocalEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }

    func clearLocalData() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        events = []
        UserDefaults.standard.removeObject(forKey: eventsKey)
    }

    func replaceWithCloudData(_ cloudEvents: [BloomEvent]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        var updatedEvents = cloudEvents
        for i in 0..<updatedEvents.count {
            for rIdx in 0..<updatedEvents[i].reminders.count {
                scheduleNotification(for: &updatedEvents[i], reminderIndex: rIdx)
            }
            if updatedEvents[i].reminderTime != nil {
                scheduleNotification(for: &updatedEvents[i])
            }
        }

        events = updatedEvents
        saveLocalEvents()
    }

    // MARK: - CRUD (Local + Cloud)

    func addEvent(title: String, date: Date, startTime: Date, endTime: Date?, hasEndTime: Bool, reminderEnabled: Bool, reminderTime: Date? = nil, reminderSound: String? = "Predefinito") {
        var newEvent = BloomEvent(
            title: title,
            date: date,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            hasEndTime: hasEndTime,
            reminderTime: reminderTime,
            reminderSound: reminderSound
        )
        if reminderEnabled {
            scheduleNotification(for: &newEvent)
        }
        events.append(newEvent)
        saveLocalEvents()
        syncToCloud(newEvent)
    }

    func updateEvent(_ event: BloomEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            let oldEvent = events[index]
            // Rimuovi solo gli ID di notifica validi (non vuoti)
            let idsToRemove = (oldEvent.reminders.map { $0.notificationId } + [oldEvent.reminderId].compactMap { $0 })
                .filter { !$0.isEmpty }

            if !idsToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }

            var updatedEvent = event
            for i in 0..<updatedEvent.reminders.count {
                scheduleNotification(for: &updatedEvent, reminderIndex: i)
            }

            events[index] = updatedEvent
            saveLocalEvents()
            syncToCloud(updatedEvent)
        }
    }

    func deleteEvent(_ event: BloomEvent) {
        // BUG-09 FIX: Controlla se l'evento esiste prima di procedere
        // per evitare doppia eliminazione dal gesto swipe + bottone
        guard events.contains(where: { $0.id == event.id }) else { return }

        let idsToRemove = (event.reminders.map { $0.notificationId } + [event.reminderId].compactMap { $0 })
            .filter { !$0.isEmpty }

        if !idsToRemove.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
        events.removeAll(where: { $0.id == event.id })
        saveLocalEvents()
        Task { try? await sb.deleteEvent(id: event.id) }
    }

    func toggleComplete(_ event: BloomEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isCompleted.toggle()
            saveLocalEvents()
            syncToCloud(events[index])
        }
    }

    // MARK: - Cloud Sync

    private func syncToCloud(_ event: BloomEvent) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertEvent(event) }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for event: inout BloomEvent, reminderIndex: Int? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Promemoria Bloom"
        content.body = "\(event.title) alle \(event.startTime.formatted(.dateTime.hour().minute()))"

        // BUG-06 FIX: Usa il suono scelto dall'utente nelle impostazioni
        let soundName = UserDefaults.standard.string(forKey: "notificationSound") ?? "Predefinito"
        switch soundName {
        case "Nessuno":
            content.sound = nil
        case "Predefinito":
            content.sound = .default
        default:
            // Usa il nome del suono come file system name se disponibile, altrimenti default
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(soundName).caf"))
        }

        let cal = Calendar.current
        var targetTime = event.startTime

        if let idx = reminderIndex, idx < event.reminders.count {
            targetTime = event.reminders[idx].time
        } else if let rt = event.reminderTime {
            targetTime = rt
        }

        var components = cal.dateComponents([.year, .month, .day], from: event.date)
        let time = cal.dateComponents([.hour, .minute], from: targetTime)
        components.hour = time.hour
        components.minute = time.minute

        if let scheduledDate = cal.date(from: components), scheduledDate < Date() {
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // BUG-11 FIX: L'ID viene assegnato subito prima di aggiungere la request
        let id = UUID().uuidString

        if let idx = reminderIndex, idx < event.reminders.count {
            event.reminders[idx].notificationId = id
        } else {
            event.reminderId = id
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Query

    func events(for date: Date) -> [BloomEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    func hasEvents(on date: Date) -> Bool {
        events.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
