//
//  MoonBuggy3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  Playable 3D SceneKit z404 Lunar South Pole (89.9°S) M00N Buggy Drift Lab:
//  - Toggle live between `4WD 4-Pip Crawl` and `2-Pip RWD Drift` (rear [2-5] 2-pip overdrive
//    + counter-steering free-caster front wheels + Kapton-gold regolith roostertails!).
//

import SwiftUI
import Combine
import SceneKit
import simd
import FDToo0Core

@MainActor
public final class MoonBuggy3DSceneCoordinator: ObservableObject {
    public let scene = SCNScene()
    public let cameraNode = SCNNode()

    private let buggyRoot = SCNNode()
    private let chassisNode = SCNNode()
    private var wheelSpinNodes: [SCNNode] = []
    private var frontSteerNodes: [SCNNode] = []
    private var roostertailLeft = SCNNode()
    private var roostertailRight = SCNNode()
    private var lastSkin: DieVisualSkin? = nil
    private var lastMode: BuggyDriveMode? = nil

    public init() {
        scene.background.contents = SceneKitDieBuilder.makeColor(0.02, 0.03, 0.06)
        setupLunarLightingAndCrater()
        setupBuggyChassis()
        setupCamera()
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 46.0
        cam.zNear = 0.2
        cam.zFar = 180.0
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLunarLightingAndCrater() {
        // Low-angle Shackleton South Pole solar grazing light!
        let sun = SCNNode()
        let sl = SCNLight()
        sl.type = .directional
        sl.intensity = 1280
        sl.castsShadow = true
        sun.light = sl
        sun.simdEulerAngles = SIMD3<Float>(-.pi / 5.2, .pi / 3.2, 0)
        scene.rootNode.addChildNode(sun)

        let earthshine = SCNNode()
        let el = SCNLight()
        el.type = .ambient
        el.intensity = 340
        el.color = SceneKitDieBuilder.makeColor(0.62, 0.76, 0.98)
        earthshine.light = el
        scene.rootNode.addChildNode(earthshine)

        // Basalt Lunar Regolith Floor
        let floor = SCNCylinder(radius: 34.0, height: 0.4)
        let regMat = SCNMaterial()
        regMat.lightingModel = .physicallyBased
        regMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.14, 0.16, 0.21)
        regMat.roughness.contents = 0.88
        floor.materials = [regMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.simdPosition = SIMD3<Float>(0, -0.2, 0)
        scene.rootNode.addChildNode(floorNode)

        // Shackleton Crater Rim Torus (r = 18m)
        let rim = SCNTorus(ringRadius: 18.0, pipeRadius: 1.35)
        let rimMat = SCNMaterial()
        rimMat.lightingModel = .physicallyBased
        rimMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.22, 0.25, 0.31)
        rimMat.roughness.contents = 0.90
        rim.materials = [rimMat]
        let rimNode = SCNNode(geometry: rim)
        rimNode.simdPosition = SIMD3<Float>(0, 0.0, 0)
        scene.rootNode.addChildNode(rimNode)

        // Central HoLy M00N Vacuum-Tube Portal at 89.9°S Pole (0, 0)!
        let portalRing = SCNTorus(ringRadius: 2.6, pipeRadius: 0.24)
        let portalMat = SCNMaterial()
        portalMat.lightingModel = .physicallyBased
        portalMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.32, 0.84, 0.98)
        portalMat.emission.contents = SceneKitDieBuilder.makeColor(0.16, 0.52, 0.72)
        portalRing.materials = [portalMat]
        let portalNode = SCNNode(geometry: portalRing)
        portalNode.simdPosition = SIMD3<Float>(0, 0.22, 0)
        scene.rootNode.addChildNode(portalNode)

