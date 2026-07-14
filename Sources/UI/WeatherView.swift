import SwiftUI

// BUG-18 FIX: AddCityView mostra errore se la città non viene trovata
// e chiude il foglio solo su successo.
struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var showingAddCity = false
    @State private var showingLocationList = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                if manager.locations.isEmpty {
                    ContentUnavailableView {
                        Label("Nessun Meteo", systemImage: "cloud.sun")
                    } description: {
                        Text("Aggiungi una città per iniziare.")
                    } actions: {
                        Button("Aggiungi Città") { showingAddCity = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TabView {
                        ForEach(manager.locations) { location in
                            if let weather = manager.weatherData[location.id] {
                                WeatherDetailPage(weather: weather)
                            } else {
                                ProgressView()
                                    .controlSize(.large)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle("Meteo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddCity = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingLocationList = true } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showingAddCity) {
                AddCityView(isPresented: $showingAddCity)
            }
            .sheet(isPresented: $showingLocationList) {
                LocationListView(isPresented: $showingLocationList)
            }
        }
    }
}

struct WeatherDetailPage: View {
    let weather: WeatherData
    @State private var selectedDay: DailyWeather?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                VStack(spacing: 4) {
                    Text(weather.city)
                        .font(.system(size: 34, weight: .medium, design: .default))
                    Text("\(Int(weather.current.temp))°")
                        .font(.system(size: 96, weight: .thin, design: .default))
                        .padding(.leading, 15)
                    Text(weather.current.description)
                        .font(.title3.weight(.medium))
                    HStack(spacing: 15) {
                        Text("Max: \(Int(weather.daily.first?.tempMax ?? 0))°")
                        Text("Min: \(Int(weather.daily.first?.tempMin ?? 0))°")
                    }
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                HourlyForecastCard(weather: weather)
                DailyForecastCard(weather: weather, selectedDay: $selectedDay)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    WeatherDetailCard(title: "UV INDEX", value: "\(Int(weather.current.uvIndex))", icon: "sun.max.fill")
                    WeatherDetailCard(title: "UMIDITÀ", value: "\(weather.current.humidity)%", icon: "humidity.fill")
                    WeatherDetailCard(title: "VENTO", value: "\(Int(weather.current.windSpeed)) km/h", icon: "wind")
                    WeatherDetailCard(title: "PRESSIONE", value: "\(Int(weather.current.pressure)) hPa", icon: "gauge.with.needle")
                }
                .padding(.horizontal)

                Spacer(minLength: 80)
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, city: weather.city, hourlyData: weather.hourly)
        }
    }
}

struct HourlyForecastCard: View {
    let weather: WeatherData

