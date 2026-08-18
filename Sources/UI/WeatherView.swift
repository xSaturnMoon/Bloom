import SwiftUI

// MARK: - Weather Main View (Bloom Clean Elegance)

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var selectedLocationId: UUID?
    @State private var showingAddCitySheet = false
    @State private var showingManageCitiesSheet = false

    private var currentLocation: WeatherLocation? {
        if let id = selectedLocationId, let loc = manager.locations.first(where: { $0.id == id }) {
            return loc
        }
        return manager.locations.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if manager.locations.isEmpty {
                    EmptyWeatherBloomView {
                        showingAddCitySheet = true
                    }
                } else if let loc = currentLocation {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // City Selector Horizontal Bar
                            CityPillSelector(
                                locations: manager.locations,
                                selectedId: selectedLocationId ?? loc.id,
                                onSelect: { id in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedLocationId = id
                                    }
                                },
                                onAdd: {
                                    showingAddCitySheet = true
                                }
                            )
                            .padding(.top, 8)

                            if let weather = manager.weatherData[loc.id] {
                                // Hero Header
                                WeatherHeroCard(weather: weather)

                                // Previsioni Orarie
                                HourlyForecastBloomCard(weather: weather)

                                // Previsioni 7 Giorni
                                DailyForecastBloomCard(weather: weather)

                                // Dettagli Utili
                                WeatherDetailsBloomGrid(weather: weather)
                            } else {
                                LoadingWeatherBloomCard(cityName: loc.name)
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable {
                        await manager.refreshAll()
                    }
                }
            }
            .navigationTitle("Meteo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingManageCitiesSheet = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCitySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddCitySheet) {
                AddCitySearchSheet(
                    isPresented: $showingAddCitySheet,
                    onCityAdded: { newId in
                        selectedLocationId = newId
                    }
                )
            }
            .sheet(isPresented: $showingManageCitiesSheet) {
                ManageCitiesSheet(
                    isPresented: $showingManageCitiesSheet,
                    selectedLocationId: $selectedLocationId
                )
            }
            .onAppear {
                if selectedLocationId == nil {
                    selectedLocationId = manager.locations.first?.id
                }
            }
        }
    }
}

// MARK: - City Pill Selector Bar

