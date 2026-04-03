import SwiftUI
import SceneKit

struct TrajectorySceneView: NSViewRepresentable {
    @ObservedObject var viewModel: ArtemisViewModel

    // Scale: 1 SceneKit unit = 10,000 km
    private let scaleFactor: Double = 10_000.0
    private let earthRadius: CGFloat = 0.6371    // 6,371 km
    private let moonRadius: CGFloat = 0.1737     // 1,737 km
    private let craftSize: CGFloat = 0.15

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        guard let data = viewModel.latestData else { return }
        context.coordinator.updatePositions(data: data, scale: scaleFactor)
    }

    func makeCoordinator() -> SceneCoordinator {
        SceneCoordinator(scaleFactor: scaleFactor, earthRadius: earthRadius, moonRadius: moonRadius, craftSize: craftSize)
    }

    class SceneCoordinator {
        let scene: SCNScene
        let earthNode: SCNNode
        let moonNode: SCNNode
        let craftNode: SCNNode
        let trailNode: SCNNode
        let earthGlowNode: SCNNode
        let cameraNode: SCNNode

        private let scaleFactor: Double
        private var trailPositions: [SCNVector3] = []
        private let maxTrailPoints = 500

        init(scaleFactor: Double, earthRadius: CGFloat, moonRadius: CGFloat, craftSize: CGFloat) {
            self.scaleFactor = scaleFactor
            scene = SCNScene()
            scene.background.contents = NSColor.black

            // Stars background
            if let stars = SCNParticleSystem() as SCNParticleSystem? {
                stars.birthRate = 0
                stars.loops = false
            }
            // Add star field manually
            let starsNode = SCNNode()
            let starGeometry = SCNSphere(radius: 200)
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = NSColor.black
            starMaterial.isDoubleSided = true
            // Create a simple star texture procedurally
            starMaterial.emission.contents = Self.generateStarField(size: 2048)
            starGeometry.firstMaterial = starMaterial
            starsNode.geometry = starGeometry
            scene.rootNode.addChildNode(starsNode)

            // Earth
            let earthGeo = SCNSphere(radius: earthRadius)
            let earthMat = SCNMaterial()
            earthMat.diffuse.contents = NSColor(red: 0.15, green: 0.4, blue: 0.8, alpha: 1.0)
            earthMat.emission.contents = NSColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1.0)
            earthMat.shininess = 0.3
            earthGeo.firstMaterial = earthMat
            earthNode = SCNNode(geometry: earthGeo)
            earthNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(earthNode)

            // Earth atmosphere glow
            let glowGeo = SCNSphere(radius: earthRadius * 1.15)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.15)
            glowMat.isDoubleSided = true
            glowMat.transparency = 0.3
            glowGeo.firstMaterial = glowMat
            earthGlowNode = SCNNode(geometry: glowGeo)
            earthNode.addChildNode(earthGlowNode)

            // Earth label
            let earthLabel = Self.makeLabel("Earth")
            earthLabel.position = SCNVector3(0, Float(earthRadius) + 0.3, 0)
            earthNode.addChildNode(earthLabel)

            // Moon
            let moonGeo = SCNSphere(radius: moonRadius)
            let moonMat = SCNMaterial()
            moonMat.diffuse.contents = NSColor(white: 0.7, alpha: 1.0)
            moonMat.emission.contents = NSColor(white: 0.15, alpha: 1.0)
            moonGeo.firstMaterial = moonMat
            moonNode = SCNNode(geometry: moonGeo)
            scene.rootNode.addChildNode(moonNode)

            // Moon label
            let moonLabel = Self.makeLabel("Moon")
            moonLabel.position = SCNVector3(0, Float(moonRadius) + 0.2, 0)
            moonNode.addChildNode(moonLabel)

            // Spacecraft — small glowing cone
            let craftGeo = SCNCone(topRadius: 0, bottomRadius: craftSize * 0.5, height: craftSize)
            let craftMat = SCNMaterial()
            craftMat.diffuse.contents = NSColor.white
            craftMat.emission.contents = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
            craftGeo.firstMaterial = craftMat
            craftNode = SCNNode(geometry: craftGeo)
            scene.rootNode.addChildNode(craftNode)

            // Craft label
            let craftLabel = Self.makeLabel("Orion")
            craftLabel.position = SCNVector3(0, Float(craftSize) + 0.15, 0)
            craftNode.addChildNode(craftLabel)

            // Craft glow
            let craftLight = SCNLight()
            craftLight.type = .omni
            craftLight.color = NSColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
            craftLight.intensity = 200
            craftLight.attenuationStartDistance = 0
            craftLight.attenuationEndDistance = 5
            craftNode.light = craftLight

            // Trail
            trailNode = SCNNode()
            scene.rootNode.addChildNode(trailNode)

            // Lighting
            let sunLight = SCNNode()
            sunLight.light = SCNLight()
            sunLight.light?.type = .directional
            sunLight.light?.color = NSColor(white: 1.0, alpha: 1.0)
            sunLight.light?.intensity = 800
            sunLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
            scene.rootNode.addChildNode(sunLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = NSColor(white: 0.15, alpha: 1.0)
            ambient.light?.intensity = 300
            scene.rootNode.addChildNode(ambient)

            // Camera
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 500
            cameraNode.camera?.fieldOfView = 50
            cameraNode.position = SCNVector3(0, 30, 50)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            // Animate Earth rotation
            let earthSpin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 20))
            earthNode.runAction(earthSpin)

            // Dashed line from Earth to Moon
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
            SCNTransaction.animationDuration = 0.1
            craftNode.position = artPos
            moonNode.position = moonPos
            SCNTransaction.commit()

            // Update trail
            trailPositions.append(artPos)
            if trailPositions.count > maxTrailPoints {
                trailPositions.removeFirst()
            }
            updateTrailGeometry()
        }

        private func updateTrailGeometry() {
            trailNode.childNodes.forEach { $0.removeFromParentNode() }

            guard trailPositions.count >= 2 else { return }

            // Draw trail as a series of small segments
            let count = trailPositions.count
            for i in 1..<count {
                let start = trailPositions[i - 1]
                let end = trailPositions[i]
                let alpha = Float(i) / Float(count)

                let segment = lineBetween(start: start, end: end, color: NSColor(
                    red: CGFloat(0.3 + 0.7 * alpha),
                    green: CGFloat(0.5 + 0.5 * alpha),
                    blue: 1.0,
                    alpha: CGFloat(0.3 + 0.7 * alpha)
                ))
                trailNode.addChildNode(segment)
            }
        }

        private func lineBetween(start: SCNVector3, end: SCNVector3, color: NSColor) -> SCNNode {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            let distance = sqrt(dx * dx + dy * dy + dz * dz)

            let cylinder = SCNCylinder(radius: 0.03, height: CGFloat(distance))
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
            // Thin dashed circle at average Moon orbit distance
            let orbitRadius: Float = Float(384_400.0 / scaleFactor)
            let segments = 120
            for i in 0..<segments {
                if i % 3 == 0 { continue } // dashed effect
                let angle1 = Float(i) / Float(segments) * 2 * .pi
                let angle2 = Float(i + 1) / Float(segments) * 2 * .pi
                let start = SCNVector3(cos(angle1) * orbitRadius, 0, sin(angle1) * orbitRadius)
                let end = SCNVector3(cos(angle2) * orbitRadius, 0, sin(angle2) * orbitRadius)
                let seg = lineBetween(start: start, end: end, color: NSColor(white: 0.2, alpha: 0.5))
                scene.rootNode.addChildNode(seg)
            }
        }

        static func makeLabel(_ text: String) -> SCNNode {
            let textGeo = SCNText(string: text, extrusionDepth: 0.01)
            textGeo.font = NSFont.systemFont(ofSize: 0.4, weight: .medium)
            textGeo.flatness = 0.1
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.white
            mat.emission.contents = NSColor.white
            textGeo.firstMaterial = mat

            let textNode = SCNNode(geometry: textGeo)
            // Center the text
            let (min, max) = textNode.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation(
                (max.x - min.x) / 2 + min.x,
                (max.y - min.y) / 2 + min.y,
                0
            )

            // Billboard constraint so label always faces camera
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
