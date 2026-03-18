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

    var body: some View {
        ZStack {
            ARViewContainer(
                lastSnapshotFilename: $lastSnapshotFilename,
                lastSnapshotPath: $lastSnapshotPath,
                deleteRequestCounter: $deleteRequestCounter,
                vehicleStore: vehicleStore,
                sceneStore: sceneStore
            )
                .ignoresSafeArea()

            VStack {
                Text("👋🏻 Hello, \(userProfileStore.greetingName)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                HStack {
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
                .padding([.top, .horizontal])

                Spacer()
            }
        }
        .navigationTitle("Rilevazione Auto")
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
    @ObservedObject var vehicleStore: VehicleStore
    @ObservedObject var sceneStore: ARTrackingSceneStore

    func makeUIView(context: Context) -> ARView {
        let arView = sceneStore.arView
        context.coordinator.arView = arView
        context.coordinator.lastSnapshotFilename = $lastSnapshotFilename
        context.coordinator.lastSnapshotPath = $lastSnapshotPath
        context.coordinator.vehicleStore = vehicleStore
        context.coordinator.sceneStore = sceneStore

        if !sceneStore.isSessionConfigured {
            context.coordinator.configureSession()
            sceneStore.isSessionConfigured = true
        }

        if !sceneStore.isTapGestureInstalled {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            arView.addGestureRecognizer(tap)
            sceneStore.isTapGestureInstalled = true
        }
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
        private struct PanelLine {
            let text: String
            let color: UIColor
            let isTitle: Bool
            let iconGlyph: String?
            let iconColor: UIColor?
        }

        private struct PanelDisplay {
            let lines: [PanelLine]
            let isParkExpired: Bool
        }

        private struct PanelMetrics {
            let width: Float
            let height: Float
            let borderWidth: Float
            let borderHeight: Float
            let leftMargin: Float
            let textMargin: Float
            let topStart: Float
            let lineHeight: Float
        }

        weak var arView: ARView?
        var lastSnapshotFilename: Binding<String>?
        var lastSnapshotPath: Binding<String>?
        weak var vehicleStore: VehicleStore?
        weak var sceneStore: ARTrackingSceneStore?
        var lastHandledDeleteRequest: Int = 0
        private let apiBaseURL = "http://192.168.1.60:8000"
        private var multaButtonPlates: [String: String] = [:]

        func configureSession() {
            guard let arView else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            arView.automaticallyConfigureSession = false
            arView.renderOptions.insert(.disableMotionBlur)
            arView.session.run(configuration)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)

            if let tappedEntity = arView.entity(at: location),
               let multaButton = multaButtonAncestor(from: tappedEntity),
               let plateForFine = multaButtonPlates[multaButton.name] {
                disableMultaButton(multaButton)
                markMulta(for: plateForFine)
                return
            }

            guard let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first else {
                return
            }

            let transform = result.worldTransform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            saveSnapshot(from: arView) { [weak self] image in
                guard let self else { return }
                self.sendSnapshotToDetectEndpoint(image: image) { data, _ in
                    DispatchQueue.main.async {
                        guard let data,
                              self.isCarFound(in: data),
                              let parsed = self.parseVehicleScan(from: data) else {
                            return
                        }

                        self.updateLastSeen(for: parsed.plate)
                        let display = self.makePanelDisplay(from: data, scan: parsed)
                        let anchor = AnchorEntity(world: position)
                        let panel = self.makeInfoPanel(
                            lines: display.lines,
                            isParkExpired: display.isParkExpired,
                            plate: parsed.plate
                        )
                        panel.position = [0, 0.06, 0]
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

        func deleteLastGeneratedRectangle() {
            guard let lastOverlay = sceneStore?.overlays.popLast() else { return }
            lastOverlay.anchor.removeFromParent()
            if let scanID = lastOverlay.vehicleScanID {
                vehicleStore?.remove(scanID: scanID)
            }
        }

        private func makeInfoPanel(lines: [PanelLine], isParkExpired: Bool, plate: String) -> Entity {
            let root = Entity()
            let metrics = panelMetrics(for: lines)

            let shadowMesh = MeshResource.generateBox(
                size: [metrics.borderWidth + 0.01, metrics.borderHeight + 0.01, 0.001],
                cornerRadius: min(metrics.borderWidth, metrics.borderHeight) * 0.28
            )
            let shadowMaterial = SimpleMaterial(color: UIColor(white: 0, alpha: 0.35), isMetallic: false)
            let shadow = ModelEntity(mesh: shadowMesh, materials: [shadowMaterial])
            shadow.position = [0.003, -0.003, -0.001]
            root.addChild(shadow)

            let borderMesh = MeshResource.generateBox(
                size: [metrics.borderWidth, metrics.borderHeight, 0.0015],
                cornerRadius: min(metrics.borderWidth, metrics.borderHeight) * 0.25
            )
            let borderColor = isParkExpired
                ? UIColor(red: 1.0, green: 0.65, blue: 0.65, alpha: 0.95)
                : UIColor(red: 0.74, green: 1.0, blue: 0.79, alpha: 0.95)
            let border = ModelEntity(mesh: borderMesh, materials: [SimpleMaterial(color: borderColor, isMetallic: false)])
            border.position = [0, 0, 0.001]
            root.addChild(border)

            let panelMesh = MeshResource.generateBox(
                size: [metrics.width, metrics.height, 0.002],
                cornerRadius: min(metrics.width, metrics.height) * 0.24
            )
            let panelColor = isParkExpired
                ? UIColor(red: 0.50, green: 0.12, blue: 0.12, alpha: 0.96)
                : UIColor(red: 0.08, green: 0.33, blue: 0.18, alpha: 0.96)
            let panelMaterial = SimpleMaterial(color: panelColor, isMetallic: false)
            let panel = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
            root.addChild(panel)

            let textContainer = Entity()
            textContainer.name = "textContainer"
            root.addChild(textContainer)

            setPanelLines(root, lines: lines, metrics: metrics)
            if let multaButton = makeMultaButton(metrics: metrics, plate: plate) {
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
                "MULTA",
                extrusionDepth: 0.0005,
                font: .systemFont(ofSize: 0.015, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )
            let labelEntity = ModelEntity(mesh: labelMesh, materials: [UnlitMaterial(color: .white)])
            labelEntity.name = "multa_button_label"
            labelEntity.scale = [0.35, 0.35, 0.35]
            labelEntity.position = [-0.013, -0.003, 0.002]
            buttonRoot.addChild(labelEntity)

            buttonRoot.position = [0, -(metrics.height / 2) + 0.014, 0.004]
            return buttonRoot
        }

        private func setPanelLines(_ panel: Entity, lines: [PanelLine], metrics: PanelMetrics) {
            guard let textContainer = panel.findEntity(named: "textContainer") else { return }
            textContainer.children.forEach { $0.removeFromParent() }

            for line in lines.enumerated() {
                let yPosition = metrics.topStart - (Float(line.offset) * metrics.lineHeight)
                let hasIcon = line.element.iconGlyph != nil
                let textX = hasIcon ? metrics.textMargin : 0

                if let icon = line.element.iconGlyph, let iconColor = line.element.iconColor {
                    let iconMesh = MeshResource.generateText(
                        icon,
                        extrusionDepth: 0.0005,
                        font: .systemFont(ofSize: 0.018, weight: .bold),
                        containerFrame: .zero,
                        alignment: .left,
                        lineBreakMode: .byClipping
                    )
                    let iconEntity = ModelEntity(mesh: iconMesh, materials: [UnlitMaterial(color: iconColor)])
                    iconEntity.scale = [0.33, 0.33, 0.33]
                    iconEntity.position = [metrics.leftMargin, yPosition, 0.002]
                    textContainer.addChild(iconEntity)
                }

                let lineMesh = MeshResource.generateText(
                    line.element.text,
                    extrusionDepth: 0.0005,
                    font: .systemFont(
                        ofSize: line.element.isTitle ? 0.022 : 0.0185,
                        weight: line.element.isTitle ? .semibold : .regular
                    ),
                    containerFrame: .zero,
                    alignment: .left,
                    lineBreakMode: .byClipping
                )
                let lineEntity = ModelEntity(mesh: lineMesh, materials: [UnlitMaterial(color: line.element.color)])
                lineEntity.scale = [0.33, 0.33, 0.33]
                lineEntity.position = [textX, yPosition, 0.002]
                textContainer.addChild(lineEntity)
            }
        }

        private func panelMetrics(for lines: [PanelLine]) -> PanelMetrics {
            let maxChars = max(lines.map { $0.text.count }.max() ?? 22, 16)
            let lineCount = max(lines.count, 1)

            // Character-based sizing tuned for RealityKit text scale used below.
            let estimatedWidth = Float(maxChars) * 0.0046 + 0.054
            let width = min(max(estimatedWidth, 0.155), 0.21)

            let estimatedHeight = Float(lineCount) * 0.018 + 0.032
            let height = min(max(estimatedHeight, 0.085), 0.145)

            let borderWidth = width + 0.006
            let borderHeight = height + 0.006
            let leftMargin = -(width / 2) + 0.011
            let textMargin = leftMargin + 0.016
            let topStart = (height / 2) - 0.016

            return PanelMetrics(
                width: width,
                height: height,
                borderWidth: borderWidth,
                borderHeight: borderHeight,
                leftMargin: leftMargin,
                textMargin: textMargin,
                topStart: topStart,
                lineHeight: 0.018
            )
        }

        private func saveSnapshot(from arView: ARView, completion: @escaping (UIImage) -> Void) {
            arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let image, let pngData = image.pngData() else { return }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
                let filename = "snapshot-\(formatter.string(from: Date())).png"

                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return
                }
                let snapshotsDirectory = documentsDirectory.appendingPathComponent("ARSnapshots", isDirectory: true)

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
                    "MULTATA",
                    extrusionDepth: 0.0005,
                    font: .systemFont(ofSize: 0.014, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byClipping
                )
                labelEntity.model = ModelComponent(mesh: labelMesh, materials: [UnlitMaterial(color: .white)])
                labelEntity.scale = [0.32, 0.32, 0.32]
                labelEntity.position = [-0.016, -0.003, 0.002]
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

        private func parseVehicleScan(from data: Data) -> VehicleScan? {
            guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
            let flatMap = flattenJSON(root)

            let plateKeys = ["plate", "license_plate", "plate_number", "number_plate", "licenseplate"]
            let plate = findPlate(in: flatMap, keys: plateKeys) ?? "Unknown"

            let details = flatMap
                .filter { key, value in
                    let lowKey = key.lowercased()
                    let isPlateField = plateKeys.contains { lowKey.contains($0) }
                    return !isPlateField && !value.isEmpty
                }
                .sorted { $0.key < $1.key }
                .prefix(4)
                .map { VehicleDetail(key: prettifyKey($0.key), value: $0.value) }

            return VehicleScan(
                id: UUID(),
                plate: plate,
                capturedAt: Date(),
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

            let neutral = UIColor(red: 0.95, green: 0.98, blue: 0.96, alpha: 1.0)
            let okay = UIColor(red: 0.60, green: 0.97, blue: 0.66, alpha: 1.0)
            let alert = UIColor(red: 1.0, green: 0.44, blue: 0.44, alpha: 1.0)
            let iconNeutral = UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)

            let lines: [PanelLine] = [
                PanelLine(
                    text: "\(trimValue(scan.plate, max: 10)) • \(trimValue(modelValue, max: 12))",
                    color: neutral,
                    isTitle: true,
                    iconGlyph: "CAR",
                    iconColor: iconNeutral
                ),
                PanelLine(
                    text: "Park \(trimValue(parkValue, max: 14))",
                    color: parkExpired == nil ? neutral : (parkExpired == true ? alert : okay),
                    isTitle: false,
                    iconGlyph: "P",
                    iconColor: parkExpired == nil ? iconNeutral : (parkExpired == true ? alert : okay)
                ),
                PanelLine(
                    text: "Insurance \(trimValue(insuranceValue, max: 14))",
                    color: insuranceExpired == nil ? neutral : (insuranceExpired == true ? alert : okay),
                    isTitle: false,
                    iconGlyph: "I",
                    iconColor: insuranceExpired == nil ? iconNeutral : (insuranceExpired == true ? alert : okay)
                ),
                PanelLine(
                    text: "Revision \(trimValue(revisionValue, max: 14))",
                    color: revisionExpired == nil ? neutral : (revisionExpired == true ? alert : okay),
                    isTitle: false,
                    iconGlyph: "R",
                    iconColor: revisionExpired == nil ? iconNeutral : (revisionExpired == true ? alert : okay)
                ),
            ]

            return PanelDisplay(lines: lines, isParkExpired: parkExpired ?? false)
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
