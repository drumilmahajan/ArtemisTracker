import SwiftUI
import SceneKit

struct TrajectorySceneView: NSViewRepresentable {
    @ObservedObject var viewModel: ArtemisViewModel
    var resetTrigger: Int = 0  // increment to trigger reset

    private let scaleFactor: Double = 10_000.0

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.pointOfView = context.coordinator.cameraNode

        // Configure trackpad camera controls:
        // - Two finger drag = rotate (orbit)
        // - Pinch = zoom
        // - Two finger pan (with option key) = pan/change center
        let cameraController = scnView.defaultCameraController
        cameraController.interactionMode = .orbitTurntable
        cameraController.inertiaEnabled = true
        cameraController.maximumVerticalAngle = 89

        context.coordinator.scnView = scnView
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        let coord = context.coordinator

        // Update live positions
        if let data = viewModel.latestData {
            coord.updatePositions(data: data, scale: scaleFactor)
        }

        // Draw planned trajectory once available (independent of live data)
        if !coord.hasDrawnTrajectory && !viewModel.plannedTrajectory.isEmpty {
            coord.drawPlannedTrajectory(viewModel.plannedTrajectory, scale: scaleFactor)
        }
        if !coord.hasDrawnMoonOrbit && !viewModel.moonOrbit.isEmpty {
            coord.drawMoonOrbit(viewModel.moonOrbit, scale: scaleFactor)
        }

