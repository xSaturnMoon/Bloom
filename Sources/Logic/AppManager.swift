import Foundation
import SwiftUI

// MARK: - BloomTabType

enum BloomTabType: String, CaseIterable, Identifiable, Codable {
    case calendar = "calendar"
    case shopping = "shopping"
    case weather = "weather"
    case settings = "settings"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendario"
        case .shopping: return "Spesa"
        case .weather: return "Meteo"
        case .settings: return "Impostazioni"
        }
    }

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .shopping: return "cart"
        case .weather: return "cloud.sun"
        case .settings: return "gear"
        }
    }

    // Le impostazioni rimangono sempre visibili per non bloccare l'utente fuori dal menu
    var canBeHidden: Bool {
        self != .settings
    }
}

// MARK: - TabItemConfig

struct TabItemConfig: Identifiable, Codable, Equatable {
    var type: BloomTabType
    var isVisible: Bool

    var id: String { type.rawValue }
}

// MARK: - AppManager

class AppManager: ObservableObject {
    static let shared = AppManager()

    @Published var selectedTab: BloomTabType = .calendar
    @Published var tabConfigs: [TabItemConfig] = []

    private let tabConfigsKey = "bloom_tab_configs_v1"

    var visibleTabs: [TabItemConfig] {
        let visible = tabConfigs.filter { $0.isVisible }
        // Garantisce che ci sia sempre almeno un tab visibile
        return visible.isEmpty ? [TabItemConfig(type: .settings, isVisible: true)] : visible
    }

    private init() {
        loadTabConfigs()
    }

    func loadTabConfigs() {
        if let data = UserDefaults.standard.data(forKey: tabConfigsKey),
           let decoded = try? JSONDecoder().decode([TabItemConfig].self, from: data) {
            var current = decoded
            // Aggiungi eventuali nuovi tab che potrebbero non essere presenti nel salvataggio
            for tab in BloomTabType.allCases {
                if !current.contains(where: { $0.type == tab }) {
                    current.append(TabItemConfig(type: tab, isVisible: true))
                }
            }
            // Forza le impostazioni sempre su visibile
            if let idx = current.firstIndex(where: { $0.type == .settings }) {
                current[idx].isVisible = true
            }
            self.tabConfigs = current
        } else {
            // Configurazione predefinita iniziale
            self.tabConfigs = BloomTabType.allCases.map { TabItemConfig(type: $0, isVisible: true) }
            saveTabConfigs()
        }

        // Assicurati che il tab selezionato sia effettivamente tra quelli visibili
        if !visibleTabs.contains(where: { $0.type == selectedTab }) {
            selectedTab = visibleTabs.first?.type ?? .calendar
        }
    }

    func saveTabConfigs() {
        if let encoded = try? JSONEncoder().encode(tabConfigs) {
            UserDefaults.standard.set(encoded, forKey: tabConfigsKey)
        }
    }

    func toggleVisibility(for tabType: BloomTabType) {
        guard tabType.canBeHidden else { return }
        if let index = tabConfigs.firstIndex(where: { $0.type == tabType }) {
            // Impedisci di nascondere tutte le categorie principali
            let activeMainCount = tabConfigs.filter { $0.isVisible && $0.type != .settings }.count
            if tabConfigs[index].isVisible && activeMainCount <= 1 {
                return
            }

            tabConfigs[index].isVisible.toggle()
            saveTabConfigs()

            // Se il tab attualmente aperto è stato appena nascosto, passa al primo tab visibile
            if !tabConfigs[index].isVisible && selectedTab == tabType {
                selectedTab = visibleTabs.first?.type ?? .settings
            }
        }
    }

    func moveTabs(from source: IndexSet, to destination: Int) {
        tabConfigs.move(fromOffsets: source, toOffset: destination)
        saveTabConfigs()
    }

    func resetToDefault() {
        self.tabConfigs = BloomTabType.allCases.map { TabItemConfig(type: $0, isVisible: true) }
        saveTabConfigs()
        selectedTab = .calendar
    }
}

