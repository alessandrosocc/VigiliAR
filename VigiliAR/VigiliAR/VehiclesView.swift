import SwiftUI

struct VehiclesView: View {
    @EnvironmentObject private var vehicleStore: VehicleStore
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        List {
            if vehicleStore.scans.isEmpty {
                ContentUnavailableView(
                    "No Vehicles Yet",
                    systemImage: "car",
                    description: Text("Scan a vehicle from AR Tracking to see it here.")
                )
            } else {
                Section("Veicoli") {
                    ForEach(vehicleStore.scans) { scan in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(scan.plate, systemImage: "car.fill")
                                    .font(.headline)
                                Spacer()
                                Label(
                                    scan.capturedAt.formatted(date: .abbreviated, time: .shortened),
                                    systemImage: "clock"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            ForEach(scan.details) { detail in
                                let presentation = detailPresentation(for: detail)
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: presentation.icon)
                                        .foregroundStyle(.blue)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(presentation.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(presentation.value)
                                            .font(.subheadline.weight(.medium))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top) {
            Text("👋🏻 Hello, \(userProfileStore.greetingName)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("Vehicles")
    }

    private func detailPresentation(for detail: VehicleDetail) -> (title: String, value: String, icon: String) {
        let normalized = normalizedKey(detail.key)
        switch normalized {
        case let key where key.contains("color"):
            return ("Colore", detail.value, "paintpalette.fill")
        case let key where key.contains("insurance"):
            return ("Scadenza Assicurazione", detail.value, "shield.checkered")
        case let key where key.contains("revision"):
            return ("Scadenza revisione", detail.value, "wrench.and.screwdriver.fill")
        case let key where key.contains("last seen"):
            return ("Ultima vista", formattedLastSeen(detail.value), "eye.fill")
        default:
            return (detail.key, detail.value, "info.circle.fill")
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
