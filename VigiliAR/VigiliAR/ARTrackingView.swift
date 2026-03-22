import SwiftUI
import RealityKit
import ARKit

struct ARTrackingView: View {
    @EnvironmentObject private var vehicleStore: VehicleStore
    @EnvironmentObject private var sceneStore: ARTrackingSceneStore
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @State private var lastSnapshotFilename: String = "None"
    @State private var lastSnapshotPath: String = ""
    @State private var shareURL: URL?
    @State private var isShowingShareSheet: Bool = false
    @State private var deleteRequestCounter: Int = 0
    @State private var hasTappedForDetection: Bool = false

    var body: some View {
        ZStack {
            ARViewContainer(
                lastSnapshotFilename: $lastSnapshotFilename,
                lastSnapshotPath: $lastSnapshotPath,
                deleteRequestCounter: $deleteRequestCounter,
                hasTappedForDetection: $hasTappedForDetection,
                vehicleStore: vehicleStore,
                sceneStore: sceneStore,
                userProfileStore: userProfileStore
            )
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rilevazione AR")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Operatore: \(userProfileStore.greetingName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        deleteRequestCounter += 1
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Spacer()

                    Button {
                        guard !lastSnapshotPath.isEmpty else { return }
                        shareURL = URL(fileURLWithPath: lastSnapshotPath)
                        isShowingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(lastSnapshotPath.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if !hasTappedForDetection {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tocca lo schermo per creare il pannello sul veicolo rilevato.")
                            .font(.footnote.weight(.semibold))
                        Text(lastSnapshotPath.isEmpty ? "Nessuno snapshot condivisibile" : "Ultimo snapshot: \(lastSnapshotFilename)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)
                }

                Spacer()
            }
        }
        .navigationTitle("Rilevazione Auto")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }
}

private struct ARViewContainer: UIViewRepresentable {
    @Binding var lastSnapshotFilename: String
    @Binding var lastSnapshotPath: String
    @Binding var deleteRequestCounter: Int
    @Binding var hasTappedForDetection: Bool
    @ObservedObject var vehicleStore: VehicleStore
    @ObservedObject var sceneStore: ARTrackingSceneStore
    @ObservedObject var userProfileStore: UserProfileStore

    func makeUIView(context: Context) -> ARView {
        let arView = sceneStore.arView
        context.coordinator.arView = arView
        context.coordinator.lastSnapshotFilename = $lastSnapshotFilename
        context.coordinator.lastSnapshotPath = $lastSnapshotPath
        context.coordinator.hasTappedForDetection = $hasTappedForDetection
        context.coordinator.vehicleStore = vehicleStore
        context.coordinator.sceneStore = sceneStore
        context.coordinator.userProfileStore = userProfileStore

        if !sceneStore.isSessionConfigured {
            context.coordinator.configureSession()
            sceneStore.isSessionConfigured = true
        }
        context.coordinator.ensureSnapshotsDirectoryExists()

        // Rebind recognizers to the current coordinator to avoid stale targets.
        if let recognizers = arView.gestureRecognizers {
            for recognizer in recognizers {
                if recognizer is UITapGestureRecognizer || recognizer is UIPinchGestureRecognizer {
                    arView.removeGestureRecognizer(recognizer)
                    continue
                }
                if let pan = recognizer as? UIPanGestureRecognizer,
                   pan.minimumNumberOfTouches == 2,
                   pan.maximumNumberOfTouches == 2 {
                    arView.removeGestureRecognizer(pan)
                }
            }
        }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        sceneStore.isTapGestureInstalled = true

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)
        sceneStore.isPinchGestureInstalled = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(pan)
        sceneStore.isTwoFingerPanGestureInstalled = true
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard deleteRequestCounter != context.coordinator.lastHandledDeleteRequest else { return }
        context.coordinator.deleteLastGeneratedRectangle()
        context.coordinator.lastHandledDeleteRequest = deleteRequestCounter
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        private struct PanelField {
            let icon: String
            let label: String
            let value: String
            let color: UIColor
        }

        private struct PanelDisplay {
            let title: String
            let fields: [PanelField]
            let isParkExpired: Bool
            let showMultaButton: Bool
        }

        private struct PanelMetrics {
            let width: Float
            let height: Float
            let titleY: Float
            let firstRowY: Float
            let secondRowY: Float
            let leftColumnX: Float
            let rightColumnRightEdgeX: Float
            let buttonY: Float
        }

        weak var arView: ARView?
        var lastSnapshotFilename: Binding<String>?
        var lastSnapshotPath: Binding<String>?
        var hasTappedForDetection: Binding<Bool>?
        weak var vehicleStore: VehicleStore?
        weak var sceneStore: ARTrackingSceneStore?
        weak var userProfileStore: UserProfileStore?
        var lastHandledDeleteRequest: Int = 0
        private let apiBaseURL = "http://192.168.1.81:8000"
        private var multaButtonPlates: [String: String] = [:]
        private weak var activePinchPanel: Entity?
        private var activePinchStartScale: SIMD3<Float> = SIMD3<Float>(repeating: 1)
        private let minPanelScale: Float = 0.65
        private let maxPanelScale: Float = 2.2
        private weak var activePanPanel: Entity?
        private var activePanPlanePoint: SIMD3<Float> = .zero
        private var activePanPlaneNormal: SIMD3<Float> = SIMD3<Float>(0, 0, 1)
        private var activePanPanelOffset: SIMD3<Float> = .zero
        private let snapshotsFolderName = "VigiliAR Snapshots"

        func configureSession() {
            guard let arView else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            arView.automaticallyConfigureSession = false
            arView.renderOptions.insert(.disableMotionBlur)
            arView.session.run(configuration)
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let arView else { return }
            guard recognizer.numberOfTouches >= 2 else { return }

            switch recognizer.state {
            case .began:
                guard let panel = panelForPinchStart(recognizer, in: arView) else {
                    return
                }
                activePinchPanel = panel
                activePinchStartScale = panel.scale
            case .changed:
                guard let panel = activePinchPanel else { return }
                let rawScale = Float(recognizer.scale)
                let clamped = min(max(rawScale, minPanelScale), maxPanelScale)
                panel.scale = activePinchStartScale * clamped
            default:
                activePinchPanel = nil
                activePinchStartScale = SIMD3<Float>(repeating: 1)
            }
        }

        @objc func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let arView else { return }
            guard recognizer.numberOfTouches >= 2 else { return }

            switch recognizer.state {
            case .began:
                guard let panel = panelForPanStart(recognizer, in: arView) else { return }
                activePanPanel = panel
                let panelPosition = panel.position(relativeTo: nil)
                activePanPlanePoint = panelPosition
                activePanPlaneNormal = cameraForward(in: arView) ?? SIMD3<Float>(0, 0, 1)

                let midpoint = recognizer.location(in: arView)
                if let hit = rayPlaneIntersection(
                    screenPoint: midpoint,
                    in: arView,
                    planePoint: activePanPlanePoint,
                    planeNormal: activePanPlaneNormal
                ) {
                    activePanPanelOffset = panelPosition - hit
                } else {
                    activePanPanelOffset = .zero
                }
            case .changed:
                guard let panel = activePanPanel else { return }
                let midpoint = recognizer.location(in: arView)
                guard let hit = rayPlaneIntersection(
                    screenPoint: midpoint,
                    in: arView,
                    planePoint: activePanPlanePoint,
                    planeNormal: activePanPlaneNormal
                ) else {
                    return
                }
                panel.setPosition(hit + activePanPanelOffset, relativeTo: nil)
            default:
                activePanPanel = nil
                activePanPlanePoint = .zero
                activePanPlaneNormal = SIMD3<Float>(0, 0, 1)
                activePanPanelOffset = .zero
            }
        }

        private func cameraForward(in arView: ARView) -> SIMD3<Float>? {
            guard let transform = arView.session.currentFrame?.camera.transform else { return nil }
            let forward = SIMD3<Float>(
                -transform.columns.2.x,
                -transform.columns.2.y,
                -transform.columns.2.z
            )
            let len = simd_length(forward)
            guard len > 0.0001 else { return nil }
            return forward / len
        }

        private func rayPlaneIntersection(
            screenPoint: CGPoint,
            in arView: ARView,
            planePoint: SIMD3<Float>,
            planeNormal: SIMD3<Float>
        ) -> SIMD3<Float>? {
            guard let ray = arView.ray(through: screenPoint) else { return nil }
            let denom = simd_dot(ray.direction, planeNormal)
            guard abs(denom) > 0.0001 else { return nil }
            let t = simd_dot(planePoint - ray.origin, planeNormal) / denom
            guard t > 0 else { return nil }
            return ray.origin + (ray.direction * t)
        }

        private func panelForPinchStart(_ recognizer: UIPinchGestureRecognizer, in arView: ARView) -> Entity? {
            let midpoint = recognizer.location(in: arView)
            let firstTouch = recognizer.location(ofTouch: 0, in: arView)
            let secondTouch = recognizer.location(ofTouch: 1, in: arView)
            let candidates = [firstTouch, secondTouch, midpoint]

            for point in candidates {
                if let touched = arView.entity(at: point),
                   let panel = panelAncestor(from: touched) {
                    return panel
                }
            }
            return nil
        }

        private func panelForPanStart(_ recognizer: UIPanGestureRecognizer, in arView: ARView) -> Entity? {
            let midpoint = recognizer.location(in: arView)
            let firstTouch = recognizer.location(ofTouch: 0, in: arView)
            let secondTouch = recognizer.location(ofTouch: 1, in: arView)
            let candidates = [firstTouch, secondTouch, midpoint]

            for point in candidates {
                if let touched = arView.entity(at: point),
                   let panel = panelAncestor(from: touched) {
                    return panel
                }
            }
            return nil
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)
            DispatchQueue.main.async {
                self.hasTappedForDetection?.wrappedValue = true
            }

            if let tappedEntity = arView.entity(at: location),
               let multaButton = multaButtonAncestor(from: tappedEntity),
               let plateForFine = multaButtonPlates[multaButton.name] {
                disableMultaButton(multaButton)
                markMulta(for: plateForFine)
                return
            }

            let position = placementPosition(for: location, in: arView)

            saveSnapshot(from: arView) { [weak self] image in
                guard let self else { return }
                self.sendSnapshotToDetectEndpoint(image: image) { data, _ in
                    DispatchQueue.main.async {
                        guard let data,
                              self.isCarFound(in: data),
                              let parsed = self.parseVehicleScan(
                                from: data,
                                detectedStreet: self.userProfileStore?.currentStreet
                                    ?? self.userProfileStore?.serviceStreet
                                    ?? "Via non disponibile"
                              ) else {
                            return
                        }

                        self.updateLastSeen(for: parsed.plate)
                        let display = self.makePanelDisplay(from: data, scan: parsed)
                        let anchor = AnchorEntity(world: position)
                        let panel = self.makeInfoPanel(display: display, plate: parsed.plate)
                        panel.position = [0, 0.06, 0]
                        self.orientPanelTowardCamera(panel, anchorPosition: position)
                        anchor.addChild(panel)
                        arView.scene.addAnchor(anchor)

                        self.vehicleStore?.add(parsed)
                        self.sceneStore?.overlays.append(
                            ARGeneratedOverlay(id: UUID(), anchor: anchor, vehicleScanID: parsed.id)
                        )
                    }
                }
            }
        }

