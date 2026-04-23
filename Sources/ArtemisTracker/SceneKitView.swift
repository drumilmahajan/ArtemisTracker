import SwiftUI
import SceneKit

struct TrajectorySceneView: NSViewRepresentable {
    @ObservedObject var viewModel: ArtemisViewModel
    var resetTrigger: Int = 0

    private var mission: TrackableMission {
        viewModel.watchedMission ?? .artemisII
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.pointOfView = context.coordinator.cameraNode

        let controller = scnView.defaultCameraController
        controller.interactionMode = .pan
        controller.inertiaEnabled = true

        context.coordinator.scnView = scnView
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        let coord = context.coordinator
        let scale = mission.scaleFactor

        // Reconfigure scene if mission changed
        if coord.currentMissionId != mission.id {
            coord.reconfigure(for: mission)
        }

        if let data = viewModel.latestData {
            coord.updatePositions(data: data, scale: scale, mission: mission)
        }

        // Update Sun lighting direction
        if let sun = viewModel.sunPosition {
            coord.updateSunLight(sunPos: sun, scale: scale, mission: mission)
        }

        // Update Earth rotation to real GMST
        if mission.centerBody == .earth {
            coord.updateEarthRotation()
        }

        if !coord.hasDrawnTrajectory && !viewModel.plannedTrajectory.isEmpty {
            coord.drawPlannedTrajectory(viewModel.plannedTrajectory, scale: scale)
        }
        if !coord.hasDrawnMoonOrbit && !viewModel.moonOrbit.isEmpty && mission.showMoon {
            coord.drawMoonOrbit(viewModel.moonOrbit, scale: scale)
        }

        if resetTrigger != coord.lastResetTrigger {
            coord.lastResetTrigger = resetTrigger
            coord.resetCamera()
        }
    }

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator(mission: mission)
    }

    class SceneCoordinator {
        let scene: SCNScene
        let centerBodyNode: SCNNode
        var moonNode: SCNNode
        let craftNode: SCNNode
        let cameraNode: SCNNode
        let sunLightNode: SCNNode

        var hasDrawnTrajectory = false
        var hasDrawnMoonOrbit = false
        var lastResetTrigger = 0
        weak var scnView: SCNView?
        var currentMissionId: String

        private var hasInitializedCamera = false
        private var lastSecondaryPos = SCNVector3Zero
        private var lastCraftPos = SCNVector3Zero

        init(mission: TrackableMission) {
            currentMissionId = mission.id
            scene = SCNScene()
            scene.background.contents = NSColor.black

            // Star field
            let starsNode = SCNNode()
            let starGeo = SCNSphere(radius: 300)
            let starMat = SCNMaterial()
            starMat.diffuse.contents = NSColor.black
            starMat.isDoubleSided = true
            starMat.emission.contents = Self.generateStarField(size: 2048)
            starGeo.firstMaterial = starMat
            starsNode.geometry = starGeo
            scene.rootNode.addChildNode(starsNode)

            // Center body (Earth or Sun)
            centerBodyNode = Self.makeCenterBody(for: mission)
            scene.rootNode.addChildNode(centerBodyNode)

            // Moon (only for lunar transit)
            moonNode = Self.makeMoon()
            moonNode.isHidden = !mission.showMoon
            scene.rootNode.addChildNode(moonNode)

            // Spacecraft
            craftNode = Self.buildSpacecraft()
            scene.rootNode.addChildNode(craftNode)

            let craftLabel = Self.makeLabel(mission.spacecraft, size: 0.7)
            craftLabel.name = "craftLabel"
            craftLabel.position = SCNVector3(0, 1.8, 0)
            craftNode.addChildNode(craftLabel)

            // Craft point light
            let craftLight = SCNLight()
            craftLight.type = .omni
            craftLight.color = NSColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
            craftLight.intensity = 600
            craftLight.attenuationStartDistance = 0
            craftLight.attenuationEndDistance = 25
            let lightNode = SCNNode()
            lightNode.light = craftLight
            craftNode.addChildNode(lightNode)

            // Lighting
            sunLightNode = SCNNode()
            sunLightNode.light = SCNLight()
            sunLightNode.light?.type = .directional
            sunLightNode.light?.color = NSColor.white
            sunLightNode.light?.intensity = 1000
            sunLightNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
            scene.rootNode.addChildNode(sunLightNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = NSColor(white: 0.25, alpha: 1.0)
            ambient.light?.intensity = 500
            scene.rootNode.addChildNode(ambient)

            // Camera
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 800
            cameraNode.camera?.fieldOfView = 55
            cameraNode.position = SCNVector3(0, 40, 60)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)
        }

        // MARK: - Reconfigure for different mission

        func reconfigure(for mission: TrackableMission) {
            currentMissionId = mission.id
            hasDrawnTrajectory = false
            hasDrawnMoonOrbit = false
            hasInitializedCamera = false

            // Remove old trajectory/orbit lines
            scene.rootNode.childNode(withName: "plannedTrajectory", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "moonOrbit", recursively: false)?.removeFromParentNode()

            // Update center body
            centerBodyNode.childNodes.forEach { $0.removeFromParentNode() }
            let newCenter = Self.makeCenterBody(for: mission)
            centerBodyNode.geometry = newCenter.geometry
            for child in newCenter.childNodes {
                centerBodyNode.addChildNode(child)
            }
            centerBodyNode.removeAllActions()
            centerBodyNode.eulerAngles = SCNVector3Zero
            if mission.centerBody == .earth {
                let obliquity = CGFloat(23.4 * .pi / 180.0)
                centerBodyNode.eulerAngles.z = obliquity
            }

            // Show/hide moon
            moonNode.isHidden = !mission.showMoon

            // Update spacecraft label
            craftNode.childNode(withName: "craftLabel", recursively: false)?.removeFromParentNode()
            let craftLabel = Self.makeLabel(mission.spacecraft, size: 0.7)
            craftLabel.name = "craftLabel"
            craftLabel.position = SCNVector3(0, 1.8, 0)
            craftNode.addChildNode(craftLabel)
        }

        // MARK: - Center Body Factory

        static func makeCenterBody(for mission: TrackableMission) -> SCNNode {
            let radius: CGFloat = 2.0
            let node: SCNNode

            if mission.centerBody == .sun {
                let geo = SCNSphere(radius: radius)
                geo.segmentCount = 48
                let mat = SCNMaterial()
                if let texturePath = Bundle.main.path(forResource: "sun_texture", ofType: "jpg"),
                   let image = NSImage(contentsOfFile: texturePath) {
                    mat.diffuse.contents = image
                    mat.emission.contents = image
                    mat.emission.intensity = 0.3
                } else {
                    mat.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
                    mat.emission.contents = NSColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 1.0)
                }
                geo.firstMaterial = mat
                node = SCNNode(geometry: geo)

                let glowGeo = SCNSphere(radius: radius * 1.3)
                let glowMat = SCNMaterial()
                glowMat.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.08)
                glowMat.emission.contents = NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.05)
                glowMat.isDoubleSided = true
                glowGeo.firstMaterial = glowMat
                node.addChildNode(SCNNode(geometry: glowGeo))

                let label = makeLabel("Sun", size: 1.0)
                label.position = SCNVector3(0, Float(radius) + 1.2, 0)
                node.addChildNode(label)
            } else {
                let geo = SCNSphere(radius: radius)
                geo.segmentCount = 64
                let mat = SCNMaterial()
                if let texturePath = Bundle.main.path(forResource: "earth_daymap", ofType: "jpg"),
                   let image = NSImage(contentsOfFile: texturePath) {
                    mat.diffuse.contents = image
                    mat.specular.contents = NSColor(white: 0.4, alpha: 1.0)
                    mat.emission.contents = NSColor(red: 0.02, green: 0.05, blue: 0.15, alpha: 1.0)
                } else {
                    mat.diffuse.contents = NSColor(red: 0.1, green: 0.35, blue: 0.8, alpha: 1.0)
                    mat.emission.contents = NSColor(red: 0.03, green: 0.1, blue: 0.25, alpha: 1.0)
                    mat.specular.contents = NSColor(white: 0.3, alpha: 1.0)
                }
                geo.firstMaterial = mat
                node = SCNNode(geometry: geo)

                // Atmosphere glow
                let glowGeo = SCNSphere(radius: radius * 1.05)
                let glowMat = SCNMaterial()
                glowMat.diffuse.contents = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.08)
                glowMat.isDoubleSided = true
                glowGeo.firstMaterial = glowMat
                node.addChildNode(SCNNode(geometry: glowGeo))

                let label = makeLabel("Earth", size: 1.0)
                label.position = SCNVector3(0, Float(radius) + 1.2, 0)
                node.addChildNode(label)
            }

            node.position = SCNVector3(0, 0, 0)
            // Earth gets 23.4° axial tilt; Sun stays upright
            if mission.centerBody == .earth {
                let obliquity = CGFloat(23.4 * .pi / 180.0)
                node.eulerAngles.z = obliquity
            }
            return node
        }

        static func makeMoon() -> SCNNode {
            let radius: CGFloat = 0.8
            let geo = SCNSphere(radius: radius)
            geo.segmentCount = 36
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(white: 0.65, alpha: 1.0)
            mat.emission.contents = NSColor(white: 0.1, alpha: 1.0)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)

            let label = makeLabel("Moon", size: 0.8)
            label.position = SCNVector3(0, Float(radius) + 0.8, 0)
            node.addChildNode(label)
            return node
        }

        // MARK: - Spacecraft Model

        static func buildSpacecraft() -> SCNNode {
            let ship = SCNNode()

            let capsuleGeo = SCNCapsule(capRadius: 0.25, height: 0.8)
            let capsuleMat = SCNMaterial()
            capsuleMat.diffuse.contents = NSColor(white: 0.9, alpha: 1.0)
            capsuleMat.emission.contents = NSColor(white: 0.3, alpha: 1.0)
            capsuleMat.metalness.contents = NSColor(white: 0.6, alpha: 1.0)
            capsuleGeo.firstMaterial = capsuleMat
            let capsuleNode = SCNNode(geometry: capsuleGeo)
            ship.addChildNode(capsuleNode)

            let serviceGeo = SCNCylinder(radius: 0.22, height: 0.6)
            let serviceMat = SCNMaterial()
            serviceMat.diffuse.contents = NSColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
            serviceMat.metalness.contents = NSColor(white: 0.7, alpha: 1.0)
            serviceGeo.firstMaterial = serviceMat
            let serviceNode = SCNNode(geometry: serviceGeo)
            serviceNode.position = SCNVector3(0, -0.7, 0)
            ship.addChildNode(serviceNode)

            let panelGeo = SCNBox(width: 2.0, height: 0.02, length: 0.4, chamferRadius: 0)
            let panelMat = SCNMaterial()
            panelMat.diffuse.contents = NSColor(red: 0.1, green: 0.15, blue: 0.4, alpha: 1.0)
            panelMat.emission.contents = NSColor(red: 0.05, green: 0.08, blue: 0.2, alpha: 1.0)
            panelMat.metalness.contents = NSColor(white: 0.8, alpha: 1.0)
            panelGeo.firstMaterial = panelMat

            let leftPanel = SCNNode(geometry: panelGeo)
            leftPanel.position = SCNVector3(-1.2, -0.6, 0)
            ship.addChildNode(leftPanel)

            let rightPanel = SCNNode(geometry: panelGeo)
            rightPanel.position = SCNVector3(1.2, -0.6, 0)
            ship.addChildNode(rightPanel)

            let strutGeo = SCNCylinder(radius: 0.02, height: 0.4)
            let strutMat = SCNMaterial()
            strutMat.diffuse.contents = NSColor(white: 0.5, alpha: 1.0)
            strutGeo.firstMaterial = strutMat

            for xSign: Float in [-1.0, 1.0] {
                let strut = SCNNode(geometry: strutGeo)
                strut.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
                strut.position = SCNVector3(xSign * 0.4, -0.6, 0)
                ship.addChildNode(strut)
            }

            let nozzleGeo = SCNCone(topRadius: 0.15, bottomRadius: 0.3, height: 0.3)
            let nozzleMat = SCNMaterial()
            nozzleMat.diffuse.contents = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)
            nozzleMat.metalness.contents = NSColor(white: 0.9, alpha: 1.0)
            nozzleGeo.firstMaterial = nozzleMat
            let nozzleNode = SCNNode(geometry: nozzleGeo)
            nozzleNode.position = SCNVector3(0, -1.15, 0)
            ship.addChildNode(nozzleNode)

            let engineGlow = SCNSphere(radius: 0.15)
            let engineMat = SCNMaterial()
            engineMat.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.6)
            engineMat.emission.contents = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
            engineGlow.firstMaterial = engineMat
            let engineGlowNode = SCNNode(geometry: engineGlow)
            engineGlowNode.position = SCNVector3(0, -1.3, 0)
            ship.addChildNode(engineGlowNode)

            let haloGeo = SCNSphere(radius: 1.5)
            let haloMat = SCNMaterial()
            haloMat.diffuse.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.1)
            haloMat.emission.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.08)
            haloMat.isDoubleSided = true
            haloGeo.firstMaterial = haloMat
            let haloNode = SCNNode(geometry: haloGeo)
            ship.addChildNode(haloNode)

            ship.scale = SCNVector3(0.5, 0.5, 0.5)

            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.X, .Y]
            ship.constraints = [billboard]

            return ship
        }

        // MARK: - Updates

        func updatePositions(data: ArtemisData, scale: Double, mission: TrackableMission) {
            let craftPos = SCNVector3(
                Float(data.positionKm.x / scale),
                Float(data.positionKm.y / scale),
                Float(data.positionKm.z / scale)
            )

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            craftNode.position = craftPos

            if mission.showMoon {
                let moonPos = SCNVector3(
                    Float(data.moonPositionKm.x / scale),
                    Float(data.moonPositionKm.y / scale),
                    Float(data.moonPositionKm.z / scale)
                )
                moonNode.position = moonPos
                lastSecondaryPos = moonPos
            }
            SCNTransaction.commit()

            lastCraftPos = craftPos

            if !hasInitializedCamera {
                hasInitializedCamera = true
                frameCamera(craftPos: craftPos, mission: mission)
            }
        }

        // MARK: - Sun Light & Earth Rotation

        func updateSunLight(sunPos: (x: Double, y: Double, z: Double), scale: Double, mission: TrackableMission) {
            // For Earth-centered views, point directional light from the Sun's actual position
            if mission.centerBody == .earth {
                let dist = sqrt(sunPos.x * sunPos.x + sunPos.y * sunPos.y + sunPos.z * sunPos.z)
                guard dist > 0 else { return }
                // Normalize direction from center toward Sun
                let dx = Float(sunPos.x / dist)
                let dy = Float(sunPos.y / dist)
                let dz = Float(sunPos.z / dist)
                // Point the directional light toward the origin (Earth) from the Sun's direction
                // Position it far away in the Sun's direction and look at origin
                sunLightNode.position = SCNVector3(dx * 100, dy * 100, dz * 100)
                sunLightNode.look(at: SCNVector3Zero)
            }
        }

        func updateEarthRotation() {
            // Calculate Greenwich Mean Sidereal Time (GMST) for real Earth rotation
            let now = Date()
            let j2000 = DateComponents(calendar: .init(identifier: .gregorian),
                                       timeZone: TimeZone(identifier: "UTC"),
                                       year: 2000, month: 1, day: 1, hour: 12).date!
            let daysSinceJ2000 = now.timeIntervalSince(j2000) / 86400.0
            let centuries = daysSinceJ2000 / 36525.0

            // GMST in degrees
            var gmst = 280.46061837 + 360.98564736629 * daysSinceJ2000
                + 0.000387933 * centuries * centuries
            gmst = gmst.truncatingRemainder(dividingBy: 360.0)
            if gmst < 0 { gmst += 360.0 }

            let gmstRadians = Float(gmst * .pi / 180.0)
            let obliquity = Float(23.4 * .pi / 180.0)

            // Apply rotation: first tilt axis, then rotate around tilted axis
            centerBodyNode.eulerAngles = SCNVector3(0, gmstRadians, obliquity)
        }

        // MARK: - Trajectory Drawing

        func drawPlannedTrajectory(_ positions: [(x: Double, y: Double, z: Double)], scale: Double) {
            hasDrawnTrajectory = true

            scene.rootNode.childNode(withName: "plannedTrajectory", recursively: false)?.removeFromParentNode()

            let trajectoryNode = SCNNode()
            trajectoryNode.name = "plannedTrajectory"

            let points = positions.map {
                SCNVector3(Float($0.x / scale), Float($0.y / scale), Float($0.z / scale))
            }

            let count = points.count
            guard count >= 2 else { return }

            // Draw as a continuous orbital trail
            let lineRadius: CGFloat = 0.08
            let step = max(1, count / 500)
            var i = step
            while i < count {
                let start = points[i - step]
                let end = points[i]
                // Fade from bright (recent) to dim (older)
                let progress = Double(i) / Double(count)
                let alpha = 0.3 + 0.6 * progress
                let seg = makeLine(from: start, to: end,
                                   color: NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: alpha),
                                   radius: lineRadius)
                trajectoryNode.addChildNode(seg)
                i += step
            }

            scene.rootNode.addChildNode(trajectoryNode)

            // Auto-frame camera to include the trail
            if !points.isEmpty {
                frameCamera(craftPos: lastCraftPos,
                            mission: TrackableMission.allMissions.first { $0.id == currentMissionId } ?? .artemisII)
            }
        }

        func drawMoonOrbit(_ positions: [(x: Double, y: Double, z: Double)], scale: Double) {
            hasDrawnMoonOrbit = true

            scene.rootNode.childNode(withName: "moonOrbit", recursively: false)?.removeFromParentNode()

            let orbitNode = SCNNode()
            orbitNode.name = "moonOrbit"

            let points = positions.map {
                SCNVector3(Float($0.x / scale), Float($0.y / scale), Float($0.z / scale))
            }

            guard points.count >= 2 else { return }

            let step = max(1, points.count / 300)
            var i = step
            while i < points.count {
                if (i / step) % 2 == 0 {
                    let start = points[i - step]
                    let end = points[i]
                    let seg = makeLine(from: start, to: end,
                                       color: NSColor(white: 0.55, alpha: 0.7),
                                       radius: 0.05)
                    orbitNode.addChildNode(seg)
                }
                i += step
            }

            scene.rootNode.addChildNode(orbitNode)
        }

        // MARK: - Camera

        func resetCamera() {
            frameCamera(craftPos: lastCraftPos, mission: TrackableMission.allMissions.first { $0.id == currentMissionId } ?? .artemisII)
        }

        private func frameCamera(craftPos: SCNVector3, mission: TrackableMission) {
            var allPoints = [SCNVector3Zero, craftPos]
            if mission.showMoon {
                allPoints.append(lastSecondaryPos)
            }

            var sumX: Float = 0, sumY: Float = 0
            for p in allPoints { sumX += Float(p.x); sumY += Float(p.y) }
            let cx = sumX / Float(allPoints.count)
            let cy = sumY / Float(allPoints.count)

            var maxExtent: Float = 10
            for p in allPoints {
                let dx = abs(Float(p.x) - cx)
                let dy = abs(Float(p.y) - cy)
                maxExtent = max(maxExtent, max(dx, dy))
            }

            let camDist: Float = maxExtent * 2.0 + 10

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            cameraNode.position = SCNVector3(CGFloat(cx), CGFloat(cy), CGFloat(camDist))
            cameraNode.look(at: SCNVector3(CGFloat(cx), CGFloat(cy), 0))
            SCNTransaction.commit()
        }

        // MARK: - Helpers

        private func makeLine(from start: SCNVector3, to end: SCNVector3, color: NSColor, radius: CGFloat) -> SCNNode {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            let distance = sqrt(dx * dx + dy * dy + dz * dz)
            guard distance > 0.001 else { return SCNNode() }

            let cylinder = SCNCylinder(radius: radius, height: CGFloat(distance))
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            cylinder.firstMaterial = mat

            let node = SCNNode(geometry: cylinder)
            node.position = SCNVector3(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            node.look(at: end, up: scene.rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
            return node
        }

        static func makeLabel(_ text: String, size: CGFloat) -> SCNNode {
            let textGeo = SCNText(string: text, extrusionDepth: 0.01)
            textGeo.font = NSFont.systemFont(ofSize: size, weight: .medium)
            textGeo.flatness = 0.1
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.white
            mat.emission.contents = NSColor.white
            textGeo.firstMaterial = mat

            let textNode = SCNNode(geometry: textGeo)
            let (min, max) = textNode.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation(
                (max.x - min.x) / 2 + min.x,
                (max.y - min.y) / 2 + min.y,
                0
            )

            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.X, .Y]
            textNode.constraints = [billboard]
            return textNode
        }

        static func generateStarField(size: Int) -> NSImage {
            let image = NSImage(size: NSSize(width: size, height: size))
            image.lockFocus()
            NSColor.black.setFill()
            NSBezierPath.fill(NSRect(x: 0, y: 0, width: size, height: size))
            for _ in 0..<3000 {
                let x = CGFloat.random(in: 0..<CGFloat(size))
                let y = CGFloat.random(in: 0..<CGFloat(size))
                let brightness = CGFloat.random(in: 0.3...1.0)
                let starSize = CGFloat.random(in: 0.5...2.0)
                NSColor(white: brightness, alpha: 1.0).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: starSize, height: starSize)).fill()
            }
            image.unlockFocus()
            return image
        }
    }
}