struct CityPillSelector: View {
    let locations: [WeatherLocation]
    let selectedId: UUID
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(locations) { loc in
                    let isSelected = loc.id == selectedId

                    Button {
                        onSelect(loc.id)
                    } label: {
                        HStack(spacing: 5) {
                            if loc.isCurrentLocation {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                            }
                            Text(loc.name)
                                .font(.subheadline.weight(isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Hero Weather Card

struct WeatherHeroCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: 12) {
            // City Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(weather.city)
                            .font(.title2.bold())
                            .foregroundColor(.primary)

                        if weather.isCurrentLocation {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    if let region = weather.adminRegion, !region.isEmpty, region != weather.city {
                        Text(region)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Condition Icon
                WeatherIconBloom(condition: weather.current.condition)
                    .font(.system(size: 40))
            }

            // Main Temperature Display
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(round(weather.current.temp)))°")
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.current.description)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Text("Min \(Int(round(weather.current.tempMinToday)))°")
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("Max \(Int(round(weather.current.tempMaxToday)))°")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                Spacer()
            }

            // Info Banner
            HStack {
                Label("Percepita \(Int(round(weather.current.feelsLike)))°", systemImage: "thermometer.medium")
                    .font(.caption.bold())
                    .foregroundColor(.blue)

                Spacer()

                if weather.current.rainSum > 0 {
                    Label("\(String(format: "%.1f", weather.current.rainSum)) mm pioggia", systemImage: "drop.fill")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                } else {
                    Text("Aggiornato alle \(weather.lastUpdated.formatted(.dateTime.hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Previsioni Orarie

struct HourlyForecastBloomCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PREVISIONI NELLE 24 ORE", systemImage: "clock.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(weather.hourly.prefix(24).enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 8) {
                            Text(index == 0 ? "Ora" : hour.time.formatted(.dateTime.hour().minute()))
                                .font(.caption.weight(index == 0 ? .bold : .medium))
                                .foregroundColor(index == 0 ? .blue : .secondary)

                            WeatherIconBloom(condition: hour.condition)
                                .font(.title3)
                                .frame(height: 24)

                            if hour.rainProbability > 0 {
                                Text("\(hour.rainProbability)%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue)
                            } else {
                                Text("-")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            }

                            Text("\(Int(round(hour.temp)))°")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                        .frame(width: 52)
                        .padding(.vertical, 8)
                        .background(index == 0 ? Color.blue.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Previsioni 7 Giorni

struct DailyForecastBloomCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("I PROSSIMI 7 GIORNI", systemImage: "calendar")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ForEach(Array(weather.daily.enumerated()), id: \.element.id) { index, day in
                HStack(spacing: 12) {
                    // Giorno
                    Text(index == 0 ? "Oggi" : (index == 1 ? "Domani" : day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized))
                        .font(.body.weight(index == 0 ? .bold : .medium))
                        .foregroundColor(.primary)
                        .frame(width: 90, alignment: .leading)

                    // Icona
                    WeatherIconBloom(condition: day.condition)
                        .font(.title3)
                        .frame(width: 28)

                    // Descrizione breve
                    Text(day.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Probabilità pioggia se presente
                    if day.rainProbability > 0 {
                        Text("\(day.rainProbability)%")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                            .frame(width: 32)
                    }

                    // Temperature Min - Max
                    HStack(spacing: 6) {
                        Text("\(Int(round(day.tempMin)))°")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("–")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(round(day.tempMax)))°")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                if index < weather.daily.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Dettagli Utili Grid

struct WeatherDetailsBloomGrid: View {
    let weather: WeatherData

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Vento
            BloomWeatherMetricTile(
                title: "VENTO",
                icon: "wind",
                value: "\(Int(round(weather.current.windSpeed))) km/h",
                detail: "Direzione: \(weather.current.windCompassDirection)"
            )

            // Umidità
            BloomWeatherMetricTile(
                title: "UMIDITÀ",
                icon: "humidity.fill",
                value: "\(weather.current.humidity)%",
                detail: weather.current.humidityDescription
            )

            // Indice UV
            BloomWeatherMetricTile(
                title: "INDICE UV",
                icon: "sun.max.fill",
                value: "\(Int(round(weather.current.uvIndex)))",
                detail: "Livello: \(weather.current.uvDescription)"
            )

            // Percepita
            BloomWeatherMetricTile(
                title: "PERCEPITA",
                icon: "thermometer.medium",
                value: "\(Int(round(weather.current.feelsLike)))°",
                detail: "Reale: \(Int(round(weather.current.temp)))°"
            )

            // Alba & Tramonto
            BloomWeatherMetricTile(
                title: "TRAMONTO",
                icon: "sunset.fill",
                value: weather.current.sunset?.formatted(.dateTime.hour().minute()) ?? "--:--",
                detail: "Alba: \(weather.current.sunrise?.formatted(.dateTime.hour().minute()) ?? "--:--")"
            )

            // Pressione
            BloomWeatherMetricTile(
                title: "PRESSIONE",
                icon: "gauge.with.needle.fill",
                value: "\(Int(round(weather.current.pressure))) hPa",
                detail: weather.current.pressure >= 1013 ? "Stabile" : "Bassa pressione"
            )
        }
    }
}

// MARK: - Metric Tile

struct BloomWeatherMetricTile: View {
    let title: String
    let icon: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(height: 95)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Weather Icon

struct WeatherIconBloom: View {
    let condition: String

    var body: some View {
        Image(systemName: iconName)
            .renderingMode(.original)
    }

    private var iconName: String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "clear_night": return "moon.stars.fill"
        case "mostly_sunny": return "cloud.sun.fill"
        case "partly_cloudy_night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "fog": return "cloud.fog.fill"
        case "rainy": return "cloud.rain.fill"
        case "freezing_rain": return "cloud.sleet.fill"
        case "snowy": return "snowflake"
        case "thunder": return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }
}

// MARK: - Add City Search Sheet

struct AddCitySearchSheet: View {
    @Binding var isPresented: Bool
    let onCityAdded: (UUID) -> Void
    @ObservedObject var manager = WeatherManager.shared
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Cerca città (es. Milano, Napoli, Parigi...)", text: $query)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .onChange(of: query) { _, newValue in
                            manager.searchCities(query: newValue)
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            manager.searchCities(query: "")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Results List
                if manager.isSearching {
                    ProgressView("Ricerca in corso...")
                        .padding(.top, 40)
                    Spacer()
                } else if !query.isEmpty && manager.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Nessuna città trovata per \"\(query)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 50)
                    Spacer()
                } else if !manager.searchResults.isEmpty {
                    List(manager.searchResults) { item in
                        Button {
                            manager.addCityFromSearchResult(item) { _ in
                                if let last = manager.locations.last {
                                    onCityAdded(last.id)
                                }
                                isPresented = false
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Digita il nome di una città per aggiungerla al meteo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                    Spacer()
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Aggiungi Città")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        isPresented = false
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Manage Cities Sheet

struct ManageCitiesSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedLocationId: UUID?
    @ObservedObject var manager = WeatherManager.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.locations) { loc in
                    Button {
                        selectedLocationId = loc.id
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(loc.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if loc.isCurrentLocation {
                                        Image(systemName: "location.fill")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }

                                if let w = manager.weatherData[loc.id] {
                                    Text(w.current.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let w = manager.weatherData[loc.id] {
                                Text("\(Int(round(w.current.temp)))°")
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    manager.removeCity(at: indexSet)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Le mie città")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fatto") {
                        isPresented = false
                    }
                    .bold()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Loading & Empty States

struct LoadingWeatherBloomCard: View {
    let cityName: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Caricamento meteo per \(cityName)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct EmptyWeatherBloomView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Nessuna città salvata")
                .font(.title2.bold())

            Text("Aggiungi una città per visualizzare le previsioni meteo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onAdd) {
                Label("Aggiungi Città", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }
}