        // Flagged z404 Rim Markers around Shackleton circle
        let flagGeo = SCNBox(width: 0.45, height: 0.30, length: 0.04, chamferRadius: 0.02)
        let flagMat = SCNMaterial()
        flagMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.90, 0.66, 0.20)
        flagMat.emission.contents = SceneKitDieBuilder.makeColor(0.35, 0.22, 0.04)
        flagGeo.materials = [flagMat]

        let poleGeo = SCNCylinder(radius: 0.03, height: 1.5)
        for i in 0..<12 {
            let ang = Float(i) * (.pi * 2.0 / 12.0)
            let fx = cos(ang) * 18.0
            let fz = sin(ang) * 18.0
            let marker = SCNNode()
            let pole = SCNNode(geometry: poleGeo)
            pole.simdPosition = SIMD3<Float>(0, 0.75, 0)
            let flag = SCNNode(geometry: flagGeo)
            flag.simdPosition = SIMD3<Float>(0.22, 1.35, 0)
            marker.addChildNode(pole)
            marker.addChildNode(flag)
            marker.simdPosition = SIMD3<Float>(fx, 1.1, fz)
            scene.rootNode.addChildNode(marker)
        }
    }

    private func setupBuggyChassis() {
        scene.rootNode.addChildNode(buggyRoot)
        buggyRoot.addChildNode(chassisNode)

        // Spaceframe Deck
        let deck = SCNBox(width: 1.55, height: 0.28, length: 2.65, chamferRadius: 0.08)
        let deckMat = SCNMaterial()
        deckMat.lightingModel = .physicallyBased
        deckMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.84, 0.86, 0.90)
        deckMat.metalness.contents = 0.78
        deckMat.roughness.contents = 0.25
        deck.materials = [deckMat]
        let deckNode = SCNNode(geometry: deck)
        deckNode.simdPosition = SIMD3<Float>(0, 0.62, 0)
        chassisNode.addChildNode(deckNode)

        // Kapton-Gold Thermal Foil Canopy + High-Gain Dish
        let canopy = SCNBox(width: 1.22, height: 0.58, length: 1.25, chamferRadius: 0.16)
        let kaptonMat = SCNMaterial()
        kaptonMat.lightingModel = .physicallyBased
        kaptonMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.92, 0.67, 0.18)
        kaptonMat.metalness.contents = 0.88
        kaptonMat.roughness.contents = 0.20
        canopy.materials = [kaptonMat]
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.simdPosition = SIMD3<Float>(0, 1.02, -0.10)
        chassisNode.addChildNode(canopyNode)

        // Rear Roostertail Plume Cones (scale dynamically during 2-Pip RWD drifts!)
        let plumeGeo = SCNCone(topRadius: 0.05, bottomRadius: 0.42, height: 1.85)
        let plumeMat = SCNMaterial()
        plumeMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.92, 0.72, 0.34, 0.55)
        plumeMat.emission.contents = SceneKitDieBuilder.makeColor(0.42, 0.30, 0.08)
        plumeMat.transparency = 0.58
        plumeGeo.materials = [plumeMat]

        roostertailLeft = SCNNode(geometry: plumeGeo)
        roostertailLeft.simdPosition = SIMD3<Float>(-0.92, 0.48, -1.95)
        roostertailLeft.simdEulerAngles = SIMD3<Float>(-.pi * 0.42, 0, 0)
        chassisNode.addChildNode(roostertailLeft)

        roostertailRight = SCNNode(geometry: plumeGeo)
        roostertailRight.simdPosition = SIMD3<Float>(0.92, 0.48, -1.95)
        roostertailRight.simdEulerAngles = SIMD3<Float>(-.pi * 0.42, 0, 0)
        chassisNode.addChildNode(roostertailRight)
    }

    private func rebuildDiceWheels(
        mode: BuggyDriveMode,
        skin: DieVisualSkin,
        appearance: BoardAppearanceMode
    ) {
        frontSteerNodes.forEach { $0.removeFromParentNode() }
        wheelSpinNodes.forEach { $0.removeFromParentNode() }
        frontSteerNodes.removeAll()
        wheelSpinNodes.removeAll()

        // 4 wheel mounts: Front-Left, Front-Right, Rear-Left, Rear-Right
        let mounts: [(x: Float, z: Float, isRear: Bool, hue: PastelHueFamily)] = [
            (-1.02,  1.02, false, .glacierSky),
            ( 1.02,  1.02, false, .glacierSky),
            (-1.05, -1.02, true,  .apricotPeach),
            ( 1.05, -1.02, true,  .apricotPeach)
        ]

        for m in mounts {
            let steerHolder = SCNNode()
            steerHolder.simdPosition = SIMD3<Float>(m.x, 0.48, m.z)
            chassisNode.addChildNode(steerHolder)

            let axle = m.isRear ? mode.rearAxleLock : mode.frontAxleLock
            let dieWheel = SceneKitDieBuilder.makeDieNode(
                pastelHue: m.hue,
                appearance: appearance,
                skin: skin,
                axleLock: axle,
                isMatchGlowing: m.isRear && mode == .drift2PipRWD
            )
            dieWheel.simdScale = SIMD3<Float>(0.54, 0.54, 0.54)
            // Orient wheel axle along chassis X so rolling forward spins cleanly around X!
            let baseOrient = AxleYahtzeeEngine.alignedInitialOrientation(for: axle == .free24 ? .pin25 : axle)
            dieWheel.simdOrientation = SceneKitDieBuilder.simdQuat(from: baseOrient.unitQuaternion)

            let spinHolder = SCNNode()
            spinHolder.addChildNode(dieWheel)
            steerHolder.addChildNode(spinHolder)

            wheelSpinNodes.append(spinHolder)
            if !m.isRear {
                frontSteerNodes.append(steerHolder)
            }
        }
    }

    public func updateFromEngine(
        buggy: MoonBuggyArenaEngine,
        skin: DieVisualSkin,
        appearance: BoardAppearanceMode
    ) {
        if lastSkin != skin || lastMode != buggy.driveMode {
            rebuildDiceWheels(mode: buggy.driveMode, skin: skin, appearance: appearance)
            lastSkin = skin
            lastMode = buggy.driveMode
        }

        let snap = buggy.snapshot
        buggyRoot.simdPosition = SIMD3<Float>(Float(snap.positionX), Float(snap.altitudeY), Float(snap.positionZ))
        buggyRoot.simdEulerAngles = SIMD3<Float>(0, Float(snap.headingRadians), 0)

        // Counter-steer visual angle on front 2 wheels!
        let steerVisual = Float(-buggy.steeringInput * 0.48)
        for fn in frontSteerNodes {
            fn.simdEulerAngles = SIMD3<Float>(0, steerVisual, 0)
        }

        // Spin front vs rear 2-pip overdrive wheels
        for (idx, wn) in wheelSpinNodes.enumerated() {
            let spin = (idx >= 2) ? Float(snap.rearWheelSpinRadians) : Float(snap.frontWheelSpinRadians)
            wn.simdEulerAngles = SIMD3<Float>(spin, 0, 0)
        }

        // Scale Kapton regolith roostertails by slip + wheelspin intensity!
        let plume = Float(snap.roostertailIntensity)
        let hidden = plume < 0.06
        roostertailLeft.isHidden = hidden
        roostertailRight.isHidden = hidden
        if !hidden {
            let s = SIMD3<Float>(0.5 + plume * 0.9, 0.4 + plume * 1.35, 0.5 + plume * 0.9)
            roostertailLeft.simdScale = s
            roostertailRight.simdScale = s
        }

        // Chase camera tracks smoothly behind velocity vector so you SEE the sideways RWD slip angle!
        let camBackAngle = Float(snap.velocityHeadingRadians)
        let camPos = SIMD3<Float>(
            Float(snap.positionX) - sin(camBackAngle) * 8.4,
            Float(snap.altitudeY) + 4.1,
            Float(snap.positionZ) - cos(camBackAngle) * 8.4
        )
        cameraNode.simdPosition = camPos
        cameraNode.simdLook(at: SIMD3<Float>(Float(snap.positionX), Float(snap.altitudeY) + 0.85, Float(snap.positionZ)))
    }
}

