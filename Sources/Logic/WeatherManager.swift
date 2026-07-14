import Foundation
import CoreLocation
import Combine

struct WeatherData: Identifiable, Codable {
    var id = UUID()
    var city: String
    var current: CurrentWeather
    var hourly: [HourlyWeather]
    var daily: [DailyWeather]
}

struct CurrentWeather: Codable {
    var temp: Double
    var description: String
    var condition: String
    var humidity: Int
    var windSpeed: Double
    var uvIndex: Double
    var visibility: Double
    var pressure: Double
    var feelsLike: Double
}

struct HourlyWeather: Identifiable, Codable {
    var id = UUID()
    var time: Date
    var temp: Double
    var condition: String
    var description: String
    var rainProbability: Int
}

struct DailyWeather: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var tempMin: Double
    var tempMax: Double
    var condition: String
    var description: String
    var rainProbability: Int
}

struct WeatherLocation: Identifiable, Codable {
    var id = UUID()
    var name: String
    let lat: Double
    let lon: Double
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    @Published var locations: [WeatherLocation] = []
    @Published var weatherData: [UUID: WeatherData] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    private let locationsKey = "bloom_weather_locations"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        loadLocations()
    }

    func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([WeatherLocation].self, from: data) {
            self.locations = decoded
            refreshAll()
        } else {
            requestLocation()
        }
    }

    func saveLocations() {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: locationsKey)
        }
    }

    func replaceWithCloudLocations(_ cloudLocs: [WeatherLocation]) {
        locations = cloudLocs
        saveLocations()
        refreshAll()
    }

    // BUG-16 FIX: clearLocalData() ora cancella anche i Combine publishers attivi
    // per evitare che fetch in corso scrivano in weatherData dopo il logout.
    func clearLocalData() {
        cancellables.removeAll()
        locations = []
        weatherData = [:]
        UserDefaults.standard.removeObject(forKey: locationsKey)
    }

    func requestLocation() {
        isLoading = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let cityName = placemarks?.first?.locality ?? "Mia Posizione"
            let newLoc = WeatherLocation(name: cityName, lat: location.coordinate.latitude, lon: location.coordinate.longitude)

            DispatchQueue.main.async {
                if !self.locations.contains(where: { $0.name == cityName }) {
                    self.locations.insert(newLoc, at: 0)
                    self.saveLocations()
                    self.syncToCloud(newLoc)
                }
                self.fetchWeather(for: newLoc)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = "Errore localizzazione: \(error.localizedDescription)"
        self.isLoading = false
    }

    // BUG-07 FIX: Controlla i duplicati prima di aggiungere.
    // Nota: il callback ora chiama il completionHandler per consentire feedback all'utente.
    func addCity(name: String, completion: ((Bool) -> Void)? = nil) {
        CLGeocoder().geocodeAddressString(name) { placemarks, error in
            guard let loc = placemarks?.first?.location, error == nil else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            let cityName = placemarks?.first?.locality ?? name
            let newLoc = WeatherLocation(name: cityName, lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)

            DispatchQueue.main.async {
                // BUG-07 FIX: Controlla duplicati per nome città
                guard !self.locations.contains(where: { $0.name == cityName }) else {
                    completion?(true) // Esiste già, ma non è un errore
                    return
                }
                self.locations.append(newLoc)
                self.saveLocations()
                self.syncToCloud(newLoc)
                self.fetchWeather(for: newLoc)
                completion?(true)
            }
        }
    }

    func removeCity(at indexSet: IndexSet) {
        let toDelete = indexSet.map { locations[$0] }
        locations.remove(atOffsets: indexSet)
        saveLocations()
        for loc in toDelete {
            Task { try? await SupabaseManager.shared.deleteWeatherLocation(id: loc.id) }
        }
    }

    private func syncToCloud(_ loc: WeatherLocation) {
        guard SupabaseManager.shared.isAuthenticated else { return }
        Task { try? await SupabaseManager.shared.upsertWeatherLocation(loc) }
    }

    func refreshAll() {
        for loc in locations {
            fetchWeather(for: loc)
        }
    }

    func fetchWeather(for location: WeatherLocation) {
        // BUG-08 FIX: Aggiunge "timeformat=iso8601" per ricevere i timestamp
        // orari come stringhe ISO8601 reali invece di numeri offset.
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.lat)&longitude=\(location.lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,pressure_msl,surface_pressure,wind_speed_10m,uv_index,visibility&hourly=temperature_2m,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&timeformat=iso8601"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: OpenMeteoResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let err) = completion {
                    print("Weather error: \(err)")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.weatherData[location.id] = self.parseResponse(response, location: location)
            }
            .store(in: &cancellables)
    }

    // BUG-08 FIX: Il parser ora usa i timestamp ISO8601 dall'API invece di
    // calcolare le ore sommando al startOfDay locale, che può essere sfasato
    // se l'utente usa l'app dopo mezzanotte senza aggiornare.
    private func parseResponse(_ res: OpenMeteoResponse, location: WeatherLocation) -> WeatherData {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentIsDay = currentHour >= 6 && currentHour < 20
        let currentCondition = weatherCodeToCondition(res.current.weather_code, isDay: currentIsDay)

        let current = CurrentWeather(
            temp: res.current.temperature_2m,
            description: weatherCodeToText(res.current.weather_code),
            condition: currentCondition,
            humidity: res.current.relative_humidity_2m,
            windSpeed: res.current.wind_speed_10m,
            uvIndex: res.current.uv_index,
            visibility: res.current.visibility / 1000.0,
            pressure: res.current.pressure_msl,
            feelsLike: res.current.apparent_temperature
        )

        // Parseamo i timestamp orari dalla risposta ISO8601 dell'API
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        var hourly: [HourlyWeather] = []
        for i in 0..<res.hourly.temperature_2m.count {
            // BUG-08: Usa il timestamp reale dell'API
            let timeString = res.hourly.time[i]
            let time = isoFormatter.date(from: timeString) ?? Date()
            let hourComponent = Calendar.current.component(.hour, from: time)
            let isDay = hourComponent >= 6 && hourComponent < 20

            hourly.append(HourlyWeather(
                time: time,
                temp: res.hourly.temperature_2m[i],
                condition: weatherCodeToCondition(res.hourly.weather_code[i], isDay: isDay),
                description: weatherCodeToText(res.hourly.weather_code[i]),
                rainProbability: res.hourly.precipitation_probability[i]
            ))
        }

        var daily: [DailyWeather] = []
        for i in 0..<res.daily.temperature_2m_max.count {
            let dateString = res.daily.time[i]
            // Le date giornaliere sono solo "YYYY-MM-DD"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: dateString) ?? Date()

            daily.append(DailyWeather(
                date: date,
                tempMin: res.daily.temperature_2m_min[i],
                tempMax: res.daily.temperature_2m_max[i],
                condition: weatherCodeToCondition(res.daily.weather_code[i], isDay: true),
                description: weatherCodeToText(res.daily.weather_code[i]),
                rainProbability: res.daily.precipitation_probability_max[i]
            ))
        }

        return WeatherData(city: location.name, current: current, hourly: hourly, daily: daily)
    }

    private func weatherCodeToText(_ code: Int) -> String {
        switch code {
        case 0: return "Sereno"
        case 1, 2, 3: return "Nuvoloso"
        case 45, 48: return "Nebbia"
        case 51, 53, 55: return "Pioggerellina"
        case 61, 63, 65: return "Pioggia"
        case 71, 73, 75: return "Neve"
        case 95: return "Temporale"
        default: return "Variabile"
        }
    }

    private func weatherCodeToCondition(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sunny" : "clear_night"
        case 1, 2, 3: return "cloudy"
        case 45, 48: return "fog"
        case 51, 53, 55, 61, 63, 65: return "rainy"
        case 71, 73, 75: return "snowy"
        case 95: return "thunder"
        default: return isDay ? "sunny" : "clear_night"
        }
    }
}

// MARK: - API Models
// BUG-08 FIX: HourlyData ora include l'array `time` con le stringhe ISO8601
struct OpenMeteoResponse: Codable {
    let current: CurrentData
    let hourly: HourlyData
    let daily: DailyData
}

struct CurrentData: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let weather_code: Int
    let pressure_msl: Double
    let wind_speed_10m: Double
    let uv_index: Double
    let visibility: Double
}

struct HourlyData: Codable {
    let time: [String]            // BUG-08 FIX: array timestamp ISO8601
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int]
}

struct DailyData: Codable {
    let time: [String]             // BUG-08 FIX: array date ISO8601
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]
}
