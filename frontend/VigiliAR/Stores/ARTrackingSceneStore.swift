import Foundation
import Combine
import RealityKit
import CoreGraphics

struct ARGeneratedOverlay {
    let id: UUID
    let anchor: AnchorEntity
    var vehicleScanID: UUID?
}

@MainActor
final class ARTrackingSceneStore: ObservableObject {
    let arView: ARView

    @Published var isSessionConfigured = false
    @Published var isTapGestureInstalled = false
    @Published var isPinchGestureInstalled = false
    @Published var isTwoFingerPanGestureInstalled = false
    @Published private(set) var overlays: [ARGeneratedOverlay] = []

    init() {
        self.arView = ARView(frame: .zero)
    }

    init(arView: ARView) {
        self.arView = arView
    }

    func appendOverlay(_ overlay: ARGeneratedOverlay) {
        overlays.append(overlay)
    }

    @discardableResult
    func removeLastOverlay() -> ARGeneratedOverlay? {
        overlays.popLast()
    }

    func clearOverlays() {
        overlays.forEach { $0.anchor.removeFromParent() }
        overlays.removeAll()
    }

    func resetSessionFlags() {
        isSessionConfigured = false
        isTapGestureInstalled = false
        isPinchGestureInstalled = false
        isTwoFingerPanGestureInstalled = false
    }
}
