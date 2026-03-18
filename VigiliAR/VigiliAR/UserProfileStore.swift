import Foundation
import Combine

final class UserProfileStore: ObservableObject {
    @Published var name: String = ""
    @Published var surname: String = ""
    @Published var identifier: String = ""

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var authStatusMessage: String = ""

    private let apiBaseURL = "http://192.168.1.60:8000"

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
                }
                self.isAuthenticated = true
                self.authStatusMessage = ""
            }
        }.resume()
    }

    func logout() {
        isAuthenticated = false
        authStatusMessage = ""
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
}