        private func placementPosition(for location: CGPoint, in arView: ARView) -> SIMD3<Float> {
            if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
                let transform = result.worldTransform
                return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            }

            guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                return SIMD3<Float>(0, 0, -0.6)
            }
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            let forward = cameraForward(in: arView) ?? SIMD3<Float>(0, 0, -1)
            return cameraPosition + (forward * 0.7)
        }

        func deleteLastGeneratedRectangle() {
            guard let lastOverlay = sceneStore?.overlays.popLast() else { return }
            lastOverlay.anchor.removeFromParent()
            if let scanID = lastOverlay.vehicleScanID {
                vehicleStore?.remove(scanID: scanID)
            }
        }

        private func makeInfoPanel(display: PanelDisplay, plate: String) -> Entity {
            let root = Entity()
            root.name = "vehicle_panel_root_\(UUID().uuidString)"
            let metrics = panelMetrics(showMultaButton: display.showMultaButton)

            let panelMesh = MeshResource.generateBox(
                size: [metrics.width, metrics.height, 0.002],
                cornerRadius: min(metrics.width, metrics.height) * 0.42
            )
            let panelColor = display.isParkExpired
                ? UIColor(red: 0.60, green: 0.12, blue: 0.12, alpha: 0.98)
                : UIColor(red: 0.10, green: 0.52, blue: 0.22, alpha: 0.98)
            let panelMaterial = SimpleMaterial(color: panelColor, isMetallic: false)
            let panel = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
            panel.name = "panel_surface"
            panel.generateCollisionShapes(recursive: false)
            root.addChild(panel)

            let textContainer = Entity()
            textContainer.name = "textContainer"
            root.addChild(textContainer)

            setPanelContent(root, display: display, metrics: metrics)
            if display.showMultaButton, let multaButton = makeMultaButton(metrics: metrics, plate: plate) {
                root.addChild(multaButton)
            }
            return root
        }

        private func makeMultaButton(metrics: PanelMetrics, plate: String) -> Entity? {
            let cleanPlate = normalizePlate(plate)
            guard !cleanPlate.isEmpty, cleanPlate != "UNKNOWN" else { return nil }

            let token = UUID().uuidString
            let buttonName = "multa_button_\(token)"
            multaButtonPlates[buttonName] = cleanPlate

            let buttonRoot = Entity()
            buttonRoot.name = buttonName

            let buttonWidth = min(max(metrics.width * 0.45, 0.07), metrics.width - 0.03)
            let buttonHeight: Float = 0.018
            let buttonMesh = MeshResource.generateBox(
                size: [buttonWidth, buttonHeight, 0.003],
                cornerRadius: 0.004
            )
            let buttonMaterial = SimpleMaterial(
                color: UIColor(red: 0.86, green: 0.12, blue: 0.13, alpha: 0.96),
                isMetallic: false
            )
            let buttonEntity = ModelEntity(mesh: buttonMesh, materials: [buttonMaterial])
            buttonEntity.name = "multa_button_surface"
            buttonEntity.generateCollisionShapes(recursive: false)
            buttonRoot.addChild(buttonEntity)

            let labelMesh = MeshResource.generateText(
                "Multa",
                extrusionDepth: 0.0005,
                font: .systemFont(ofSize: 0.015, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )
            let labelEntity = ModelEntity(mesh: labelMesh, materials: [UnlitMaterial(color: .white)])
            labelEntity.name = "multa_button_label"
            let labelScale: Float = 0.33
            labelEntity.scale = [labelScale, labelScale, labelScale]
            let labelBounds = labelMesh.bounds.extents
            labelEntity.position = [
                -(labelBounds.x * labelScale) / 2,
                -(labelBounds.y * labelScale) / 2,
                0.002
            ]
            buttonRoot.addChild(labelEntity)

            buttonRoot.position = [0, metrics.buttonY, 0.004]
            return buttonRoot
        }

        private func setPanelContent(_ panel: Entity, display: PanelDisplay, metrics: PanelMetrics) {
            guard let textContainer = panel.findEntity(named: "textContainer") else { return }
            textContainer.children.forEach { $0.removeFromParent() }

            let titleMesh = MeshResource.generateText(
                display.title,
                extrusionDepth: 0.0005,
                font: .systemFont(ofSize: 0.026, weight: .bold),
                containerFrame: .zero,
                alignment: .left,
                lineBreakMode: .byClipping
            )
            let titleEntity = ModelEntity(
                mesh: titleMesh,
                materials: [UnlitMaterial(color: UIColor.white)]
            )
            let titleScale: Float = 0.40
            titleEntity.scale = [titleScale, titleScale, titleScale]
            let titleBounds = titleMesh.bounds.extents
            titleEntity.position = [-(titleBounds.x * titleScale) / 2, metrics.titleY, 0.002]
            textContainer.addChild(titleEntity)

            for (index, field) in display.fields.prefix(4).enumerated() {
                let isLeft = index % 2 == 0
                let isFirstRow = index < 2
                let y = isFirstRow ? metrics.firstRowY : metrics.secondRowY
                let text = "\(field.label): \(field.value)"

                let fieldMesh = MeshResource.generateText(
                    text,
                    extrusionDepth: 0.0005,
                    font: .systemFont(ofSize: 0.022, weight: .bold),
                    containerFrame: .zero,
                    alignment: isLeft ? .left : .right,
                    lineBreakMode: .byClipping
                )
                let fieldEntity = ModelEntity(mesh: fieldMesh, materials: [UnlitMaterial(color: field.color)])
                let fieldScale: Float = 0.35
                fieldEntity.scale = [fieldScale, fieldScale, fieldScale]
                if isLeft {
                    fieldEntity.position = [metrics.leftColumnX, y, 0.002]
                } else {
                    let bounds = fieldMesh.bounds.extents
                    let textWidth = bounds.x * fieldScale
                    fieldEntity.position = [metrics.rightColumnRightEdgeX - textWidth, y, 0.002]
                }
                textContainer.addChild(fieldEntity)
            }
        }

        private func panelMetrics(showMultaButton: Bool) -> PanelMetrics {
            let width: Float = 0.27
            let height: Float = showMultaButton ? 0.145 : 0.115
            let titleY = (height / 2) - 0.018
            let firstRowY = titleY - 0.030
            let secondRowY = firstRowY - 0.024
            let leftColumnX = -(width / 2) + 0.014
            let rightColumnRightEdgeX = (width / 2) - 0.014
            let buttonY = -(height / 2) + 0.016

            return PanelMetrics(
                width: width,
                height: height,
                titleY: titleY,
                firstRowY: firstRowY,
                secondRowY: secondRowY,
                leftColumnX: leftColumnX,
                rightColumnRightEdgeX: rightColumnRightEdgeX,
                buttonY: buttonY
            )
        }

        private func orientPanelTowardCamera(_ panel: Entity, anchorPosition: SIMD3<Float>) {
            guard let cameraTransform = arView?.session.currentFrame?.camera.transform else { return }

            let cameraWorld = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            let panelWorld = anchorPosition + panel.position
            let horizontalDirection = SIMD3<Float>(
                cameraWorld.x - panelWorld.x,
                0,
                cameraWorld.z - panelWorld.z
            )
            let length = simd_length(horizontalDirection)
            guard length > 0.0001 else { return }

            let normalized = horizontalDirection / length
            let yaw = atan2(normalized.x, normalized.z)
            panel.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        }

        private func snapshotsDirectoryURL() -> URL? {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            return documentsDirectory.appendingPathComponent(snapshotsFolderName, isDirectory: true)
        }

        func ensureSnapshotsDirectoryExists() {
            guard let snapshotsDirectory = snapshotsDirectoryURL() else { return }
            try? FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
        }

        private func saveSnapshot(from arView: ARView, completion: @escaping (UIImage) -> Void) {
            arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let image, let pngData = image.pngData() else { return }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
                let filename = "snapshot-\(formatter.string(from: Date())).png"

                let fileManager = FileManager.default
                guard let snapshotsDirectory = self?.snapshotsDirectoryURL() else { return }

                do {
                    try fileManager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
                    let fileURL = snapshotsDirectory.appendingPathComponent(filename)
                    try pngData.write(to: fileURL, options: .atomic)
                    DispatchQueue.main.async {
                        self?.lastSnapshotFilename?.wrappedValue = filename
                        self?.lastSnapshotPath?.wrappedValue = fileURL.path
                        completion(image)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.lastSnapshotFilename?.wrappedValue = "Save failed"
                        self?.lastSnapshotPath?.wrappedValue = ""
                        completion(image)
                    }
                }
            }
        }

        private func sendSnapshotToDetectEndpoint(image: UIImage, completion: @escaping (Data?, String) -> Void) {
            guard let imageData = image.jpegData(compressionQuality: 0.9),
                  let url = URL(string: "\(apiBaseURL)/detect") else {
                completion(nil, """
                {
                  "detected" : false,
                  "error" : "invalid image or URL"
                }
                """)
                return
            }

            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"targa.jpeg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
                if let urlError = error as? URLError {
                    completion(nil, """
                    {
                      "detected" : false,
                      "error" : "\(urlError.localizedDescription)",
                      "urlErrorCode" : \(urlError.errorCode)
                    }
                    """)
                    return
                }

                if let error {
                    completion(nil, """
                    {
                      "detected" : false,
                      "error" : "\(error.localizedDescription)"
                    }
                    """)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(nil, """
                    {
                      "detected" : false,
                      "error" : "HTTP \(httpResponse.statusCode)",
                      "responseBody" : "\(bodyString.replacingOccurrences(of: "\"", with: "\\\""))"
                    }
                    """)
                    return
                }

                guard let data else {
                    completion(nil, """
                    {
                      "detected" : false,
                      "error" : "empty response"
                    }
                    """)
                    return
                }

                if let pretty = self.prettyJSONString(from: data) {
                    completion(data, pretty)
                } else if let raw = String(data: data, encoding: .utf8) {
                    completion(data, raw)
                } else {
                    completion(data, """
                    {
                      "detected" : false,
                      "error" : "unreadable response"
                    }
                    """)
                }
            }.resume()
        }

        private func multaButtonAncestor(from entity: Entity) -> Entity? {
            var current: Entity? = entity
            while let node = current {
                if multaButtonPlates[node.name] != nil {
                    return node
                }
                current = node.parent
            }
            return nil
        }

        private func panelAncestor(from entity: Entity) -> Entity? {
            var current: Entity? = entity
            while let node = current {
                if node.name.hasPrefix("vehicle_panel_root_") {
                    return node
                }
                current = node.parent
            }
            return nil
        }

        private func disableMultaButton(_ buttonRoot: Entity) {
            multaButtonPlates.removeValue(forKey: buttonRoot.name)

            if let buttonSurface = buttonRoot.findEntity(named: "multa_button_surface") as? ModelEntity {
                buttonSurface.model?.materials = [
                    SimpleMaterial(
                        color: UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 0.95),
                        isMetallic: false
                    )
                ]
                buttonSurface.components.remove(CollisionComponent.self)
            }

            if let labelEntity = buttonRoot.findEntity(named: "multa_button_label") as? ModelEntity {
                let labelMesh = MeshResource.generateText(
                    "Multata",
                    extrusionDepth: 0.0005,
                    font: .systemFont(ofSize: 0.014, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byClipping
                )
                labelEntity.model = ModelComponent(mesh: labelMesh, materials: [UnlitMaterial(color: .white)])
                let labelScale: Float = 0.31
                labelEntity.scale = [labelScale, labelScale, labelScale]
                let labelBounds = labelMesh.bounds.extents
                labelEntity.position = [
                    -(labelBounds.x * labelScale) / 2,
                    -(labelBounds.y * labelScale) / 2,
                    0.002
                ]
            }
        }

        private func normalizePlate(_ value: String) -> String {
            value
                .uppercased()
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func markMulta(for plate: String) {
            patchCar(plate: plate, payload: ["Multa": true])
        }

        private func updateLastSeen(for plate: String) {
            let cleanPlate = normalizePlate(plate)
            guard !cleanPlate.isEmpty, cleanPlate != "UNKNOWN" else { return }
            patchCar(plate: cleanPlate, payload: ["last_seen": iso8601NowUTCString()])
        }

        private func patchCar(plate: String, payload: [String: Any]) {
            let cleanPlate = normalizePlate(plate)
            guard !cleanPlate.isEmpty,
                  let encodedPlate = cleanPlate.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "\(apiBaseURL)/cars/\(encodedPlate)"),
                  JSONSerialization.isValidJSONObject(payload),
                  let body = try? JSONSerialization.data(withJSONObject: payload) else {
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
        }

        private func iso8601NowUTCString() -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter.string(from: Date())
        }

        private func parseVehicleScan(from data: Data, detectedStreet: String) -> VehicleScan? {
            guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
            let flatMap = flattenJSON(root)

            let plateKeys = ["plate", "license_plate", "plate_number", "number_plate", "licenseplate"]
            let plate = findPlate(in: flatMap, keys: plateKeys) ?? "Unknown"
            let parkValue = findFirstValue(in: flatMap, matchingAny: [
                "park_expiration", "parking_expiration", "parking_expiry", "park_expiry"
            ]) ?? "-"
            let insuranceValue = findFirstValue(in: flatMap, matchingAny: [
                "insurance_expiration", "insurance_expiry"
            ]) ?? "-"
            let revisionValue = findFirstValue(in: flatMap, matchingAny: [
                "last_revision", "revision_expiration", "revision_expiry"
            ]) ?? "-"
            let multaRaw = findFirstValue(in: flatMap, matchingAny: ["multa"])
            let multaState = multaRaw.flatMap(boolFromString)

            let details = [
                VehicleDetail(key: "Park Expiration", value: formatDisplayDate(parkValue)),
                VehicleDetail(key: "Insurance Expiration", value: formatDisplayDate(insuranceValue)),
                VehicleDetail(key: "Last Revision", value: formatDisplayDate(revisionValue)),
                VehicleDetail(key: "Multa", value: multaState == nil ? "-" : (multaState == true ? "SI" : "NO")),
            ]

            return VehicleScan(
                id: UUID(),
                plate: plate,
                capturedAt: Date(),
                capturedStreet: detectedStreet,
                details: details
            )
        }

        private func flattenJSON(_ any: Any, prefix: String = "") -> [String: String] {
            var output: [String: String] = [:]

            if let dict = any as? [String: Any] {
                for (key, value) in dict {
                    let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                    let nested = flattenJSON(value, prefix: fullKey)
                    for (nestedKey, nestedValue) in nested {
                        output[nestedKey] = nestedValue
                    }
                }
                return output
            }

            if let array = any as? [Any] {
                for (index, value) in array.enumerated() {
                    let fullKey = "\(prefix)[\(index)]"
                    let nested = flattenJSON(value, prefix: fullKey)
                    for (nestedKey, nestedValue) in nested {
                        output[nestedKey] = nestedValue
                    }
                }
                return output
            }

            let finalKey = prefix.isEmpty ? "value" : prefix
            if let value = any as? String {
                output[finalKey] = value
            } else if let number = any as? NSNumber {
                output[finalKey] = number.stringValue
            } else if let boolValue = any as? Bool {
                output[finalKey] = boolValue ? "true" : "false"
            } else {
                output[finalKey] = "\(any)"
            }

            return output
        }

        private func findPlate(in flatMap: [String: String], keys: [String]) -> String? {
            for (key, value) in flatMap {
                let lower = key.lowercased()
                if keys.contains(where: { lower.contains($0) }) && !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        private func prettifyKey(_ key: String) -> String {
            let simple = key
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: ".", with: " ")
            return simple.prefix(1).uppercased() + simple.dropFirst()
        }

        private func makePanelDisplay(from data: Data, scan: VehicleScan) -> PanelDisplay {
            let root = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
            let flatMap = flattenJSON(root)

            let parkValue = findFirstValue(in: flatMap, matchingAny: [
                "park_expiration", "parking_expiration", "parking_expiry", "park_expiry"
            ]) ?? "-"
            let insuranceValue = findFirstValue(in: flatMap, matchingAny: [
                "insurance_expiration", "insurance_expiry"
            ]) ?? "-"
            let revisionValue = findFirstValue(in: flatMap, matchingAny: [
                "last_revision", "revision_expiration", "revision_expiry"
            ]) ?? "-"
            let modelValue = findFirstValue(in: flatMap, matchingAny: [
                "model", "vehicle_model", "vehicle_type", "make"
            ]) ?? (scan.details.first?.value ?? "-")

            let parkExpired = isExpiredDateString(parkValue)
            let insuranceExpired = isExpiredDateString(insuranceValue)
            let revisionExpired = isExpiredDateString(revisionValue)
            let multaRaw = findFirstValue(in: flatMap, matchingAny: ["multa"])
            let multaState = multaRaw.flatMap(boolFromString)
            let hasAlert = (parkExpired == true) || (insuranceExpired == true) || (revisionExpired == true) || (multaState == true)

            let textColor = UIColor(red: 0.96, green: 0.98, blue: 0.97, alpha: 1.0)

            let fields: [PanelField] = [
                PanelField(
                    icon: "P",
                    label: "Parcheggio",
                    value: trimValue(formatDisplayDate(parkValue), max: 18),
                    color: textColor
                ),
                PanelField(
                    icon: "A",
                    label: "Assic.",
                    value: trimValue(formatDisplayDate(insuranceValue), max: 18),
                    color: textColor
                ),
                PanelField(
                    icon: "R",
                    label: "Revis.",
                    value: trimValue(formatDisplayDate(revisionValue), max: 18),
                    color: textColor
                ),
                PanelField(
                    icon: "!",
                    label: "Multa",
                    value: multaState == nil ? "-" : (multaState == true ? "SI" : "NO"),
                    color: textColor
                ),
            ]

            return PanelDisplay(
                title: "\(trimValue(scan.plate, max: 10)) • \(trimValue(modelValue, max: 12))",
                fields: fields,
                isParkExpired: hasAlert,
                showMultaButton: (parkExpired == true) && (multaState == false)
            )
        }

        private func isCarFound(in data: Data) -> Bool {
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            if let found = root["car_found"] as? Bool {
                return found
            }
            if let foundString = root["car_found"] as? String {
                return foundString.lowercased() == "true"
            }
            if let foundNumber = root["car_found"] as? NSNumber {
                return foundNumber.boolValue
            }
            return false
        }

        private func findFirstValue(in flatMap: [String: String], matchingAny tokens: [String]) -> String? {
            for (key, value) in flatMap {
                let lower = key.lowercased()
                if tokens.contains(where: { lower.contains($0) }) &&
                    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
            }
            return nil
        }

        private func isExpiredDateString(_ raw: String) -> Bool? {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != "-" else { return nil }
            guard let date = parseFlexibleDate(value) else { return nil }

            let startOfToday = Calendar.current.startOfDay(for: Date())
            return date < startOfToday
        }

        private func parseFlexibleDate(_ raw: String) -> Date? {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let isoDate = iso.date(from: raw) {
                return isoDate
            }
            iso.formatOptions = [.withInternetDateTime]
            if let isoDate = iso.date(from: raw) {
                return isoDate
            }

            let formats = [
                "yyyy-MM-dd",
                "yyyy/MM/dd",
                "dd/MM/yyyy",
                "dd-MM-yyyy",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy/MM/dd HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss",
            ]

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current

            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: raw) {
                    return date
                }
            }

            return nil
        }

        private func formatDisplayDate(_ raw: String) -> String {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != "-", let date = parseFlexibleDate(value) else {
                return value.isEmpty ? "-" : value
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = value.contains("T") || value.contains(":") ? "dd/MM/yyyy HH:mm" : "dd/MM/yyyy"
            return formatter.string(from: date)
        }

        private func boolFromString(_ raw: String) -> Bool? {
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y", "si":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        }

        private func trimValue(_ value: String, max: Int) -> String {
            if value.count <= max { return value }
            return String(value.prefix(max - 1)) + "…"
        }

        private func prettyJSONString(from data: Data) -> String? {
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  JSONSerialization.isValidJSONObject(object),
                  let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                  let prettyString = String(data: prettyData, encoding: .utf8) else {
                return nil
            }
            return prettyString
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ARTrackingView()
            .environmentObject(VehicleStore())
            .environmentObject(ARTrackingSceneStore())
            .environmentObject(UserProfileStore())
    }
}
