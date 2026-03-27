import SwiftUI

struct VehiclesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vehicleStore: VehicleStore
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        headerSection
                        titleSection

                        if vehicleStore.scans.isEmpty {
                            emptyStateCard
                        } else {
                            scansSection
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
                    .padding(.bottom, 36)
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)

                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 42, height: 42)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)

                    Image(systemName: "car.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 2) {
                    Text("VigiliAR")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Visura veicoli")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            Spacer()
        }
        .frame(height: 44)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VISURA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .textCase(.uppercase)

            Text("Veicoli Rilevati")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("Operatore: \(userProfileStore.greetingName)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primary.opacity(0.28),
                                    Color.cyan.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)

                    Image(systemName: "car.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nessun veicolo rilevato")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)

                    Text("La lista si popolerà dopo una rilevazione AR")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Text("Avvia una rilevazione AR per acquisire il veicolo e vedere qui i dettagli della visura.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cyan)

                Text("I risultati compariranno automaticamente in questa schermata.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.84))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    // MARK: - Scans

    private var scansSection: some View {
        VStack(spacing: 16) {
            ForEach(vehicleStore.scans) { scan in
                vehicleCard(scan)
            }
        }
    }

    private func vehicleCard(_ scan: VehicleScan) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primary.opacity(0.28),
                                    Color.cyan.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)

                    Image(systemName: "car.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    Text(scan.plate)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(scan.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            infoRow(
                icon: "mappin.and.ellipse",
                title: "Via rilevazione",
                value: scan.capturedStreet
            )

            VStack(spacing: 12) {
                ForEach(scan.details) { detail in
                    let presentation = detailPresentation(for: detail)

                    detailRow(
                        icon: presentation.icon,
                        title: presentation.title,
                        value: presentation.value,
                        status: presentation.status
                    )
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.18))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func detailRow(
        icon: String,
        title: String,
        value: String,
        status: (text: String, color: Color)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.18))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer(minLength: 8)

            if let status {
                StatusBadge(text: status.text, color: status.color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Presentation

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
            "dd-MM-yyyy"
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

    // MARK: - Shared Card Style

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.10))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.05),
                            AppTheme.primary.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .clear,
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(.white.opacity(0.10), lineWidth: 1)
    }
}

#Preview("Vehicles - Filled") {
    NavigationStack {
        VehiclesView()
            .environmentObject(VehicleStore.previewWithScans())
            .environmentObject(UserProfileStore.previewDashboard())
    }
}

#Preview("Vehicles - Empty") {
    NavigationStack {
        VehiclesView()
            .environmentObject(VehicleStore.previewEmpty())
            .environmentObject(UserProfileStore.previewDashboard())
    }
}
