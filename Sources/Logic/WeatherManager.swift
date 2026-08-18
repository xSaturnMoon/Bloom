import Foundation
import CoreLocation
import Combine

// MARK: - Weather Data Models

struct WeatherData: Identifiable, Codable {
    var id = UUID()
    var city: String
    var adminRegion: String?
    var country: String?
    var isCurrentLocation: Bool
    var current: CurrentWeather
    var hourly: [HourlyWeather]
    var daily: [DailyWeather]
    var lastUpdated: Date
}

struct CurrentWeather: Codable {
    var temp: Double
    var description: String
    var condition: String
    var humidity: Int
    var windSpeed: Double
    var windDirection: Int // gradi 0-360
    var uvIndex: Double
    var visibility: Double // in km
    var pressure: Double // in hPa
    var feelsLike: Double
    var rainSum: Double // in mm
    var tempMaxToday: Double
    var tempMinToday: Double
    var isDay: Bool
    var sunrise: Date?
    var sunset: Date?

    var windCompassDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(windDirection) + 22.5) / 45.0) % 8
        return directions[index]
    }

    var uvDescription: String {
        switch uvIndex {
        case 0..<3: return "Basso"
        case 3..<6: return "Moderato"
        case 6..<8: return "Alto"
        case 8..<11: return "Molto Alto"
        default: return "Estremo"
        }
    }

    var humidityDescription: String {
        switch humidity {
        case ..<30: return "Secca"
        case 30...60: return "Ideale"
        case 61...80: return "Umidità elevata"
        default: return "Molto umida"
        }
    }
}

struct HourlyWeather: Identifiable, Codable {
    var id = UUID()
    var time: Date
    var temp: Double
    var condition: String
    var description: String
    var rainProbability: Int
    var isDay: Bool
}

struct DailyWeather: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var tempMin: Double
    var tempMax: Double
    var condition: String
    var description: String
    var rainProbability: Int
    var uvIndexMax: Double
    var windSpeedMax: Double
    var sunrise: Date?
    var sunset: Date?
}

struct WeatherLocation: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    let lat: Double
    let lon: Double
    var isCurrentLocation: Bool = false
    var adminRegion: String? = nil
    var country: String? = nil
}

struct CitySearchResult: Identifiable, Codable {
    var id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let country_code: String?
    let admin1: String?
    let timezone: String?