        // Reset camera
        if resetTrigger != coord.lastResetTrigger {
            coord.lastResetTrigger = resetTrigger
            coord.resetCamera()
        }
    }

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator(scaleFactor: scaleFactor)
    }

    class SceneCoordinator {
        let scene: SCNScene
        let earthNode: SCNNode
        let moonNode: SCNNode
        let craftNode: SCNNode
        let cameraNode: SCNNode

        var hasDrawnTrajectory = false
        var hasDrawnMoonOrbit = false
        var lastResetTrigger = 0
        weak var scnView: SCNView?

        private let scaleFactor: Double
        private let earthDisplayRadius: CGFloat = 2.0
        private let moonDisplayRadius: CGFloat = 0.8
        private var hasInitializedCamera = false
        private var lastMoonPos = SCNVector3Zero
        private var lastCraftPos = SCNVector3Zero

        init(scaleFactor: Double) {
            self.scaleFactor = scaleFactor
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

            // === Earth ===
            let earthGeo = SCNSphere(radius: earthDisplayRadius)
            earthGeo.segmentCount = 48
            let earthMat = SCNMaterial()
            earthMat.diffuse.contents = NSColor(red: 0.1, green: 0.35, blue: 0.8, alpha: 1.0)
            earthMat.emission.contents = NSColor(red: 0.03, green: 0.1, blue: 0.25, alpha: 1.0)
            earthMat.specular.contents = NSColor(white: 0.3, alpha: 1.0)
            earthGeo.firstMaterial = earthMat
            earthNode = SCNNode(geometry: earthGeo)
            earthNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(earthNode)

            // Earth glow
            let glowGeo = SCNSphere(radius: earthDisplayRadius * 1.12)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.12)
            glowMat.isDoubleSided = true
            glowGeo.firstMaterial = glowMat
            earthNode.addChildNode(SCNNode(geometry: glowGeo))

            let earthLabel = Self.makeLabel("Earth", size: 1.0)
            earthLabel.position = SCNVector3(0, Float(earthDisplayRadius) + 1.2, 0)
            earthNode.addChildNode(earthLabel)
            earthNode.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 30)))

            // === Moon ===
            let moonGeo = SCNSphere(radius: moonDisplayRadius)
            moonGeo.segmentCount = 36
            let moonMat = SCNMaterial()
            moonMat.diffuse.contents = NSColor(white: 0.65, alpha: 1.0)
            moonMat.emission.contents = NSColor(white: 0.1, alpha: 1.0)
            moonGeo.firstMaterial = moonMat
            moonNode = SCNNode(geometry: moonGeo)
            scene.rootNode.addChildNode(moonNode)

            let moonLabel = Self.makeLabel("Moon", size: 0.8)
            moonLabel.position = SCNVector3(0, Float(moonDisplayRadius) + 0.8, 0)
            moonNode.addChildNode(moonLabel)

            // === Artemis Spacecraft (built from primitives) ===
            craftNode = Self.buildSpacecraft()
            scene.rootNode.addChildNode(craftNode)

            // Craft label above
            let craftLabel = Self.makeLabel("Artemis", size: 0.7)
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

            // === Lighting ===
            let sunLight = SCNNode()
            sunLight.light = SCNLight()
            sunLight.light?.type = .directional
            sunLight.light?.color = NSColor.white
            sunLight.light?.intensity = 1000
            sunLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
            scene.rootNode.addChildNode(sunLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = NSColor(white: 0.25, alpha: 1.0)
            ambient.light?.intensity = 500
            scene.rootNode.addChildNode(ambient)

            // === Camera ===
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 800
            cameraNode.camera?.fieldOfView = 55
            cameraNode.position = SCNVector3(0, 40, 60)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)
        }

        // MARK: - Spacecraft Model

        static func buildSpacecraft() -> SCNNode {
            let ship = SCNNode()

            // --- Command Module (capsule/cone shape) ---
            let capsuleGeo = SCNCapsule(capRadius: 0.25, height: 0.8)
            let capsuleMat = SCNMaterial()
            capsuleMat.diffuse.contents = NSColor(white: 0.9, alpha: 1.0)
            capsuleMat.emission.contents = NSColor(white: 0.3, alpha: 1.0)
            capsuleMat.metalness.contents = NSColor(white: 0.6, alpha: 1.0)
            capsuleGeo.firstMaterial = capsuleMat
            let capsuleNode = SCNNode(geometry: capsuleGeo)
            capsuleNode.position = SCNVector3(0, 0, 0)
            ship.addChildNode(capsuleNode)

            // --- Service Module (cylinder body) ---
            let serviceGeo = SCNCylinder(radius: 0.22, height: 0.6)
            let serviceMat = SCNMaterial()
            serviceMat.diffuse.contents = NSColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1.0)
            serviceMat.metalness.contents = NSColor(white: 0.7, alpha: 1.0)
            serviceGeo.firstMaterial = serviceMat
            let serviceNode = SCNNode(geometry: serviceGeo)
            serviceNode.position = SCNVector3(0, -0.7, 0)
            ship.addChildNode(serviceNode)

            // --- Solar Panel Wings (two flat boxes) ---
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

            // Panel struts
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

            // --- Engine Nozzle (cone at bottom) ---
            let nozzleGeo = SCNCone(topRadius: 0.15, bottomRadius: 0.3, height: 0.3)
            let nozzleMat = SCNMaterial()
            nozzleMat.diffuse.contents = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)
            nozzleMat.metalness.contents = NSColor(white: 0.9, alpha: 1.0)
            nozzleGeo.firstMaterial = nozzleMat
            let nozzleNode = SCNNode(geometry: nozzleGeo)
            nozzleNode.position = SCNVector3(0, -1.15, 0)
            ship.addChildNode(nozzleNode)

            // Engine glow
            let engineGlow = SCNSphere(radius: 0.15)
            let engineMat = SCNMaterial()
            engineMat.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.6)
            engineMat.emission.contents = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
            engineGlow.firstMaterial = engineMat
            let engineGlowNode = SCNNode(geometry: engineGlow)
            engineGlowNode.position = SCNVector3(0, -1.3, 0)
            ship.addChildNode(engineGlowNode)

            // Outer glow halo so it's visible from far away
            let haloGeo = SCNSphere(radius: 1.5)
            let haloMat = SCNMaterial()
            haloMat.diffuse.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.1)
            haloMat.emission.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.08)
            haloMat.isDoubleSided = true
            haloGeo.firstMaterial = haloMat
            let haloNode = SCNNode(geometry: haloGeo)
            ship.addChildNode(haloNode)

            // Scale up so it's visible at scene scale
            ship.scale = SCNVector3(0.5, 0.5, 0.5)

            // Billboard constraint so it always faces camera nicely
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.X, .Y]
            ship.constraints = [billboard]

            return ship
        }

        // MARK: - Updates

        func updatePositions(data: ArtemisData, scale: Double) {
            let artPos = SCNVector3(
                Float(data.positionKm.x / scale),
                Float(data.positionKm.y / scale),
                Float(data.positionKm.z / scale)
            )
            let moonPos = SCNVector3(
                Float(data.moonPositionKm.x / scale),
                Float(data.moonPositionKm.y / scale),
                Float(data.moonPositionKm.z / scale)
            )

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            craftNode.position = artPos
            moonNode.position = moonPos
            SCNTransaction.commit()

            lastMoonPos = moonPos
            lastCraftPos = artPos

            if !hasInitializedCamera {
                hasInitializedCamera = true
                frameCamera(moonPos: moonPos, craftPos: artPos)
            }
        }

        // MARK: - Trajectory Drawing

        func drawPlannedTrajectory(_ positions: [(x: Double, y: Double, z: Double)], scale: Double) {
            hasDrawnTrajectory = true

            // Remove old if any
            scene.rootNode.childNode(withName: "plannedTrajectory", recursively: false)?.removeFromParentNode()

            let trajectoryNode = SCNNode()
            trajectoryNode.name = "plannedTrajectory"

            let points = positions.map {
                SCNVector3(Float($0.x / scale), Float($0.y / scale), Float($0.z / scale))
            }

            let count = points.count
            guard count >= 2 else { return }

            let step = max(1, count / 400)
            var i = step
            while i < count {
                let start = points[i - step]
                let end = points[i]
                let t = Float(i) / Float(count)

                let color: NSColor
                if t < 0.5 {
                    let u = t * 2
                    color = NSColor(
                        red: CGFloat(0.1 + 0.5 * u),
                        green: CGFloat(0.9),
                        blue: CGFloat(0.1 + 0.5 * u),
                        alpha: CGFloat(0.5 + 0.3 * u)
                    )
                } else {
                    let u = (t - 0.5) * 2
                    color = NSColor(
                        red: CGFloat(0.6 - 0.4 * u),
                        green: CGFloat(0.9),
                        blue: CGFloat(0.6 + 0.4 * u),
                        alpha: CGFloat(0.6 + 0.3 * u)
                    )
                }

                let seg = makeLine(from: start, to: end, color: color, radius: 0.1)
                trajectoryNode.addChildNode(seg)
                i += step
            }

            scene.rootNode.addChildNode(trajectoryNode)

            // Re-frame camera if trajectory is larger than what we see
            if hasInitializedCamera, let first = points.first, let last = points.last {
                frameCameraForTrajectory(points: [first, last, SCNVector3Zero])
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

            let step = max(1, points.count / 200)
            var i = step
            while i < points.count {
                let start = points[i - step]
                let end = points[i]
                if (i / step) % 3 != 0 {
                    let seg = makeLine(from: start, to: end, color: NSColor(white: 0.3, alpha: 0.5), radius: 0.04)
                    orbitNode.addChildNode(seg)
                }
                i += step
            }

            scene.rootNode.addChildNode(orbitNode)
        }

        // MARK: - Camera

        func resetCamera() {
            frameCamera(moonPos: lastMoonPos, craftPos: lastCraftPos)
        }

        private func frameCamera(moonPos: SCNVector3, craftPos: SCNVector3) {
            let cx = (moonPos.x + craftPos.x) / 2
            let cy = (moonPos.y + craftPos.y) / 2
            let cz = (moonPos.z + craftPos.z) / 2
            let center = SCNVector3(cx, cy, cz)

            let dists = [SCNVector3Zero, moonPos, craftPos].map { p in
                sqrt(pow(p.x - cx, 2) + pow(p.y - cy, 2) + pow(p.z - cz, 2))
            }
            let maxDist = dists.max() ?? 20
            let camDist = maxDist * 2.5 + 15

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            // Top-down view: camera above looking down (Y-up)
            cameraNode.position = SCNVector3(cx, cy + camDist, cz + camDist * 0.1)
            cameraNode.look(at: center)
            SCNTransaction.commit()

            scnView?.defaultCameraController.target = center
        }

        private func frameCameraForTrajectory(points: [SCNVector3]) {
            var minX: CGFloat = .greatestFiniteMagnitude, maxX: CGFloat = -.greatestFiniteMagnitude
            var minY: CGFloat = .greatestFiniteMagnitude, maxY: CGFloat = -.greatestFiniteMagnitude
            var minZ: CGFloat = .greatestFiniteMagnitude, maxZ: CGFloat = -.greatestFiniteMagnitude

            for p in points {
                let px = CGFloat(p.x), py = CGFloat(p.y), pz = CGFloat(p.z)
                minX = min(minX, px); maxX = max(maxX, px)
                minY = min(minY, py); maxY = max(maxY, py)
                minZ = min(minZ, pz); maxZ = max(maxZ, pz)
            }

            let cx = Float((minX + maxX) / 2)
            let cy = Float((minY + maxY) / 2)
            let cz = Float((minZ + maxZ) / 2)
            let center = SCNVector3(cx, cy, cz)
            let span = Float(max(maxX - minX, max(maxY - minY, maxZ - minZ)))
            let camDist = span * 1.2 + 10

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            cameraNode.position = SCNVector3(cx + camDist * 0.2, cy + camDist * 0.5, cz + camDist * 0.7)
            cameraNode.look(at: center)
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
