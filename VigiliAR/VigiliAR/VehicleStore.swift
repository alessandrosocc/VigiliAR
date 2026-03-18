import Foundation
import Combine

struct VehicleScan: Identifiable, Equatable {
    let id: UUID
    let plate: String
    let capturedAt: Date
    let details: [VehicleDetail]
}

struct VehicleDetail: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
}

final class VehicleStore: ObservableObject {
    @Published private(set) var scans: [VehicleScan] = []

    func add(_ scan: VehicleScan) {
        scans.insert(scan, at: 0)
    }

    func remove(scanID: UUID) {
        scans.removeAll { $0.id == scanID }
    }
}