public struct MoonBuggy3DView: View {
    @Bindable public var buggy: MoonBuggyArenaEngine
    public var globalEngine: GameEngine23

    @StateObject private var sceneCoord = MoonBuggy3DSceneCoordinator()
    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    public init(buggy: MoonBuggyArenaEngine, globalEngine: GameEngine23) {
        self.buggy = buggy
        self.globalEngine = globalEngine
    }

    private var primaryInk: Color {
        globalEngine.appearanceMode == .light
            ? Color(red: 0.13, green: 0.11, blue: 0.10)
            : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    private var panelBg: Color {
        globalEngine.appearanceMode == .light
            ? Color(red: 0.95, green: 0.93, blue: 0.89)
            : Color(red: 0.11, green: 0.13, blue: 0.18)
    }

    public var body: some View {
        VStack(spacing: 10) {
            driveModeHeader
            lunarViewport
            touchSteeringAndDriftDeck
        }
        .onAppear {
            buggy.resetToRim()
            buggy.throttleInput = 0.65
            buggy.steeringInput = 0.38
            sceneCoord.updateFromEngine(buggy: buggy, skin: globalEngine.visualSkin, appearance: globalEngine.appearanceMode)
        }
        .onReceive(frameTimer) { _ in
            buggy.step(dt: 1.0 / 60.0)
            sceneCoord.updateFromEngine(
                buggy: buggy,
                skin: globalEngine.visualSkin,
                appearance: globalEngine.appearanceMode
            )
        }
    }

    private var driveModeHeader: some View {
        HStack(spacing: 8) {
            Button {
                buggy.toggleDriveMode()
                TactileAudioHaptics.shared.playTumble(pip: buggy.driveMode == .drift2PipRWD ? 2 : 4)
            } label: {
                Text(buggy.driveMode.badgeTitle)
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(buggy.driveMode == .drift2PipRWD ? Color.orange : Color.teal)
                    )
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(format: "%.1f m/s • Slip %.0f° • Drift %d",
                        buggy.groundSpeed,
                        buggy.slipAngleDegrees,
                        buggy.driftScore))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryInk)
        }
    }

    private var lunarViewport: some View {
        ZStack(alignment: .bottomLeading) {
            SceneView(
                scene: sceneCoord.scene,
                pointOfView: sceneCoord.cameraNode,
                options: [.temporalAntialiasingEnabled]
            )
            .frame(minHeight: 255, maxHeight: 340)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { val in
                        let steer = max(-1.0, min(1.0, Double(val.translation.width / 75.0)))
                        let throt = max(-0.8, min(1.0, Double(-val.translation.height / 75.0)))
                        buggy.steeringInput = steer
                        buggy.throttleInput = abs(throt) < 0.12 ? 0.72 : throt
                    }
            )

            Text(buggy.statusReadout)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.94, green: 0.74, blue: 0.28))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.62), in: Capsule())
                .padding(10)
        }
    }

    private var touchSteeringAndDriftDeck: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("⟲ Drift Left") {
                    buggy.steeringInput = -0.78
                    buggy.throttleInput = 0.92
                }
                .buttonStyle(.bordered)

                Button("⬆ Full 2-Pip Boost") {
                    buggy.steeringInput = 0.0
                    buggy.throttleInput = 1.0
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Drift Right ⟳") {
                    buggy.steeringInput = 0.78
                    buggy.throttleInput = 0.92
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.bold))

            HStack(spacing: 8) {
                Button("🪐 Low-G Hop (1.62 m/s²)") {
                    buggy.triggerLunarCraterHop()
                    TactileAudioHaptics.shared.playCascadeMatch(chain: 2, isChromaSurge: true)
                }
                .buttonStyle(.bordered)

                Button("⏹ Coast / Brake") {
                    buggy.throttleInput = 0.0
                    buggy.steeringInput = 0.0
                }
                .buttonStyle(.bordered)

                Button("↺ Rim") {
                    buggy.resetToRim()
                }
                .buttonStyle(.bordered)
            }
            .font(.caption2.weight(.bold))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(panelBg))
    }
}
