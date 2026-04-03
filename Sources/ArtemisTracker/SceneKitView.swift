import SwiftUI
import SceneKit

struct TrajectorySceneView: NSViewRepresentable {
    @ObservedObject var viewModel: ArtemisViewModel

    // 1 SceneKit unit = 10,000 km
    private let scaleFactor: Double = 10_000.0

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.pointOfView = context.coordinator.cameraNode
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        guard let data = viewModel.latestData else { return }
        let coord = context.coordinator
        coord.updatePositions(data: data, scale: scaleFactor)

        // Draw planned trajectory once when available
        if !coord.hasDrawnTrajectory && !viewModel.plannedTrajectory.isEmpty {
            coord.drawPlannedTrajectory(viewModel.plannedTrajectory, scale: scaleFactor)
        }
        if !coord.hasDrawnMoonOrbit && !viewModel.moonOrbit.isEmpty {
            coord.drawMoonOrbit(viewModel.moonOrbit, scale: scaleFactor)
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

        private let scaleFactor: Double
        private let earthDisplayRadius: CGFloat = 2.0
        private let moonDisplayRadius: CGFloat = 0.8
        private let craftDisplaySize: CGFloat = 0.5
        private var hasInitializedCamera = false

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
            earthLabel.position = SCNVector3(0, Float(earthDisplayRadius) + 1.0, 0)
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
            moonLabel.position = SCNVector3(0, Float(moonDisplayRadius) + 0.6, 0)
            moonNode.addChildNode(moonLabel)

            // === Artemis Spacecraft ===
            let craftGeo = SCNSphere(radius: craftDisplaySize)
            let craftMat = SCNMaterial()
            craftMat.diffuse.contents = NSColor.white
            craftMat.emission.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
            craftGeo.firstMaterial = craftMat
            craftNode = SCNNode(geometry: craftGeo)
            scene.rootNode.addChildNode(craftNode)

            // Glow halo
            let glowHalo = SCNSphere(radius: craftDisplaySize * 2.5)
            let haloMat = SCNMaterial()
            haloMat.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.15)
            haloMat.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.1)
            haloMat.isDoubleSided = true
            glowHalo.firstMaterial = haloMat
            craftNode.addChildNode(SCNNode(geometry: glowHalo))

            let craftLabel = Self.makeLabel("Artemis", size: 0.7)
            craftLabel.position = SCNVector3(0, Float(craftDisplaySize) + 0.8, 0)
            craftNode.addChildNode(craftLabel)

            // Craft point light
            let craftLight = SCNLight()
            craftLight.type = .omni
            craftLight.color = NSColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
            craftLight.intensity = 500
            craftLight.attenuationStartDistance = 0
            craftLight.attenuationEndDistance = 20
            craftNode.light = craftLight

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
            ambient.light?.color = NSColor(white: 0.2, alpha: 1.0)
            ambient.light?.intensity = 400
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

            if !hasInitializedCamera {
                hasInitializedCamera = true
                frameCamera(moonPos: moonPos, craftPos: artPos)
            }
        }

        /// Draw the full planned Artemis trajectory as a colored path
        func drawPlannedTrajectory(_ positions: [(x: Double, y: Double, z: Double)], scale: Double) {
            hasDrawnTrajectory = true
            let trajectoryNode = SCNNode()
            trajectoryNode.name = "plannedTrajectory"

            let points = positions.map {
                SCNVector3(Float($0.x / scale), Float($0.y / scale), Float($0.z / scale))
            }

            let count = points.count
            guard count >= 2 else { return }

            // Draw segments — color from green (past/start) through white to cyan (future/end)
            let step = max(1, count / 300) // limit segments for performance
            var i = step
            while i < count {
                let start = points[i - step]
                let end = points[i]
                let t = Float(i) / Float(count)

                // Past portion: dimmer, future: brighter
                let color: NSColor
                if t < 0.5 {
                    // Green → white for first half
                    let u = t * 2
                    color = NSColor(
                        red: CGFloat(0.2 + 0.8 * u),
                        green: CGFloat(0.8),
                        blue: CGFloat(0.2 + 0.8 * u),
                        alpha: CGFloat(0.3 + 0.4 * u)
                    )
                } else {
                    // White → cyan for second half
                    let u = (t - 0.5) * 2
                    color = NSColor(
                        red: CGFloat(1.0 - 0.7 * u),
                        green: CGFloat(0.8 + 0.2 * u),
                        blue: CGFloat(1.0),
                        alpha: CGFloat(0.5 + 0.3 * u)
                    )
                }

                let seg = makeLine(from: start, to: end, color: color, radius: 0.08)
                trajectoryNode.addChildNode(seg)
                i += step
            }

            // Label at start
            let startLabel = Self.makeLabel("Launch", size: 0.5)
            startLabel.position = SCNVector3(points[0].x, points[0].y + 1.0, points[0].z)
            trajectoryNode.addChildNode(startLabel)

            // Label at end
            if let last = points.last {
                let endLabel = Self.makeLabel("Return", size: 0.5)
                endLabel.position = SCNVector3(last.x, last.y + 1.0, last.z)
                trajectoryNode.addChildNode(endLabel)
            }

            scene.rootNode.addChildNode(trajectoryNode)
        }

        /// Draw the Moon's orbit path
        func drawMoonOrbit(_ positions: [(x: Double, y: Double, z: Double)], scale: Double) {
            hasDrawnMoonOrbit = true
            let orbitNode = SCNNode()
            orbitNode.name = "moonOrbit"

            let points = positions.map {
                SCNVector3(Float($0.x / scale), Float($0.y / scale), Float($0.z / scale))
            }

            guard points.count >= 2 else { return }

            let step = max(1, points.count / 150)
            var i = step
            while i < points.count {
                let start = points[i - step]
                let end = points[i]
                // Dashed effect: skip every 3rd segment
                if (i / step) % 3 != 0 {
                    let seg = makeLine(from: start, to: end, color: NSColor(white: 0.25, alpha: 0.4), radius: 0.03)
                    orbitNode.addChildNode(seg)
                }
                i += step
            }

            scene.rootNode.addChildNode(orbitNode)
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

            let camDist = maxDist * 2.5 + 10
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            cameraNode.position = SCNVector3(cx + camDist * 0.3, cy + camDist * 0.5, cz + camDist * 0.8)
            cameraNode.look(at: center)
            SCNTransaction.commit()
        }

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
