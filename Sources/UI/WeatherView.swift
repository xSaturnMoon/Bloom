import SwiftUI

// MARK: - Weather Main View

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var selectedLocationId: UUID?
    @State private var showingLocationsSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if manager.locations.isEmpty {
                    EmptyWeatherView(onAdd: { showingLocationsSheet = true })
                } else {
                    TabView(selection: $selectedLocationId) {
                        ForEach(manager.locations) { location in
                            if let weather = manager.weatherData[location.id] {
                                WeatherDetailPage(weather: weather)
                                    .tag(Optional(location.id))
                            } else {
                                LoadingWeatherPage(locationName: location.name)
                                    .tag(Optional(location.id))
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .ignoresSafeArea(edges: .top)
                }
            }
            .navigationTitle("Meteo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLocationsSheet = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLocationsSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }
            }
            .sheet(isPresented: $showingLocationsSheet) {
                WeatherLocationSheet(
                    isPresented: $showingLocationsSheet,
                    selectedLocationId: $selectedLocationId
                )
            }
            .onAppear {
                if selectedLocationId == nil {
                    selectedLocationId = manager.locations.first?.id
                }
            }
            .onChange(of: manager.locations) { _, newLocs in
                if selectedLocationId == nil || !newLocs.contains(where: { $0.id == selectedLocationId }) {
                    selectedLocationId = newLocs.first?.id
                }
            }
        }
    }
}

// MARK: - Weather Detail Page

struct WeatherDetailPage: View {
    let weather: WeatherData
    @State private var selectedDay: DailyWeather?
    @ObservedObject var manager = WeatherManager.shared

    var body: some View {
        ZStack {
            // Dynamic atmospheric gradient background
            WeatherBackgroundGradient(condition: weather.current.condition, isDay: weather.current.isDay)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero Header
                    WeatherHeroHeader(weather: weather)
                        .padding(.top, 60)
                        .padding(.bottom, 10)

                    // 24-Hour Forecast
                    HourlyForecastCard(weather: weather)

                    // 7-Day Forecast with visual temperature bars
                    WeeklyForecastCard(weather: weather, selectedDay: $selectedDay)

                    // 2x2 Metric Detail Cards
                    WeatherMetricsGrid(weather: weather)

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
            }
            .refreshable {
                await manager.refreshAll()
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(day: day, city: weather.city, hourlyData: weather.hourly)
        }
    }
}

// MARK: - Hero Header