    var upcomingHours: [HourlyWeather] {
        let now = Date()
        return Array(weather.hourly.filter { $0.time >= now }.prefix(24))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("PREVISIONI ORARIE", systemImage: "clock")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 25) {
                    ForEach(upcomingHours) { hour in
                        VStack(spacing: 12) {
                            Text(hour.time.formatted(.dateTime.hour().locale(Locale(identifier: "it_IT"))))
                                .font(.subheadline.weight(.semibold))
                            WeatherIcon(condition: hour.condition)
                                .font(.title2)
                            if hour.rainProbability > 0 {
                                Text("\(hour.rainProbability)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                            } else {
                                Spacer().frame(height: 13)
                            }
                            Text("\(Int(hour.temp))°")
                                .font(.title3.weight(.medium))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.secondary.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal)
    }
}

struct DailyForecastCard: View {
    let weather: WeatherData
    @Binding var selectedDay: DailyWeather?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("PROSSIMI 7 GIORNI", systemImage: "calendar")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 15)
                .padding(.horizontal)
                .padding(.top, 16)

            ForEach(weather.daily) { day in
                Button { selectedDay = day } label: {
                    HStack {
                        Text(day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                            .font(.headline.weight(.medium))
                            .frame(width: 110, alignment: .leading)
                        WeatherIcon(condition: day.condition).font(.title3)
                        if day.rainProbability > 0 {
                            Text("\(day.rainProbability)%")
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                                .frame(width: 35)
                        } else {
                            Spacer().frame(width: 35)
                        }
                        Spacer()
                        Text("\(Int(day.tempMin))°")
                            .foregroundStyle(.secondary)
                            .font(.headline.weight(.medium))
                            .frame(width: 35)
                        Text("\(Int(day.tempMax))°")
                            .font(.headline.weight(.medium))
                            .frame(width: 35)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                if day.id != weather.daily.last?.id {
                    Divider().padding(.leading, 15)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.secondary.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal)
    }
}

struct DayDetailView: View {
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
                Color(uiColor: .systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Condizione")
                                Spacer()
                                Text(day.description).foregroundStyle(.secondary)
                                WeatherIcon(condition: day.condition).padding(.leading, 4)
                            }.padding()
                            Divider().padding(.leading)
                            HStack { Text("Temperatura Max"); Spacer(); Text("\(Int(day.tempMax))°").bold() }.padding()
                            Divider().padding(.leading)
                            HStack { Text("Temperatura Min"); Spacer(); Text("\(Int(day.tempMin))°").bold() }.padding()
                            Divider().padding(.leading)
                            HStack { Text("Probabilità Pioggia"); Spacer(); Text("\(day.rainProbability)%").bold().foregroundColor(.blue) }.padding()
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.secondary.opacity(0.1), lineWidth: 0.5))
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 0) {
                            Label("METEO ORARIO", systemImage: "clock")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 15).padding(.horizontal).padding(.top, 16)

                            if hoursForDay.isEmpty {
                                Text("Dati orari non disponibili.").foregroundStyle(.secondary).padding()
                            } else {
                                ForEach(hoursForDay) { hour in
                                    HStack {
                                        Text(hour.time.formatted(.dateTime.hour().locale(Locale(identifier: "it_IT"))))
                                            .font(.headline.weight(.medium)).frame(width: 60, alignment: .leading)
                                        WeatherIcon(condition: hour.condition).font(.title3).frame(width: 30)
                                        if hour.rainProbability > 0 {
                                            Text("\(hour.rainProbability)%").font(.caption.bold()).foregroundColor(.blue).frame(width: 45)
                                        } else {
                                            Spacer().frame(width: 45)
                                        }
                                        Spacer()
                                        Text(hour.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                        Spacer()
                                        Text("\(Int(hour.temp))°").font(.headline.weight(.medium)).frame(width: 40, alignment: .trailing)
                                    }
                                    .padding(.vertical, 12).padding(.horizontal)
                                    if hour.id != hoursForDay.last?.id { Divider().padding(.leading, 15) }
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.secondary.opacity(0.1), lineWidth: 0.5))
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Text("Chiudi").bold() }
                }
            }
        }
    }
}

struct LocationListView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = WeatherManager.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.locations) { loc in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(loc.name).font(.headline)
                            if let w = manager.weatherData[loc.id] {
                                Text(w.current.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let w = manager.weatherData[loc.id] {
                            Text("\(Int(w.current.temp))°").font(.title2.bold())
                        }
                    }
                }
                .onDelete(perform: manager.removeCity)
            }
            .navigationTitle("Le mie città")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Chiudi") { isPresented = false } }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
        }
    }
}

// BUG-18 FIX: Il foglio si chiude solo dopo geocodifica riuscita.
// Se la città non viene trovata, mostra un messaggio di errore.
struct AddCityView: View {
    @Binding var isPresented: Bool
    @State private var cityName = ""
    @State private var isLoading = false
    @State private var showError = false
    @ObservedObject var manager = WeatherManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Cerca città...", text: $cityName)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                if showError {
                    Text("Città non trovata. Verifica il nome e riprova.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                Button {
                    isLoading = true
                    showError = false
                    // BUG-18 FIX: Usa il completion handler per chiudere solo su successo
                    manager.addCity(name: cityName) { success in
                        isLoading = false
                        if success {
                            isPresented = false
                        } else {
                            withAnimation { showError = true }
                        }
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Aggiungi")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(cityName.isEmpty || isLoading)

                Spacer()
            }
            .navigationTitle("Nuova Città")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annulla") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WeatherIcon: View {
    let condition: String
    var body: some View { Image(systemName: iconName).renderingMode(.original) }
    var iconName: String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "clear_night": return "moon.stars.fill"
        case "cloudy": return "cloud.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "thunder": return "cloud.bolt.fill"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }
}

struct WeatherDetailCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            Text(value).font(.title2.weight(.medium))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 90)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.secondary.opacity(0.1), lineWidth: 0.5))
    }
}
