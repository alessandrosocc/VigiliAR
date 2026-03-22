import Foundation
import Combine
import CoreLocation

struct ServiceTrackPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}

final class UserProfileStore: NSObject, ObservableObject {
    @Published var name: String = ""
    @Published var surname: String = ""
    @Published var identifier: String = ""

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var authStatusMessage: String = ""
    @Published private(set) var serviceStartedAt: Date?
    @Published private(set) var serviceStreet: String = "Via non disponibile"
    @Published private(set) var currentStreet: String = "Via non disponibile"
    @Published private(set) var isResolvingServiceLocation: Bool = false
    @Published private(set) var serviceStatusMessage: String = ""
    @Published private(set) var serviceTrackPoints: [ServiceTrackPoint] = []

    private let apiBaseURL = "http://192.168.1.81:8000"
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasSubmittedServiceCheckIn: Bool = false
    private var didAskLocationPermission: Bool = false
    private var isReverseGeocodeInFlight: Bool = false
    private var lastTrackedLocation: CLLocation?
    private var lastTrackedAt: Date?
    private var lastStreetLookupAt: Date?
    private let minimumTrackDistanceMeters: CLLocationDistance = 6
    private let minimumTrackTimeInterval: TimeInterval = 6
    private let streetLookupInterval: TimeInterval = 20

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 5
    }

    var greetingName: String {
        let first = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.isEmpty && last.isEmpty { return "there" }
        if last.isEmpty { return first }
        if first.isEmpty { return last }
        return "\(first), \(last)"
    }

    var fullName: String {
        let joined = "\(name) \(surname)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        return joined
    }

    var canAttemptLogin: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedServiceStartDateTime: String {
        guard let serviceStartedAt else { return "In attesa di presa servizio" }
        return serviceStartedAt.formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "it_IT"))
                .day().month(.twoDigits).year()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    func login() {
        guard canAttemptLogin else {
            authStatusMessage = "Inserisci Nome, Cognome e Identificativo."
            return
        }

        guard let url = URL(string: "\(apiBaseURL)/auth/login") else {
            authStatusMessage = "URL backend non valida."
            return
        }

        isAuthenticating = true
        authStatusMessage = "Verifica credenziali in corso..."

        let payload: [String: Any] = [
            "Nome": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "Cognome": surname.trimmingCharacters(in: .whitespacesAndNewlines),
            "matricola": identifier.trimmingCharacters(in: .whitespacesAndNewlines),
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            isAuthenticating = false
            authStatusMessage = "Payload login non valido."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false

                if let error {
                    self.isAuthenticated = false
                    self.authStatusMessage = "Errore rete: \(error.localizedDescription)"
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    self.isAuthenticated = false
                    self.authStatusMessage = "Risposta server non valida."
                    return
                }

                guard let data else {
                    self.isAuthenticated = false
                    self.authStatusMessage = "Risposta vuota dal server."
                    return
                }

                if !(200...299).contains(http.statusCode) {
                    self.isAuthenticated = false
                    self.authStatusMessage = self.extractBackendError(from: data) ?? "Login non autorizzato."
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let authenticated = json["authenticated"] as? Bool,
                      authenticated else {
                    self.isAuthenticated = false
                    self.authStatusMessage = "Credenziali non valide."
                    return
                }

                if let user = json["user"] as? [String: Any] {
                    self.name = (user["name"] as? String) ?? self.name
                    self.surname = (user["surname"] as? String) ?? self.surname
                    self.identifier = (user["matricola"] as? String) ?? self.identifier
                }
                self.isAuthenticated = true
                self.authStatusMessage = ""
                self.startServiceSessionIfNeeded()
            }
        }.resume()
    }

    func logout() {
        isAuthenticated = false
        authStatusMessage = ""
        serviceStartedAt = nil
        serviceStreet = "Via non disponibile"
        currentStreet = "Via non disponibile"
        serviceStatusMessage = ""
        isResolvingServiceLocation = false
        hasSubmittedServiceCheckIn = false
        didAskLocationPermission = false
        isReverseGeocodeInFlight = false
        lastTrackedLocation = nil
        lastTrackedAt = nil
        lastStreetLookupAt = nil
        serviceTrackPoints = []
        locationManager.stopUpdatingLocation()
    }

    func startServiceSessionIfNeeded() {
        guard isAuthenticated else { return }
        if serviceStartedAt == nil {
            serviceStartedAt = Date()
        }
        requestServiceLocation()
    }

    private func extractBackendError(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = json["detail"] as? String {
            return detail
        }
        return nil
    }

    private func requestServiceLocation() {
        let hasResolvedStreet = serviceStreet != "Via non disponibile" &&
            serviceStreet != "Posizione non autorizzata" &&
            !serviceStreet.hasPrefix("Coordinate ")

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            guard !didAskLocationPermission else { return }
            didAskLocationPermission = true
            isResolvingServiceLocation = true
            serviceStatusMessage = "Autorizza la geolocalizzazione per registrare la presa servizio."
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            locationManager.stopUpdatingLocation()
            isResolvingServiceLocation = false
            serviceStreet = "Posizione non autorizzata"
            serviceStatusMessage = "Posizione non disponibile: autorizzazione negata."
            submitServiceCheckInIfNeeded(location: nil, street: serviceStreet)
        case .authorizedAlways, .authorizedWhenInUse:
            if hasResolvedStreet {
                isResolvingServiceLocation = false
                if !serviceStatusMessage.contains("non salvata") {
                    serviceStatusMessage = ""
                }
            } else {
                isResolvingServiceLocation = true
                serviceStatusMessage = "Rilevazione posizione in corso..."
            }
            locationManager.startUpdatingLocation()
        @unknown default:
            isResolvingServiceLocation = false
            serviceStreet = "Posizione non disponibile"
            serviceStatusMessage = "Impossibile rilevare la posizione."
            submitServiceCheckInIfNeeded(location: nil, street: serviceStreet)
        }
    }

    private func composeStreet(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let streetName = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let streetNumber = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let locality = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var base = ""
        if !streetName.isEmpty && !streetNumber.isEmpty {
            base = "\(streetName), \(streetNumber)"
        } else if !streetName.isEmpty {
            base = streetName
        }

        if !locality.isEmpty {
            return base.isEmpty ? locality : "\(base) - \(locality)"
        }
        return base.isEmpty ? nil : base
    }

    private func fallbackStreet(from location: CLLocation) -> String {
        let lat = String(format: "%.5f", location.coordinate.latitude)
        let lon = String(format: "%.5f", location.coordinate.longitude)
        return "Coordinate \(lat), \(lon)"
    }

    private func appendTrackPointIfNeeded(_ location: CLLocation) {
        let now = Date()
        if let previousLocation = lastTrackedLocation, let previousTime = lastTrackedAt {
            let movedMeters = location.distance(from: previousLocation)
            let elapsed = now.timeIntervalSince(previousTime)
            if movedMeters < minimumTrackDistanceMeters && elapsed < minimumTrackTimeInterval {
                return
            }
        }

        lastTrackedLocation = location
        lastTrackedAt = now
        serviceTrackPoints.append(
            ServiceTrackPoint(
                coordinate: location.coordinate,
                timestamp: now
            )
        )
    }

    private func submitServiceCheckInIfNeeded(location: CLLocation?, street: String) {
        guard isAuthenticated else { return }
        guard !hasSubmittedServiceCheckIn else { return }
        guard let startedAt = serviceStartedAt else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startedAtISO = formatter.string(from: startedAt)

        var payload: [String: Any] = [
            "Nome": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "Cognome": surname.trimmingCharacters(in: .whitespacesAndNewlines),
            "matricola": identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            "data_ora_presa_servizio": startedAtISO,
            "via": street,
        ]

        if let location {
            payload["latitude"] = location.coordinate.latitude
            payload["longitude"] = location.coordinate.longitude
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        hasSubmittedServiceCheckIn = true
        postServiceCheckIn(body: body, endpointPaths: ["/service/checkin", "/service/check-in"])
    }

    private func postServiceCheckIn(body: Data, endpointPaths: [String]) {
        guard let path = endpointPaths.first else {
            DispatchQueue.main.async {
                self.hasSubmittedServiceCheckIn = false
                self.serviceStatusMessage = "Presa servizio non salvata: endpoint non disponibile."
            }
            return
        }
        guard let url = URL(string: "\(apiBaseURL)\(path)") else {
            DispatchQueue.main.async {
                self.hasSubmittedServiceCheckIn = false
                self.serviceStatusMessage = "Presa servizio non salvata: URL backend non valida."
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.hasSubmittedServiceCheckIn = false
                    self.serviceStatusMessage = "Presa servizio non salvata: \(error.localizedDescription)"
                }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.hasSubmittedServiceCheckIn = false
                    self.serviceStatusMessage = "Presa servizio non salvata: risposta server non valida."
                }
                return
            }

            if http.statusCode == 404, endpointPaths.count > 1 {
                self.postServiceCheckIn(body: body, endpointPaths: Array(endpointPaths.dropFirst()))
                return
            }

            guard (200...299).contains(http.statusCode) else {
                DispatchQueue.main.async {
                    self.hasSubmittedServiceCheckIn = false
                    let backendMessage = data.flatMap { self.extractBackendError(from: $0) } ?? "Errore server."
                    if http.statusCode == 404 {
                        self.serviceStatusMessage = "Presa servizio non salvata: endpoint check-in non trovato (404). Riavvia il backend aggiornato."
                    } else {
                        self.serviceStatusMessage = "Presa servizio non salvata: \(backendMessage)"
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.serviceStatusMessage = "Presa servizio registrata."
            }
        }.resume()
    }
}

