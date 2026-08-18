import SwiftUI

// MARK: - Weather Main View (Bloom Clean Elegance)

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var selectedLocationId: UUID?
    @State private var showingAddCitySheet = false
    @State private var showingManageCitiesSheet = false
    @State private var selectedDay: DailyWeather?

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
                        VStack(spacing: 20) {
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
                                // Hero Header (Spazioso e pulito)
                                WeatherHeroCard(weather: weather)

                                // Previsioni Nelle 24 Ore
                                HourlyForecastBloomCard(weather: weather)

                                // Previsioni 7 Giorni (Interattive, cliccabili)
                                DailyForecastBloomCard(weather: weather, selectedDay: $selectedDay)

                                // Dettagli Utili (6 riquadri puliti)
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
                    .sheet(item: $selectedDay) { day in
                        if let weather = manager.weatherData[loc.id] {
                            DayDetailSheet(day: day, city: weather.city, hourlyData: weather.hourly)
                        }
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

// MARK: - Hero Weather Card (Pulita, Spaziosa e Chiara)

struct WeatherHeroCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: 16) {
            // City Header & Location
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(weather.city)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if weather.isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                if let region = weather.adminRegion, !region.isEmpty, region != weather.city {
                    Text(region)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Big Temperature & Main Icon
            HStack(spacing: 16) {
                WeatherIconBloom(condition: weather.current.condition)
                    .font(.system(size: 56))

                Text("\(Int(round(weather.current.temp)))°")
                    .font(.system(size: 72, weight: .light, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Condition & Temp Range Pill
            VStack(spacing: 6) {
                Text(weather.current.description)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 10) {
                    Text("Max: \(Int(round(weather.current.tempMaxToday)))°")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("Min: \(Int(round(weather.current.tempMinToday)))°")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("Percepita: \(Int(round(weather.current.feelsLike)))°")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Previsioni Nelle 24 Ore

struct HourlyForecastBloomCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PREVISIONI NELLE 24 ORE", systemImage: "clock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if let maxRain = weather.hourly.prefix(24).map(\.rainProbability).max(), maxRain > 0 {
                    Text("Pioggia fino a \(maxRain)%")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 4)

            if weather.hourly.isEmpty {
                Text("Previsioni orarie in fase di caricamento...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
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
                                    Spacer().frame(height: 12)
                                }

                                Text("\(Int(round(hour.temp)))°")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 54)
                            .padding(.vertical, 8)
                            .background(index == 0 ? Color.blue.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 4)
                }
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

// MARK: - Previsioni 7 Giorni (Interattive e Cliccabili)

struct DailyForecastBloomCard: View {
    let weather: WeatherData
    @Binding var selectedDay: DailyWeather?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("PREVISIONI A 7 GIORNI", systemImage: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Tocca per i dettagli")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ForEach(Array(weather.daily.enumerated()), id: \.element.id) { index, day in
                Button {
                    selectedDay = day
                } label: {
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
                        } else {
                            Spacer().frame(width: 32)
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
                        .frame(width: 65, alignment: .trailing)

                        // Chevron to indicate tap
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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

// MARK: - Day Detail Sheet (Meteo Completo del Giorno Selezionato)

struct DayDetailSheet: View {
    let day: DailyWeather
    let city: String
    let hourlyData: [HourlyWeather]
    @Environment(\.dismiss) var dismiss

    var hoursForDay: [HourlyWeather] {
        hourlyData.filter { Calendar.current.isDate($0.time, inSameDayAs: day.date) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Summary Hero Card
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.blue)
                                    Text(day.description)
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                WeatherIconBloom(condition: day.condition)
                                    .font(.system(size: 44))
                            }

                            Divider()

                            HStack(spacing: 16) {
                                DayStatBox(title: "MASSIMA", value: "\(Int(round(day.tempMax)))°", color: .primary)
                                DayStatBox(title: "MINIMA", value: "\(Int(round(day.tempMin)))°", color: .secondary)
                                DayStatBox(title: "PIOGGIA", value: "\(day.rainProbability)%", color: .blue)
                                DayStatBox(title: "INDICE UV", value: "\(Int(round(day.uvIndexMax)))", color: .orange)
                            }

                            if let sunrise = day.sunrise, let sunset = day.sunset {
                                Divider()

                                HStack {
                                    Label("Alba: \(sunrise.formatted(.dateTime.hour().minute()))", systemImage: "sunrise.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Label("Tramonto: \(sunset.formatted(.dateTime.hour().minute()))", systemImage: "sunset.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Meteo Orario della Giornata
                        if !hoursForDay.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("METEO ORARIO DELLA GIORNATA", systemImage: "clock.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 0) {
                                    ForEach(hoursForDay) { hour in
                                        HStack {
                                            Text(hour.time.formatted(.dateTime.hour().minute()))
                                                .font(.subheadline.bold())
                                                .frame(width: 55, alignment: .leading)

                                            WeatherIconBloom(condition: hour.condition)
                                                .font(.title3)
                                                .frame(width: 28)

                                            if hour.rainProbability > 0 {
                                                Text("\(hour.rainProbability)%")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.blue)
                                                    .frame(width: 36)
                                            } else {
                                                Spacer().frame(width: 36)
                                            }

                                            Text(hour.description)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            Spacer()

                                            Text("\(Int(round(hour.temp)))°")
                                                .font(.headline.weight(.semibold))
                                                .frame(width: 40, alignment: .trailing)
                                        }
                                        .padding(.vertical, 11)
                                        .padding(.horizontal, 16)

                                        if hour.id != hoursForDay.last?.id {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .bold()
                }
            }
        }
    }
}

struct DayStatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dettagli Utili Grid (6 Card Pulite)

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



