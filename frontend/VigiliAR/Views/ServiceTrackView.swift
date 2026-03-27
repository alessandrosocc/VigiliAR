import SwiftUI
import MapKit
import CoreLocation

struct ServiceTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        headerSection
                        titleSection

                        if userProfileStore.serviceTrackPoints.isEmpty {
                            emptyStateCard
                        } else {
                            mapCard
                            timelineCard
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
        .onAppear {
            fitCameraToTrackIfNeeded()
        }
        .onChange(of: trackSignature) { _ in
            fitCameraToTrackIfNeeded()
        }
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

                    Image(systemName: "map")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 2) {
                    Text("VigiliAR")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Tracciato operatore")
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
            Text("TRACCIATO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .textCase(.uppercase)

            Text("Percorso Operatore")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("Segmenti del percorso registrato e posizione attuale dell’operatore durante il servizio")
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

                    Image(systemName: "map")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracciato non disponibile")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)

                    Text("Nessuno spostamento registrato")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Text("Muoviti con geolocalizzazione attiva per iniziare a registrare il percorso dell’operatore durante il servizio.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cyan)

                Text("La timeline verrà popolata automaticamente quando saranno disponibili nuovi punti GPS.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .multilineTextAlignment(.leading)
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

    // MARK: - Map Card

    private var mapCard: some View {
        let points = userProfileStore.serviceTrackPoints
        let coordinates = points.map(\.coordinate)

        return VStack(alignment: .leading, spacing: 18) {
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

                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Percorso registrato")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)

                    Text("\(points.count) punti rilevati")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Map(position: $cameraPosition) {
                if coordinates.count >= 2 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(AppTheme.primary, lineWidth: 5)
                }

                if points.count == 1 {
                    if let point = points.first {
                        Annotation("Posizione attuale", coordinate: point.coordinate) {
                            CurrentLocationMarker()
                        }
                    }
                } else {
                    if let start = points.first {
                        Annotation("Partenza", coordinate: start.coordinate) {
                            StartLocationMarker()
                        }
                    }

                    if points.count > 2 {
                        ForEach(Array(points.dropFirst().dropLast())) { point in
                            Annotation("", coordinate: point.coordinate) {
                                IntermediateTrackMarker()
                            }
                        }
                    }

                    if let current = points.last {
                        Annotation("Posizione attuale", coordinate: current.coordinate) {
                            CurrentLocationMarker()
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    trackInfoPill(
                        systemImage: "flag.fill",
                        text: "Partenza",
                        tint: .green
                    )

                    trackInfoPill(
                        systemImage: "circle.fill",
                        text: "Punti registrati",
                        tint: AppTheme.primary
                    )

                    trackInfoPill(
                        systemImage: "location.fill",
                        text: "Posizione attuale",
                        tint: .red
                    )
                }

                Text("I punti blu rappresentano i segmenti registrati del tracciato; il marker rosso indica la posizione attuale.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        let lastTen = Array(userProfileStore.serviceTrackPoints.suffix(10))

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.22),
                                    Color.cyan.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)

                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ultimi spostamenti")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.green)

                    Text("Cronologia recente del servizio")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                ForEach(lastTen.reversed()) { point in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.18))
                                .frame(width: 30, height: 30)

                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(formattedCoordinate(point.coordinate))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
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
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    // MARK: - Shared UI Helpers

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

    private var trackSignature: [String] {
        userProfileStore.serviceTrackPoints.map {
            "\($0.coordinate.latitude)-\($0.coordinate.longitude)-\($0.timestamp.timeIntervalSince1970)"
        }
    }

    private func trackInfoPill(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Map Fitting

    private func fitCameraToTrackIfNeeded() {
        let points = userProfileStore.serviceTrackPoints
        guard !points.isEmpty else { return }

        if points.count == 1, let point = points.first {
            let region = MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0035, longitudeDelta: 0.0035)
            )
            cameraPosition = .region(region)
            return
        }

        var minLat = points[0].coordinate.latitude
        var maxLat = minLat
        var minLon = points[0].coordinate.longitude
        var maxLon = minLon

        for point in points {
            minLat = min(minLat, point.coordinate.latitude)
            maxLat = max(maxLat, point.coordinate.latitude)
            minLon = min(minLon, point.coordinate.longitude)
            maxLon = max(maxLon, point.coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = max((maxLat - minLat) * 1.8, 0.0035)
        let lonDelta = max((maxLon - minLon) * 1.8, 0.0035)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        cameraPosition = .region(region)
    }

    private func formattedCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Map Markers

private struct StartLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 24, height: 24)

            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}

private struct CurrentLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 24, height: 24)

            Image(systemName: "location.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}

private struct IntermediateTrackMarker: View {
    var body: some View {
        Circle()
            .fill(AppTheme.primary)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

#Preview("Service Track") {
    NavigationStack {
        ServiceTrackView()
            .environmentObject(UserProfileStore.previewServiceTrack())
    }
}

#Preview("Service Track - Empty") {
    NavigationStack {
        ServiceTrackView()
            .environmentObject(UserProfileStore.previewServiceTrackEmpty())
    }
}