struct WeatherHeroHeader: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: 4) {
            // City Name & Location icon
            HStack(spacing: 6) {
                Text(weather.city)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if weather.isCurrentLocation {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            if let region = weather.adminRegion, !region.isEmpty, region != weather.city {
                Text(region)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }

            // Giant Temperature
            Text("\(Int(round(weather.current.temp)))°")
                .font(.system(size: 92, weight: .thin, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 12)

            // Weather Condition Description
            Text(weather.current.description)
                .font(.title3.weight(.medium))
                .foregroundColor(.white.opacity(0.95))

            // High / Low / Feels Like
            HStack(spacing: 12) {
                Text("Max: \(Int(round(weather.current.tempMaxToday)))°")
                Text("Min: \(Int(round(weather.current.tempMinToday)))°")
                Text("Percepita: \(Int(round(weather.current.feelsLike)))°")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.top, 2)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Hourly Forecast Card

struct HourlyForecastCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PREVISIONI ORARIE", systemImage: "clock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if let firstHour = weather.hourly.first, firstHour.rainProbability > 0 {
                    Text("Probabilità pioggia oggi fino a \(weather.hourly.map(\.rainProbability).max() ?? 0)%")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Array(weather.hourly.prefix(24).enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 10) {
                            Text(index == 0 ? "Adesso" : hour.time.formatted(.dateTime.hour().minute()))
                                .font(.subheadline.weight(index == 0 ? .bold : .medium))
                                .foregroundColor(.white)

                            WeatherIconView(condition: hour.condition)
                                .font(.title2)
                                .frame(height: 28)

                            if hour.rainProbability > 0 {
                                Text("\(hour.rainProbability)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "5ce1e6"))
                            } else {
                                Spacer().frame(height: 14)
                            }

                            Text("\(Int(round(hour.temp)))°")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 58)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Weekly Forecast Card with Apple-Style Temp Range Bars

struct WeeklyForecastCard: View {
    let weather: WeatherData
    @Binding var selectedDay: DailyWeather?

    private var weekMin: Double {
        weather.daily.map(\.tempMin).min() ?? 0
    }
    private var weekMax: Double {
        weather.daily.map(\.tempMax).max() ?? 40
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("PREVISIONI A 7 GIORNI", systemImage: "calendar")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(Array(weather.daily.enumerated()), id: \.element.id) { index, day in
                Button {
                    selectedDay = day
                } label: {
                    HStack(spacing: 10) {
                        // Day Label
                        Text(index == 0 ? "Oggi" : day.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "it_IT"))).capitalized)
                            .font(.headline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(width: 60, alignment: .leading)

                        // Condition Icon
                        WeatherIconView(condition: day.condition)
                            .font(.title3)
                            .frame(width: 32)

                        // Rain probability
                        if day.rainProbability > 0 {
                            Text("\(day.rainProbability)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "5ce1e6"))
                                .frame(width: 34)
                        } else {
                            Spacer().frame(width: 34)
                        }

                        // Temp Min
                        Text("\(Int(round(day.tempMin)))°")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, alignment: .trailing)

                        // Apple-style Temperature Gradient Range Bar
                        TemperatureRangeBar(
                            min: day.tempMin,
                            max: day.tempMax,
                            globalMin: weekMin,
                            globalMax: weekMax
                        )
                        .frame(height: 5)

                        // Temp Max
                        Text("\(Int(round(day.tempMax)))°")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if index < weather.daily.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Temperature Range Bar

struct TemperatureRangeBar: View {
    let min: Double
    let max: Double
    let globalMin: Double
    let globalMax: Double

    var body: some View {
        GeometryReader { geo in
            let totalRange = Swift.max(globalMax - globalMin, 1.0)
            let startOffset = Swift.max((min - globalMin) / totalRange, 0.0)
            let widthRatio = Swift.max((max - min) / totalRange, 0.08)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.black.opacity(0.25))

                // Active range gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4facfe"), Color(hex: "00f2fe"), Color(hex: "ffb199"), Color(hex: "ff0844")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(widthRatio))
                    .offset(x: geo.size.width * CGFloat(startOffset))
            }
        }
    }
}

// MARK: - Metrics Grid

struct WeatherMetricsGrid: View {
    let weather: WeatherData

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            // UV Index
            MetricCard(
                title: "INDICE UV",
                icon: "sun.max.fill",
                mainValue: "\(Int(round(weather.current.uvIndex)))",
                subtitle: weather.current.uvDescription,
                footer: "Proteggiti nelle ore centrali"
            )

            // Feels Like
            MetricCard(
                title: "PERCEPITA",
                icon: "thermometer.medium",
                mainValue: "\(Int(round(weather.current.feelsLike)))°",
                subtitle: abs(weather.current.feelsLike - weather.current.temp) < 2 ? "Simile alla temperatura" : (weather.current.feelsLike < weather.current.temp ? "Più fredda per il vento" : "Più calda per l'umidità"),
                footer: nil
            )

            // Wind
            MetricCard(
                title: "VENTO",
                icon: "wind",
                mainValue: "\(Int(round(weather.current.windSpeed))) km/h",
                subtitle: "\(weather.current.windCompassDirection) • Raffiche possibili",
                footer: nil
            )

            // Humidity
            MetricCard(
                title: "UMIDITÀ",
                icon: "humidity.fill",
                mainValue: "\(weather.current.humidity)%",
                subtitle: weather.current.humidityDescription,
                footer: nil
            )

            // Sunrise & Sunset
            MetricCard(
                title: "ALBA & TRAMONTO",
                icon: "sunset.fill",
                mainValue: weather.current.sunset?.formatted(.dateTime.hour().minute()) ?? "--:--",
                subtitle: "Alba: \(weather.current.sunrise?.formatted(.dateTime.hour().minute()) ?? "--:--")",
                footer: nil
            )

            // Visibility
            MetricCard(
                title: "VISIBILITÀ",
                icon: "eye.fill",
                mainValue: "\(Int(round(weather.current.visibility))) km",
                subtitle: weather.current.visibility >= 10 ? "Perfetta" : "Ridotta",
                footer: nil
            )

            // Pressure
            MetricCard(
                title: "PRESSIONE",
                icon: "gauge.with.needle.fill",
                mainValue: "\(Int(round(weather.current.pressure))) hPa",
                subtitle: weather.current.pressure >= 1013 ? "Alta pressione" : "Bassa pressione",
                footer: nil
            )

            // Precipitation Sum
            MetricCard(
                title: "PRECIPITAZIONI",
                icon: "drop.fill",
                mainValue: "\(String(format: "%.1f", weather.current.rainSum)) mm",
                subtitle: "Nelle ultime 24 ore",
                footer: nil
            )
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let icon: String
    let mainValue: String
    let subtitle: String
    let footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.7))
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(mainValue)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)

            if let footer = footer {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Weather Background Dynamic Gradient

struct WeatherBackgroundGradient: View {
    let condition: String
    let isDay: Bool

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var gradientColors: [Color] {
        if !isDay {
            // Night Gradients
            switch condition {
            case "thunder":
                return [Color(hex: "0d1322"), Color(hex: "1a1c2e"), Color(hex: "2d1b36")]
            case "rainy", "freezing_rain":
                return [Color(hex: "0a1128"), Color(hex: "1c2541"), Color(hex: "27345b")]
            case "snowy":
                return [Color(hex: "1a233a"), Color(hex: "2e3d5b"), Color(hex: "475b7a")]
            case "fog", "cloudy":
                return [Color(hex: "141a29"), Color(hex: "232b3d"), Color(hex: "374256")]
            default:
                // Clear / Starry Night
                return [Color(hex: "080e21"), Color(hex: "141f3d"), Color(hex: "22335c")]
            }
        } else {
            // Day Gradients
            switch condition {
            case "sunny":
                return [Color(hex: "2193b0"), Color(hex: "6dd5ed"), Color(hex: "bfe9ff")]
            case "mostly_sunny":
                return [Color(hex: "3a7bd5"), Color(hex: "3a6073"), Color(hex: "90b8f8")]
            case "cloudy":
                return [Color(hex: "536976"), Color(hex: "708898"), Color(hex: "9fb1be")]
            case "fog":
                return [Color(hex: "606c74"), Color(hex: "7e8c95"), Color(hex: "a6b4bd")]
            case "rainy", "freezing_rain":
                return [Color(hex: "373b44"), Color(hex: "4286f4"), Color(hex: "6397e5")]
            case "thunder":
                return [Color(hex: "1f1c2c"), Color(hex: "3e3954"), Color(hex: "625b84")]
            case "snowy":
                return [Color(hex: "708090"), Color(hex: "8fa1b3"), Color(hex: "c2d3e4")]
            default:
                return [Color(hex: "2980b9"), Color(hex: "6dd5fa"), Color(hex: "ffffff")]
            }
        }
    }
}

// MARK: - Weather Icon Component

struct WeatherIconView: View {
    let condition: String

    var body: some View {
        Image(systemName: iconName)
            .renderingMode(.original)
            .symbolRenderingMode(.multicolor)
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

// MARK: - City Management Sheet & Search with Autocomplete

struct WeatherLocationSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedLocationId: UUID?
    @ObservedObject var manager = WeatherManager.shared
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Cerca una città nel mondo...", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onChange(of: searchText) { _, newValue in
                                manager.searchCities(query: newValue)
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
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
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    // Results or Saved Cities
                    if !searchText.isEmpty {
                        if manager.isSearching {
                            ProgressView()
                                .padding(.top, 40)
                            Spacer()
                        } else if manager.searchResults.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("Nessun risultato per \"\(searchText)\"")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                            Spacer()
                        } else {
                            List(manager.searchResults) { result in
                                Button {
                                    manager.addCityFromSearchResult(result) { _ in
                                        if let last = manager.locations.last {
                                            selectedLocationId = last.id
                                        }
                                        isPresented = false
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        // Saved Cities List
                        List {
                            Section {
                                ForEach(manager.locations) { loc in
                                    SavedCityRow(
                                        location: loc,
                                        weather: manager.weatherData[loc.id],
                                        isSelected: selectedLocationId == loc.id
                                    ) {
                                        selectedLocationId = loc.id
                                        isPresented = false
                                    }
                                }
                                .onDelete { indexSet in
                                    manager.removeCity(at: indexSet)
                                }
                            } header: {
                                Text("Le tue città")
                                    .font(.caption.bold())
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Città")
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

// MARK: - Saved City Row

struct SavedCityRow: View {
    let location: WeatherLocation
    let weather: WeatherData?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(location.name)
                            .font(.title3.bold())
                            .foregroundColor(.primary)

                        if location.isCurrentLocation {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    if let w = weather {
                        Text(w.current.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Aggiornamento...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let w = weather {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(round(w.current.temp)))°")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)

                        Text("H: \(Int(round(w.current.tempMaxToday)))° L: \(Int(round(w.current.tempMinToday)))°")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ProgressView()
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Detail Sheet

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
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Summary card
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(day.description)
                                        .font(.title2.bold())
                                }
                                Spacer()
                                WeatherIconView(condition: day.condition)
                                    .font(.system(size: 44))
                            }

                            Divider()

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Massima").font(.caption).foregroundColor(.secondary)
                                    Text("\(Int(round(day.tempMax)))°").font(.title3.bold())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Minima").font(.caption).foregroundColor(.secondary)
                                    Text("\(Int(round(day.tempMin)))°").font(.title3.bold())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pioggia").font(.caption).foregroundColor(.secondary)
                                    Text("\(day.rainProbability)%").font(.title3.bold()).foregroundColor(.blue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Indice UV").font(.caption).foregroundColor(.secondary)
                                    Text("\(Int(round(day.uvIndexMax)))").font(.title3.bold())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Hourly list
                        if !hoursForDay.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ORARIO DELLA GIORNATA")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 0) {
                                    ForEach(hoursForDay) { hour in
                                        HStack {
                                            Text(hour.time.formatted(.dateTime.hour().minute()))
                                                .font(.subheadline.bold())
                                                .frame(width: 60, alignment: .leading)

                                            WeatherIconView(condition: hour.condition)
                                                .font(.title3)
                                                .frame(width: 30)

                                            if hour.rainProbability > 0 {
                                                Text("\(hour.rainProbability)%")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.blue)
                                                    .frame(width: 40)
                                            } else {
                                                Spacer().frame(width: 40)
                                            }

                                            Text(hour.description)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)

                                            Spacer()

                                            Text("\(Int(round(hour.temp)))°")
                                                .font(.headline)
                                                .frame(width: 40, alignment: .trailing)
                                        }
                                        .padding(.vertical, 10)
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

// MARK: - Loading & Empty States

struct LoadingWeatherPage: View {
    let locationName: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2980b9"), Color(hex: "6dd5fa")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Caricamento meteo per \(locationName)...")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
        }
    }
}

struct EmptyWeatherView: View {
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2980b9"), Color(hex: "6dd5fa")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Nessuna città salvata")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Cerca una città per vedere le previsioni meteo in tempo reale.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onAdd) {
                    Label("Aggiungi Città", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white)
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

