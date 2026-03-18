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
                Section("Vehicles") {
                    ForEach(vehicleStore.scans) { scan in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(scan.plate)")
                                .font(.headline)

                            Text(scan.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(scan.details) { detail in
                                Text("\(detail.key): \(detail.value)")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
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
}

#Preview {
    NavigationStack {
        VehiclesView()
            .environmentObject(VehicleStore())
            .environmentObject(UserProfileStore())
    }
}
