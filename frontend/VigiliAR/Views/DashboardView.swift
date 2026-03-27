import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore
    let serviceTimer: Publishers.Autoconnect<Timer.TimerPublisher>
    @State private var now = Date()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 42, height: 42)

                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)

                                    Image(systemName: "shield")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .fixedSize()

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("VigiliAR")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)

                                    Text("Controllo soste")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                            }

                            Spacer()

                            Button {
                                userProfileStore.logout()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 40, height: 40)

                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)

                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 44)

                        // Welcome block
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Bentornato")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .textCase(.uppercase)

                            Text(userProfileStore.greetingName)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            Text("Dashboard operativa")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Service card
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

                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .fixedSize()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Presa Servizio")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)

                                    Text("Sessione operativa attiva")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer(minLength: 0)
                            }

                            // Time row
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primary.opacity(0.18))
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }

                                Text(userProfileStore.formattedServiceStartDateTime)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 14)
                            )

                            // Location row
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.18))
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.cyan)
                                }

                                if userProfileStore.isResolvingServiceLocation {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)

                                        Text("Ricerca via...")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                } else {
                                    Text(userProfileStore.serviceStreet)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 14)
                            )

                            // Service status / duration row
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.green)

                                    Text("Turno attivo")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.12), in: Capsule())

                                Spacer()

                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textSecondary)

                                    Text(userProfileStore.formattedServiceDuration)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(.top, 10)

                            if shouldShowServiceStatusMessage {
                                DashboardStatusMessageRow(
                                    message: userProfileStore.serviceStatusMessage,
                                    tone: .warning
                                )
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
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
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)

                        // Actions
                        VStack(spacing: 14) {
                            NavigationLink(destination: VehiclesView()) {
                                DashboardActionTile(
                                    title: "Visura Veicoli",
                                    subtitle: "Consulta rapidamente i veicoli rilevati",
                                    systemImage: "car.fill",
                                    accentColor: Color.cyan,
                                    isPrimary: false
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: ARTrackingView()) {
                                DashboardActionTile(
                                    title: "Inizia Rilevazione",
                                    subtitle: "Apri la scena AR e acquisisci il veicolo",
                                    systemImage: "camera.viewfinder",
                                    accentColor: AppTheme.primary,
                                    isPrimary: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: ServiceTrackView()) {
                                DashboardActionTile(
                                    title: "Tracciato Operatore",
                                    subtitle: "Visualizza percorso e punti del servizio",
                                    systemImage: "map.fill",
                                    accentColor: Color.green,
                                    isPrimary: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
                    .padding(.bottom, 28)
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !isRunningInPreview else { return }
            userProfileStore.startServiceSessionIfNeeded()
        }
        .onReceive(serviceTimer) { value in
            now = value
        }
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var shouldShowServiceStatusMessage: Bool {
        if userProfileStore.serviceStatusMessage.isEmpty { return false }
        if userProfileStore.isResolvingServiceLocation { return true }
        if userProfileStore.serviceStatusMessage.contains("non salvata") { return true }

        return userProfileStore.serviceStreet == "Via non disponibile" ||
               userProfileStore.serviceStreet == "Posizione non autorizzata"
    }
}

private struct DashboardActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isPrimary ? 0.12 : 0.08), lineWidth: 1)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(chevronColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tileStroke, lineWidth: 1)
        )
        .shadow(color: tileShadowColor, radius: isPrimary ? 12 : 8, x: 0, y: isPrimary ? 6 : 4)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var iconBackground: some ShapeStyle {
        LinearGradient(
            colors: isPrimary
                ? [Color.white.opacity(0.18), Color.white.opacity(0.08)]
                : [accentColor.opacity(0.24), accentColor.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconForeground: Color {
        isPrimary ? .white : accentColor
    }

    private var titleColor: Color {
        .white
    }

    private var subtitleColor: Color {
        isPrimary ? Color.white.opacity(0.78) : AppTheme.textSecondary
    }

    private var chevronColor: Color {
        isPrimary ? Color.white.opacity(0.82) : AppTheme.textMuted
    }

    private var tileStroke: Color {
        Color.white.opacity(isPrimary ? 0.14 : 0.10)
    }

    private var tileShadowColor: Color {
        isPrimary ? AppTheme.primary.opacity(0.22) : .black.opacity(0.10)
    }

    @ViewBuilder
    private var tileBackground: some View {
        if isPrimary {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.07), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}

private struct DashboardStatusMessageRow: View {
    enum Tone {
        case warning
        case neutral
    }

    let message: String
    let tone: Tone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 16, height: 16)
                .padding(.top, 1)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch tone {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch tone {
        case .warning:
            return Color.orange.opacity(0.95)
        case .neutral:
            return AppTheme.primary
        }
    }

    private var textColor: Color {
        switch tone {
        case .warning:
            return Color.white.opacity(0.84)
        case .neutral:
            return AppTheme.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .warning:
            return Color.orange.opacity(0.10)
        case .neutral:
            return Color.white.opacity(0.06)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .warning:
            return Color.orange.opacity(0.16)
        case .neutral:
            return Color.white.opacity(0.08)
        }
    }
}

#Preview("Dashboard") {
    NavigationStack {
        DashboardView(serviceTimer: Timer.publish(every: 60, on: .main, in: .common).autoconnect())
            .environmentObject(
                UserProfileStore.previewDashboard(
                    name: "Alessandro",
                    surname: "Soccol",
                    identifier: "alesoccol2001",
                    serviceStartedAt: Date().addingTimeInterval(-4200),
                    serviceStreet: "Via Nomentana, Roma",
                    currentStreet: "Viale Regina Margherita, Roma"
                )
            )
            .environmentObject(VehicleStore())
            .environmentObject(ARTrackingSceneStore())
    }
}

#Preview("Dashboard - Loading Location") {
    NavigationStack {
        DashboardView(serviceTimer: Timer.publish(every: 60, on: .main, in: .common).autoconnect())
            .environmentObject(UserProfileStore.previewDashboardResolvingLocation())
            .environmentObject(VehicleStore())
            .environmentObject(ARTrackingSceneStore())
    }
}

#Preview("Dashboard - Location Denied") {
    NavigationStack {
        DashboardView(serviceTimer: Timer.publish(every: 60, on: .main, in: .common).autoconnect())
            .environmentObject(UserProfileStore.previewDashboardLocationDenied())
            .environmentObject(VehicleStore())
            .environmentObject(ARTrackingSceneStore())
    }
}