    var subtitle: String {
        let parts = [admin1, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Weather Manager

@MainActor
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    @Published var locations: [WeatherLocation] = []
    @Published var weatherData: [UUID: WeatherData] = [:]
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var searchResults: [CitySearchResult] = []
    @Published var isSearching = false
    @Published var error: String?

    private let locationManager = CLLocationManager()
    private let locationsKey = "bloom_weather_locations_v2"
    private let cacheKey = "bloom_weather_cache_v2"
    private var searchTask: Task<Void, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        loadSavedData()
    }

    // MARK: - Persistence & Cache

    private func loadSavedData() {
        // Carica cache meteo per render istantaneo
        if let cacheData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedWeather = try? JSONDecoder().decode([UUID: WeatherData].self, from: cacheData) {
            self.weatherData = cachedWeather
        }

        // Carica città
        if let data = UserDefaults.standard.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([WeatherLocation].self, from: data),
           !decoded.isEmpty {
            self.locations = decoded
            Task { await refreshAll() }
        } else {
            // Se vuoto, aggiungi Roma come fallback e richiedi posizione
            let defaultLoc = WeatherLocation(name: "Roma", lat: 41.8919, lon: 12.5113, isCurrentLocation: false, adminRegion: "Lazio", country: "Italia")
            self.locations = [defaultLoc]
            saveLocations()
            Task {
                await fetchWeather(for: defaultLoc)
                requestLocation()
            }
        }
    }

    func saveLocations() {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: locationsKey)
        }
    }

    private func saveWeatherCache() {
        if let encoded = try? JSONEncoder().encode(weatherData) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    func replaceWithCloudLocations(_ cloudLocs: [WeatherLocation]) {
        guard !cloudLocs.isEmpty else { return }
        locations = cloudLocs
        saveLocations()
        Task { await refreshAll() }
    }

    func clearLocalData() {
        locations = []
        weatherData = [:]
        searchResults = []
        UserDefaults.standard.removeObject(forKey: locationsKey)
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Location Service

    func requestLocation() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let location = locs.first else { return }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let cityName = placemarks?.first?.locality ?? "Mia Posizione"
            let admin = placemarks?.first?.administrativeArea
            let country = placemarks?.first?.country

            Task { @MainActor in
                let currentLoc = WeatherLocation(
                    name: cityName,
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    isCurrentLocation: true,
                    adminRegion: admin,
                    country: country
                )

                // Rimuovi eventuale posizione precedente e metti in cima
                self.locations.removeAll(where: { $0.isCurrentLocation || $0.name == cityName })
                self.locations.insert(currentLoc, at: 0)
                self.saveLocations()
                self.syncToCloud(currentLoc)
                await self.fetchWeather(for: currentLoc)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error.localizedDescription)")
            self.isLoading = false
        }
    }

    // MARK: - Geocoding City Search

    func searchCities(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
            guard !Task.isCancelled else { return }

            guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=it&format=json") else {
                self.isSearching = false
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoGeoResponse.self, from: data)
                if !Task.isCancelled {
                    self.searchResults = response.results ?? []
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }

    func addCityFromSearchResult(_ item: CitySearchResult, completion: ((Bool) -> Void)? = nil) {
        let newLoc = WeatherLocation(
            name: item.name,
            lat: item.latitude,
            lon: item.longitude,
            isCurrentLocation: false,
            adminRegion: item.admin1,
            country: item.country
        )

        if !locations.contains(where: { abs($0.lat - newLoc.lat) < 0.05 && abs($0.lon - newLoc.lon) < 0.05 }) {
            locations.append(newLoc)
            saveLocations()
            syncToCloud(newLoc)
            Task {
                await fetchWeather(for: newLoc)
                completion?(true)
            }
        } else {
            completion?(true)
        }
    }

    func addCity(name: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=it&format=json") else {
                completion?(false)
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoGeoResponse.self, from: data)
                if let first = response.results?.first {
                    addCityFromSearchResult(first, completion: completion)
                } else {
                    // Fallback con CLGeocoder
                    CLGeocoder().geocodeAddressString(name) { placemarks, error in
                        guard let loc = placemarks?.first?.location, error == nil else {
                            Task { @MainActor in completion?(false) }
                            return
                        }
                        let cityName = placemarks?.first?.locality ?? name
                        let newLoc = WeatherLocation(name: cityName, lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                        Task { @MainActor in
                            self.locations.append(newLoc)
                            self.saveLocations()
                            self.syncToCloud(newLoc)
                            await self.fetchWeather(for: newLoc)
                            completion?(true)
                        }
                    }
                }
            } catch {
                completion?(false)
            }
        }
    }

    func removeCity(at indexSet: IndexSet) {
        let toDelete = indexSet.map { locations[$0] }
        locations.remove(atOffsets: indexSet)
        saveLocations()
        for loc in toDelete {
            weatherData.removeValue(forKey: loc.id)
            Task { try? await SupabaseManager.shared.deleteWeatherLocation(id: loc.id) }
        }
        saveWeatherCache()
    }

    func removeCity(id: UUID) {
        if let idx = locations.firstIndex(where: { $0.id == id }) {
            let loc = locations.remove(at: idx)
            weatherData.removeValue(forKey: id)
            saveLocations()
            saveWeatherCache()
            Task { try? await SupabaseManager.shared.deleteWeatherLocation(id: loc.id) }
        }
    }

    private func syncToCloud(_ loc: WeatherLocation) {
        guard SupabaseManager.shared.isAuthenticated else { return }
        Task { try? await SupabaseManager.shared.upsertWeatherLocation(loc) }
    }

    // MARK: - Weather Fetching

    func refreshAll() async {
        isRefreshing = true
        await withTaskGroup(of: Void.self) { group in
            for loc in locations {
                group.addTask {
                    await self.fetchWeather(for: loc)
                }
            }
        }
        isRefreshing = false
        saveWeatherCache()
    }

    func fetchWeather(for location: WeatherLocation) async {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.lat)&longitude=\(location.lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m,uv_index,visibility&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max&timezone=auto&timeformat=iso8601"

        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

            let decoded = try JSONDecoder().decode(OpenMeteoFullResponse.self, from: data)
            let parsed = parseResponse(decoded, location: location)
            self.weatherData[location.id] = parsed
            self.saveWeatherCache()
        } catch {
            print("Failed to fetch weather for \(location.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Response Parsing

    private func parseResponse(_ res: OpenMeteoFullResponse, location: WeatherLocation) -> WeatherData {
        let isDay = res.current.is_day == 1
        let currentCondition = weatherCodeToCondition(res.current.weather_code, isDay: isDay)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        let sunriseDate = res.daily.sunrise.first.flatMap { isoFormatter.date(from: $0) }
        let sunsetDate = res.daily.sunset.first.flatMap { isoFormatter.date(from: $0) }

        let current = CurrentWeather(
            temp: res.current.temperature_2m,
            description: weatherCodeToText(res.current.weather_code),
            condition: currentCondition,
            humidity: res.current.relative_humidity_2m,
            windSpeed: res.current.wind_speed_10m,
            windDirection: res.current.wind_direction_10m ?? 0,
            uvIndex: res.current.uv_index ?? 0,
            visibility: (res.current.visibility ?? 10000.0) / 1000.0,
            pressure: res.current.surface_pressure ?? 1013.25,
            feelsLike: res.current.apparent_temperature,
            rainSum: res.current.precipitation ?? 0.0,
            tempMaxToday: res.daily.temperature_2m_max.first ?? res.current.temperature_2m,
            tempMinToday: res.daily.temperature_2m_min.first ?? res.current.temperature_2m,
            isDay: isDay,
            sunrise: sunriseDate,
            sunset: sunsetDate
        )

        // Hourly parsing (prossime 36 ore)
        var hourly: [HourlyWeather] = []
        let now = Date().addingTimeInterval(-3600)
        for i in 0..<min(res.hourly.time.count, res.hourly.temperature_2m.count) {
            let timeString = res.hourly.time[i]
            guard let time = isoFormatter.date(from: timeString), time >= now else { continue }

            let hourIsDay = res.hourly.is_day?[i] == 1
            let code = res.hourly.weather_code[i]
            let temp = res.hourly.temperature_2m[i]
            let rainProb = res.hourly.precipitation_probability?[i] ?? 0

            hourly.append(HourlyWeather(
                time: time,
                temp: temp,
                condition: weatherCodeToCondition(code, isDay: hourIsDay),
                description: weatherCodeToText(code),
                rainProbability: rainProb,
                isDay: hourIsDay
            ))

            if hourly.count >= 24 { break }
        }

        // Daily parsing (7 giorni)
        var daily: [DailyWeather] = []
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateFormat = "yyyy-MM-dd"

        for i in 0..<res.daily.time.count {
            let dateString = res.daily.time[i]
            guard let date = dayDateFormatter.date(from: dateString) else { continue }

            let code = res.daily.weather_code[i]
            let tMin = res.daily.temperature_2m_min[i]
            let tMax = res.daily.temperature_2m_max[i]
            let rainProb = res.daily.precipitation_probability_max?[i] ?? 0
            let uvMax = res.daily.uv_index_max?[i] ?? 0.0
            let windMax = res.daily.wind_speed_10m_max?[i] ?? 0.0
            let daySunrise = i < res.daily.sunrise.count ? isoFormatter.date(from: res.daily.sunrise[i]) : nil
            let daySunset = i < res.daily.sunset.count ? isoFormatter.date(from: res.daily.sunset[i]) : nil

            daily.append(DailyWeather(
                date: date,
                tempMin: tMin,
                tempMax: tMax,
                condition: weatherCodeToCondition(code, isDay: true),
                description: weatherCodeToText(code),
                rainProbability: rainProb,
                uvIndexMax: uvMax,
                windSpeedMax: windMax,
                sunrise: daySunrise,
                sunset: daySunset
            ))
        }

        return WeatherData(
            city: location.name,
            adminRegion: location.adminRegion,
            country: location.country,
            isCurrentLocation: location.isCurrentLocation,
            current: current,
            hourly: hourly,
            daily: daily,
            lastUpdated: Date()
        )
    }

    private func weatherCodeToText(_ code: Int) -> String {
        switch code {
        case 0: return "Sereno"
        case 1: return "Prevalentemente sereno"
        case 2: return "Parzialmente nuvoloso"
        case 3: return "Coperto"
        case 45, 48: return "Nebbia"
        case 51, 53, 55: return "Pioggerellina"
        case 56, 57: return "Pioggerellina gelata"
        case 61: return "Pioggia debole"
        case 63: return "Pioggia moderata"
        case 65: return "Pioggia forte"
        case 66, 67: return "Pioggia ghiacciata"
        case 71: return "Neve debole"
        case 73: return "Neve moderata"
        case 75: return "Neve forte"
        case 77: return "Granelli di neve"
        case 80, 81, 82: return "Rovesci di pioggia"
        case 85, 86: return "Rovesci di neve"
        case 95: return "Temporale"
        case 96, 99: return "Temporale con grandine"
        default: return "Variabile"
        }
    }

    private func weatherCodeToCondition(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sunny" : "clear_night"
        case 1, 2: return isDay ? "mostly_sunny" : "partly_cloudy_night"
        case 3: return "cloudy"
        case 45, 48: return "fog"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "rainy"
        case 56, 57, 66, 67: return "freezing_rain"
        case 71, 73, 75, 77, 85, 86: return "snowy"
        case 95, 96, 99: return "thunder"
        default: return isDay ? "sunny" : "clear_night"
        }
    }
}

// MARK: - OpenMeteo Response Models

struct OpenMeteoGeoResponse: Codable {
    let results: [CitySearchResult]?
}

struct OpenMeteoFullResponse: Codable {
    let current: CurrentMetrics
    let hourly: HourlyMetrics
    let daily: DailyMetrics
}

struct CurrentMetrics: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let is_day: Int
    let precipitation: Double?
    let rain: Double?
    let weather_code: Int
    let surface_pressure: Double?
    let wind_speed_10m: Double
    let wind_direction_10m: Int?
    let uv_index: Double?
    let visibility: Double?
}

struct HourlyMetrics: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let relative_humidity_2m: [Int]?
    let apparent_temperature: [Double]?
    let precipitation_probability: [Int]?
    let precipitation: [Double]?
    let weather_code: [Int]
    let is_day: [Int]?
}

struct DailyMetrics: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let sunrise: [String]
    let sunset: [String]
    let uv_index_max: [Double]?
    let precipitation_sum: [Double]?
    let precipitation_probability_max: [Int]?
    let wind_speed_10m_max: [Double]?
}
