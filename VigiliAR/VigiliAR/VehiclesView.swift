import SwiftUI

struct VehiclesView: View {
    @EnvironmentObject private var vehicleStore: VehicleStore
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.88, green: 0.93, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visura Veicoli")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Operatore: \(userProfileStore.greetingName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if vehicleStore.scans.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "car.circle")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                            Text("Nessun veicolo rilevato")
                                .font(.headline)
                            Text("Avvia una rilevazione AR per vedere qui i risultati.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.75), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
                    } else {
                        ForEach(vehicleStore.scans) { scan in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    Label(scan.plate, systemImage: "car.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                                    Spacer()
                                    Label(
                                        scan.capturedAt.formatted(date: .abbreviated, time: .shortened),
                                        systemImage: "clock"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Via rilevazione")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(scan.capturedStreet)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer(minLength: 0)
                                }

                                ForEach(scan.details) { detail in
                                    let presentation = detailPresentation(for: detail)
                                    HStack(alignment: .top, spacing: 9) {
                                        Image(systemName: presentation.icon)
                                            .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(presentation.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(presentation.value)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        if let status = presentation.status {
                                            Text(status.text)
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(status.color.opacity(0.15), in: Capsule())
                                                .foregroundStyle(status.color)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Visura")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailPresentation(for detail: VehicleDetail) -> (title: String, value: String, icon: String, status: (text: String, color: Color)?) {
        let normalized = normalizedKey(detail.key)
        switch normalized {
        case let key where key.contains("park"):
            return ("Scadenza Parcheggio", formattedDate(detail.value), "parkingsign.circle.fill", expiryStatus(for: detail.value))
        case let key where key.contains("color"):
            return ("Colore", detail.value, "paintpalette.fill", nil)
        case let key where key.contains("insurance"):
            return ("Scadenza Assicurazione", formattedDate(detail.value), "shield.checkered", expiryStatus(for: detail.value))
        case let key where key.contains("revision"):
            return ("Scadenza Revisione", formattedDate(detail.value), "wrench.and.screwdriver.fill", expiryStatus(for: detail.value))
        case let key where key.contains("multa"):
            return ("Multa", formattedMulta(detail.value), "exclamationmark.triangle.fill", multaStatus(for: detail.value))
        case let key where key.contains("last seen"):
            return ("Ultima vista", formattedLastSeen(detail.value), "eye.fill", nil)
        default:
            return (detail.key, detail.value, "info.circle.fill", nil)
        }
    }

    private func normalizedKey(_ key: String) -> String {
        key
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func formattedLastSeen(_ raw: String) -> String {
        guard let date = parseDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd-MM-yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func formattedDate(_ raw: String) -> String {
        guard let date = parseDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }

    private func formattedMulta(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["true", "1", "si", "sì", "yes"].contains(value) { return "SI" }
        if ["false", "0", "no"].contains(value) { return "NO" }
        return "-"
    }

    private func expiryStatus(for raw: String) -> (text: String, color: Color)? {
        guard let date = parseDate(raw) else { return ("N/D", .gray) }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        return target >= today ? ("OK", .green) : ("SCADUTA", .red)
    }

    private func multaStatus(for raw: String) -> (text: String, color: Color)? {
        let value = formattedMulta(raw)
        if value == "SI" { return ("MULTATA", .red) }
        if value == "NO" { return ("NO MULTA", .green) }
        return ("N/D", .gray)
    }

    private func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm",
            "dd-MM-yyyy",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        VehiclesView()
            .environmentObject(VehicleStore())
            .environmentObject(UserProfileStore())
    }
}
