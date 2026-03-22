import SwiftUI
import MapKit

struct ServiceTrackView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @State private var cameraPosition: MapCameraPosition = .automatic

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
                        Text("Tracciato Operatore")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Punto di partenza e spostamenti durante il servizio")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if userProfileStore.serviceTrackPoints.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "map")
                                .font(.system(size: 42))
                                .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                            Text("Tracciato non disponibile")
                                .font(.headline)
                            Text("Muoviti con geolocalizzazione attiva per registrare il percorso.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                    } else {
                        mapCard
                        timelineCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Tracciato")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fitCameraToTrackIfNeeded()
        }
        .onChange(of: userProfileStore.serviceTrackPoints.count) { _ in
            fitCameraToTrackIfNeeded()
        }
    }

    private var mapCard: some View {
        let coordinates = userProfileStore.serviceTrackPoints.map(\.coordinate)
        return Map(position: $cameraPosition) {
            if let start = userProfileStore.serviceTrackPoints.first {
                Marker("Partenza", systemImage: "flag.fill", coordinate: start.coordinate)
                    .tint(.green)
            }
            if let current = userProfileStore.serviceTrackPoints.last {
                Marker("Posizione Attuale", systemImage: "location.fill", coordinate: current.coordinate)
                    .tint(.red)
            }
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color(red: 0.07, green: 0.28, blue: 0.52), lineWidth: 5)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }

    private var timelineCard: some View {
        let points = userProfileStore.serviceTrackPoints
        let lastTen = Array(points.suffix(10))
        return VStack(alignment: .leading, spacing: 10) {
            Label("Ultimi Spostamenti", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.headline)
                .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))

            ForEach(lastTen.reversed()) { point in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline.weight(.semibold))
                        Text(formattedCoordinate(point.coordinate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

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

#Preview {
    NavigationStack {
        ServiceTrackView()
            .environmentObject(UserProfileStore())
    }
}
