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
        context.coordinator.updatePositions(data: data, scale: scaleFactor)
    }

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator(scaleFactor: scaleFactor)
    }

    class SceneCoordinator {
        let scene: SCNScene
        let earthNode: SCNNode
        let moonNode: SCNNode
        let craftNode: SCNNode
        let trailNode: SCNNode
        let cameraNode: SCNNode
        let craftGlowNode: SCNNode

        private let scaleFactor: Double
        // Exaggerated sizes so they're visible (not to real scale)
        private let earthDisplayRadius: CGFloat = 2.0
        private let moonDisplayRadius: CGFloat = 0.8
        private let craftDisplaySize: CGFloat = 0.6

        private var trailPositions: [SCNVector3] = []
        private let maxTrailPoints = 800
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
            let glowNode = SCNNode(geometry: glowGeo)
            earthNode.addChildNode(glowNode)

            // Earth label
            let earthLabel = Self.makeLabel("Earth", size: 1.0)
            earthLabel.position = SCNVector3(0, Float(earthDisplayRadius) + 1.0, 0)
            earthNode.addChildNode(earthLabel)

            // Earth spin
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

            // Moon label
            let moonLabel = Self.makeLabel("Moon", size: 0.8)
            moonLabel.position = SCNVector3(0, Float(moonDisplayRadius) + 0.6, 0)
            moonNode.addChildNode(moonLabel)

            // === Spacecraft ===
            // Bright sphere with glow so it's always visible
            let craftGeo = SCNSphere(radius: craftDisplaySize)
            let craftMat = SCNMaterial()
            craftMat.diffuse.contents = NSColor.white
            craftMat.emission.contents = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
            craftGeo.firstMaterial = craftMat
            craftNode = SCNNode(geometry: craftGeo)
            scene.rootNode.addChildNode(craftNode)

            // Craft outer glow
            let craftGlowGeo = SCNSphere(radius: craftDisplaySize * 2.5)
            let craftGlowMat = SCNMaterial()
            craftGlowMat.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.15)
            craftGlowMat.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.1)
            craftGlowMat.isDoubleSided = true
            craftGlowGeo.firstMaterial = craftGlowMat
            craftGlowNode = SCNNode(geometry: craftGlowGeo)
            craftNode.addChildNode(craftGlowNode)

            // Craft label
            let craftLabel = Self.makeLabel("Orion", size: 0.7)
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

            // Trail
            trailNode = SCNNode()
            scene.rootNode.addChildNode(trailNode)

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

            // Moon orbit guide (dashed ring)
            addOrbitGuide()
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

            // Auto-frame camera on first data
            if !hasInitializedCamera {
                hasInitializedCamera = true
                frameCamera(earthPos: SCNVector3Zero, moonPos: moonPos, craftPos: artPos)
            }

            // Trail
            trailPositions.append(artPos)
            if trailPositions.count > maxTrailPoints {
                trailPositions.removeFirst()
            }
            if trailPositions.count % 5 == 0 {
                updateTrailGeometry()
            }
        }

        private func frameCamera(earthPos: SCNVector3, moonPos: SCNVector3, craftPos: SCNVector3) {
            // Find center of all three objects
            let cx = (earthPos.x + moonPos.x + craftPos.x) / 3
            let cy = (earthPos.y + moonPos.y + craftPos.y) / 3
            let cz = (earthPos.z + moonPos.z + craftPos.z) / 3
            let center = SCNVector3(cx, cy, cz)

            // Find max distance from center to any object
            let dists = [earthPos, moonPos, craftPos].map { p in
                sqrt(pow(p.x - cx, 2) + pow(p.y - cy, 2) + pow(p.z - cz, 2))
            }
            let maxDist = dists.max() ?? 20

            // Position camera above and back, far enough to see everything
            let camDist = maxDist * 2.5 + 10
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            cameraNode.position = SCNVector3(cx + camDist * 0.3, cy + camDist * 0.5, cz + camDist * 0.8)
            cameraNode.look(at: center)
            SCNTransaction.commit()
        }

        private func updateTrailGeometry() {
            trailNode.childNodes.forEach { $0.removeFromParentNode() }
            guard trailPositions.count >= 2 else { return }

            let count = trailPositions.count
            // Draw every other segment for performance
            let step = max(1, count / 200)
            var i = step
            while i < count {
                let start = trailPositions[i - step]
                let end = trailPositions[i]
                let alpha = Float(i) / Float(count)

                let seg = lineBetween(
                    start: start, end: end,
                    color: NSColor(
                        red: CGFloat(0.2 + 0.8 * alpha),
                        green: CGFloat(0.5 + 0.5 * alpha),
                        blue: 1.0,
                        alpha: CGFloat(0.4 + 0.6 * alpha)
                    ),
                    radius: 0.06
                )
                trailNode.addChildNode(seg)
                i += step
            }
        }

        private func lineBetween(start: SCNVector3, end: SCNVector3, color: NSColor, radius: CGFloat = 0.04) -> SCNNode {
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

        private func addOrbitGuide() {
            let orbitRadius: Float = Float(384_400.0 / scaleFactor)
            let segments = 120
            for i in 0..<segments {
                if i % 3 == 0 { continue }
                let angle1 = Float(i) / Float(segments) * 2 * .pi
                let angle2 = Float(i + 1) / Float(segments) * 2 * .pi
                let start = SCNVector3(cos(angle1) * orbitRadius, 0, sin(angle1) * orbitRadius)
                let end = SCNVector3(cos(angle2) * orbitRadius, 0, sin(angle2) * orbitRadius)
                let seg = lineBetween(start: start, end: end, color: NSColor(white: 0.2, alpha: 0.4), radius: 0.02)
                scene.rootNode.addChildNode(seg)
            }
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
