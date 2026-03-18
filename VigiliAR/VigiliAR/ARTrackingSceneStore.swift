import Foundation
import Combine
import RealityKit
internal import CoreGraphics

struct ARGeneratedOverlay {
    let id: UUID
    let anchor: AnchorEntity
    var vehicleScanID: UUID?
}

final class ARTrackingSceneStore: ObservableObject {
    let arView = ARView(frame: .zero)
    var isSessionConfigured = false
    var isTapGestureInstalled = false
    var overlays: [ARGeneratedOverlay] = []
}
