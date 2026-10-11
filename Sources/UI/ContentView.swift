import SwiftUI

struct ContentView: View {
    @StateObject var appManager = AppManager.shared
    @State private var showingAuth = false
    @State private var hasCheckedAuth = false

    var body: some View {
        ZStack {
            TabView(selection: $appManager.selectedTab) {
                ForEach(appManager.visibleTabs) { config in
                    switch config.type {
                    case .calendar:
                        CalendarView()
                            .tabItem { Label(config.type.title, systemImage: config.type.icon) }
                            .tag(BloomTabType.calendar)

                    case .shopping:
                        ShoppingView()
                            .tabItem { Label(config.type.title, systemImage: config.type.icon) }
                            .tag(BloomTabType.shopping)

                    case .weather:
                        WeatherView()
                            .tabItem { Label(config.type.title, systemImage: config.type.icon) }
                            .tag(BloomTabType.weather)

                    case .settings:
                        SettingsView()
                            .tabItem { Label(config.type.title, systemImage: config.type.icon) }
                            .tag(BloomTabType.settings)
                    }
                }
            }
            .tint(.blue)
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthView(isPresented: $showingAuth, isOptional: false)
                .interactiveDismissDisabled() // Prevent swipe to dismiss
        }
        .onAppear {
            if !hasCheckedAuth {
                hasCheckedAuth = true
                if AuthManager.shared.currentUser == nil {
                    showingAuth = true
                }
            }
        }
        .onChange(of: AuthManager.shared.currentUser?.id) { _, newId in
            if newId == nil {
                showingAuth = true
            } else {
                showingAuth = false
            }
        }
    }
}