extension UserProfileStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if !isAuthenticated { return }
        requestServiceLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isResolvingServiceLocation = false
            serviceStreet = "Posizione non disponibile"
            currentStreet = "Posizione non disponibile"
            submitServiceCheckInIfNeeded(location: nil, street: serviceStreet)
            return
        }
        appendTrackPointIfNeeded(location)

        if currentStreet == "Via non disponibile" {
            currentStreet = fallbackStreet(from: location)
        }

        let now = Date()
        let shouldRefreshCurrentStreet =
            !isReverseGeocodeInFlight &&
            (lastStreetLookupAt == nil || now.timeIntervalSince(lastStreetLookupAt ?? .distantPast) >= streetLookupInterval)
        let shouldResolveStreet = serviceStreet == "Via non disponibile" || serviceStreet.hasPrefix("Coordinate ")
        guard shouldResolveStreet || shouldRefreshCurrentStreet else {
            if !hasSubmittedServiceCheckIn {
                submitServiceCheckInIfNeeded(location: location, street: serviceStreet)
            }
            return
        }

        isReverseGeocodeInFlight = true
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReverseGeocodeInFlight = false
                let resolvedStreet = self.composeStreet(from: placemarks?.first) ?? self.fallbackStreet(from: location)
                self.currentStreet = resolvedStreet
                self.lastStreetLookupAt = Date()

                if shouldResolveStreet {
                    self.isResolvingServiceLocation = false
                    self.serviceStreet = resolvedStreet
                    self.submitServiceCheckInIfNeeded(location: location, street: resolvedStreet)
                } else if !self.hasSubmittedServiceCheckIn {
                    self.submitServiceCheckInIfNeeded(location: location, street: self.serviceStreet)
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isResolvingServiceLocation = false
        serviceStreet = "Posizione non disponibile"
        serviceStatusMessage = "Impossibile leggere la posizione."
        submitServiceCheckInIfNeeded(location: nil, street: serviceStreet)
    }
}
