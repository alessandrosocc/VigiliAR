import Foundation
import Combine

struct VehicleScan: Identifiable, Equatable {
    let id: UUID
    let plate: String
    let capturedAt: Date
    let capturedStreet: String
    let details: [VehicleDetail]
}

struct VehicleDetail: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
}

final class VehicleStore: ObservableObject {
    @Published fileprivate(set) var scans: [VehicleScan] = []

    func add(_ scan: VehicleScan) {
        scans.insert(scan, at: 0)
    }

    func remove(scanID: UUID) {
        scans.removeAll { $0.id == scanID }
    }
}

#if DEBUG
extension VehicleStore {
    static func previewWithScans() -> VehicleStore {
        let store = VehicleStore()

        store.scans = [
            VehicleScan(
                id: UUID(),
                plate: "AB123CD",
                capturedAt: Date().addingTimeInterval(-900),
                capturedStreet: "Via Roma, Cagliari",
                details: [
                    VehicleDetail(key: "park_expiration", value: "2026-03-27"),
                    VehicleDetail(key: "color", value: "Bianco"),
                    VehicleDetail(key: "insurance_expiration", value: "2026-11-10"),
                    VehicleDetail(key: "revision_expiration", value: "2025-12-01"),
                    VehicleDetail(key: "multa", value: "false"),
                    VehicleDetail(key: "last_seen", value: "2026-03-27T20:35:00")
                ]
            ),
            VehicleScan(
                id: UUID(),
                plate: "EF456GH",
                capturedAt: Date().addingTimeInterval(-1800),
                capturedStreet: "Largo Carlo Felice, Cagliari",
                details: [
                    VehicleDetail(key: "park_expiration", value: "2026-03-20"),
                    VehicleDetail(key: "color", value: "Nero"),
                    VehicleDetail(key: "insurance_expiration", value: "2025-01-15"),
                    VehicleDetail(key: "revision_expiration", value: "2026-04-10"),
                    VehicleDetail(key: "multa", value: "true"),
                    VehicleDetail(key: "last_seen", value: "2026-03-27T19:58:00")
                ]
            )
        ]

        return store
    }

    static func previewEmpty() -> VehicleStore {
        VehicleStore()
    }
}
#endif
