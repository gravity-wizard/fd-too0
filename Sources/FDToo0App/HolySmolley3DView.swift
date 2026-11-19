//
//  HolySmolley3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  3D SceneKit Planetary & Abyssal OTEC HyperLoop Explorer + Joe SmoLLey Storied Missions:
//  - Cutaway 3D HoLy Earth (with glowing PREM iron-nickel core!), HoLy M00N (z404 89.9°S),
//    and Submerged Ocean-Trench OTEC HyperLoop (warm surface + 4°C abyssal cold pipe!).
//  - Live 3-Die 3D AxLe-Locked Airlock Valve Manifold puzzle to launch the gravity capsule!
//

import SwiftUI
import Combine
import SceneKit
import simd
import FDToo0Core

@MainActor
public final class HolySmolley3DSceneCoordinator: ObservableObject {
    public let scene = SCNScene()
    public let cameraNode = SCNNode()
    private let worldRoot = SCNNode()
    private let capsuleNode = SCNNode()
    private let manifoldRoot = SCNNode()
    private var currentStartPos = SIMD3<Float>(0, 2.2, 0)
    private var currentEndPos = SIMD3<Float>(0, -2.2, 0)

    public init() {
        scene.background.contents = SceneKitDieBuilder.makeColor(0.03, 0.05, 0.10)

        let key = SCNNode()
        let kl = SCNLight()
        kl.type = .directional
        kl.intensity = 1150
        key.light = kl
        key.simdEulerAngles = SIMD3<Float>(-.pi / 4.0, .pi / 4.0, 0)
        scene.rootNode.addChildNode(key)

        let amb = SCNNode()
        let al = SCNLight()
        al.type = .ambient
        al.intensity = 420
        amb.light = al
        scene.rootNode.addChildNode(amb)

        let cam = SCNCamera()
        cam.fieldOfView = 40.0
        cameraNode.camera = cam
        cameraNode.simdPosition = SIMD3<Float>(0, 1.4, 8.2)
        cameraNode.simdLook(at: SIMD3<Float>(0, -0.35, 0))
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(worldRoot)
        scene.rootNode.addChildNode(manifoldRoot)
        buildCapsule()
    }

    private func buildCapsule() {
        let pod = SCNCapsule(capRadius: 0.14, height: 0.48)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = SceneKitDieBuilder.makeColor(0.98, 0.78, 0.24)
        mat.emission.contents = SceneKitDieBuilder.makeColor(0.55, 0.38, 0.05)
        mat.metalness.contents = 0.85
        mat.roughness.contents = 0.15
        pod.materials = [mat]
        capsuleNode.geometry = pod
        worldRoot.addChildNode(capsuleNode)
    }

    public func rebuildPlanetAndManifold(
        missionEngine: HolySmolleyMissionEngine,
        skin: DieVisualSkin,
        appearance: BoardAppearanceMode
    ) {
        worldRoot.childNodes.filter { $0 !== capsuleNode }.forEach { $0.removeFromParentNode() }
        manifoldRoot.childNodes.forEach { $0.removeFromParentNode() }

        let model = missionEngine.currentMission.bodyModel
        let radius: Float = 2.15

        if model == .abyssalOTECTrench {
            // Warm Tropical Surface Layer + 4°C Deep Abyssal Trench + Vertical OTEC Cold Pipe + Submerged Vacuum Tube!
            let warmSea = SCNBox(width: 5.2, height: 0.55, length: 2.2, chamferRadius: 0.06)
            let warmMat = SCNMaterial()
            warmMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.12, 0.72, 0.82, 0.48)
            warmMat.transparency = 0.52
            warmSea.materials = [warmMat]
            let warmNode = SCNNode(geometry: warmSea)
            warmNode.simdPosition = SIMD3<Float>(0, 1.45, 0)
            worldRoot.addChildNode(warmNode)

            let deepSea = SCNBox(width: 5.2, height: 1.85, length: 2.2, chamferRadius: 0.08)
            let deepMat = SCNMaterial()
            deepMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.05, 0.18, 0.44, 0.62)
            deepMat.transparency = 0.65
            deepSea.materials = [deepMat]
            let deepNode = SCNNode(geometry: deepSea)
            deepNode.simdPosition = SIMD3<Float>(0, 0.25, 0)
            worldRoot.addChildNode(deepNode)

            // Vertical 1,000m OTEC Cold-Water Upwelling Pipe
            let pipe = SCNCylinder(radius: 0.14, height: 2.1)
            let pipeMat = SCNMaterial()
            pipeMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.45, 0.88, 1.0)
            pipeMat.metalness.contents = 0.65
            pipe.materials = [pipeMat]
            let pipeNode = SCNNode(geometry: pipe)
            pipeNode.simdPosition = SIMD3<Float>(0, 0.72, -0.35)
            worldRoot.addChildNode(pipeNode)

            // Horizontal Submerged Evacuated HyperLoop Tube
            let hTube = SCNCylinder(radius: 0.22, height: 4.8)
            let tubeMat = SCNMaterial()
            tubeMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.85, 0.96, 1.0, 0.38)
            tubeMat.transparency = 0.42
            hTube.materials = [tubeMat]
            let hTubeNode = SCNNode(geometry: hTube)
            hTubeNode.simdEulerAngles = SIMD3<Float>(0, 0, .pi * 0.5)
            hTubeNode.simdPosition = SIMD3<Float>(0, 0.15, 0.25)
            worldRoot.addChildNode(hTubeNode)

            currentStartPos = SIMD3<Float>(-2.2, 0.15, 0.25)
            currentEndPos = SIMD3<Float>(2.2, 0.15, 0.25)
            capsuleNode.simdEulerAngles = SIMD3<Float>(0, 0, .pi * 0.5)
        } else {
            // Translucent Cutaway HoLy Earth or HoLy M00N Sphere
            let outerSphere = SCNSphere(radius: CGFloat(radius))
            outerSphere.segmentCount = 48
            let outerMat = SCNMaterial()
            outerMat.lightingModel = .physicallyBased
            if model == .holyMoonZ404 {
                outerMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.58, 0.62, 0.68, 0.36)
            } else {
                outerMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.14, 0.52, 0.86, 0.34)
            }
            outerMat.transparency = 0.38
            outerMat.writesToDepthBuffer = false
            outerSphere.materials = [outerMat]
            let sphereNode = SCNNode(geometry: outerSphere)
            sphereNode.simdPosition = SIMD3<Float>(0, 0.65, 0)
            worldRoot.addChildNode(sphereNode)

            // Glowing Iron-Nickel PREM Core (r = 3480 / 6371 * R) for Earth!
            if model != .holyMoonZ404 {
                let coreGeo = SCNSphere(radius: CGFloat(radius * 0.546))
                let coreMat = SCNMaterial()
                coreMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.95, 0.48, 0.14, 0.62)
                coreMat.emission.contents = SceneKitDieBuilder.makeColor(0.45, 0.18, 0.04)
                coreMat.transparency = 0.65
                coreMat.writesToDepthBuffer = false
                coreGeo.materials = [coreMat]
                let coreNode = SCNNode(geometry: coreGeo)
                coreNode.simdPosition = SIMD3<Float>(0, 0.65, 0)
                worldRoot.addChildNode(coreNode)
            }

            // Straight Evacuated Chord or Polar Core Vacuum Tube!
            let depthFrac = Float(max(0.12, min(1.0, missionEngine.customChordDepth)))
            let b = radius * (1.0 - depthFrac)
            let halfLen = max(0.35, (radius * radius - b * b).squareRoot())

            let tubeGeo = SCNCylinder(radius: 0.16, height: CGFloat(halfLen * 2.0))
            let tubeMat = SCNMaterial()
            tubeMat.diffuse.contents = model == .earthEquatorial
                ? SceneKitDieBuilder.makeColor(0.96, 0.36, 0.36, 0.55)
                : SceneKitDieBuilder.makeColor(0.38, 0.90, 0.98, 0.52)
            tubeMat.transparency = 0.55
            tubeGeo.materials = [tubeMat]
            let tubeNode = SCNNode(geometry: tubeGeo)

            if model == .earthEquatorial {
                // Horizontal chord offset by b
                tubeNode.simdEulerAngles = SIMD3<Float>(0, 0, .pi * 0.5)
                tubeNode.simdPosition = SIMD3<Float>(0, 0.65 + b, 0)
                currentStartPos = SIMD3<Float>(-halfLen, 0.65 + b, 0)
                currentEndPos = SIMD3<Float>(halfLen, 0.65 + b, 0)
                capsuleNode.simdEulerAngles = SIMD3<Float>(0, 0, .pi * 0.5)
            } else {
                // Polar South-to-North (89.9°S <-> 89.9°N) or vertical chord
                tubeNode.simdPosition = SIMD3<Float>(b, 0.65, 0)
                currentStartPos = SIMD3<Float>(b, 0.65 - halfLen, 0)
                currentEndPos = SIMD3<Float>(b, 0.65 + halfLen, 0)
                capsuleNode.simdEulerAngles = SIMD3<Float>(0, 0, 0)
            }
            worldRoot.addChildNode(tubeNode)
        }

        // Sync 3-Die 3D AxLe-Locked Valve Manifold along bottom foreground!
        let hues: [PastelHueFamily] = [.glacierSky, .buttercreamSun, .mintSage]
        let spacing: Float = 1.95
        for idx in missionEngine.manifoldDice.indices {
            let orient = missionEngine.manifoldDice[idx]
            let ax = missionEngine.currentMission.valveAxles[idx]
            let matched = orient.top == missionEngine.currentMission.targetValvePips[idx]
            let dieNode = SceneKitDieBuilder.makeDieNode(
                pastelHue: hues[idx % hues.count],
                appearance: appearance,
                skin: skin,
                axleLock: ax,
                isMatchGlowing: matched
            )
            dieNode.simdScale = SIMD3<Float>(0.56, 0.56, 0.56)
            dieNode.simdPosition = SIMD3<Float>(Float(idx - 1) * spacing, -2.05, 1.45)
            // Tilt slightly toward camera so Top + South + East are legible!
            let tilt = Quat.axisAngle(axis: Vec3(1, 0, 0), radians: 0.42)
            dieNode.simdOrientation = SceneKitDieBuilder.simdQuat(from: tilt * orient.unitQuaternion)
            manifoldRoot.addChildNode(dieNode)
        }

        updateCapsulePosition(progress: missionEngine.capsuleProgress)
    }

    public func updateCapsulePosition(progress: Double) {
        // Cosine SHM profile s(u) = 0.5 * (1 - cos(pi * u)) mirrors real harmonic gravity acceleration!
        let u = Float(0.5 * (1.0 - cos(.pi * max(0.0, min(1.0, progress)))))
        capsuleNode.simdPosition = currentStartPos + (currentEndPos - currentStartPos) * u
    }
}

public struct HolySmolley3DView: View {
    @Bindable public var smolley: HolySmolleyMissionEngine
    public var globalEngine: GameEngine23

    @StateObject private var sceneCoord = HolySmolley3DSceneCoordinator()
    private let animTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    public init(smolley: HolySmolleyMissionEngine, globalEngine: GameEngine23) {
        self.smolley = smolley
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
        let transit = smolley.currentTransitSummary
        let otec = smolley.otecTelemetry

        ScrollView {
            VStack(spacing: 10) {
                missionSelectorStrip
                cutaway3DViewport(transit: transit)
                valveManifoldControls
                joeStoryCard
                otecAndTunnelSliders(otec: otec, transit: transit)
            }
            .padding(.bottom, 12)
        }
        .onAppear { sync3D() }
        .onChange(of: smolley.currentMissionIndex) { _, _ in sync3D() }
        .onChange(of: smolley.manifoldDice) { _, _ in sync3D() }
        .onChange(of: smolley.customChordDepth) { _, _ in sync3D() }
        .onChange(of: globalEngine.visualSkin) { _, _ in sync3D() }
        .onReceive(animTimer) { _ in
            guard smolley.isLaunching else { return }
            smolley.advanceCapsule(deltaProgress: 0.014)
            sceneCoord.updateCapsulePosition(progress: smolley.capsuleProgress)
        }
    }

    private func sync3D() {
        sceneCoord.rebuildPlanetAndManifold(
            missionEngine: smolley,
            skin: globalEngine.visualSkin,
            appearance: globalEngine.appearanceMode
        )
    }

    private var missionSelectorStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(JoeSmolleyMission.campaign.enumerated()), id: \.element.id) { idx, m in
                let active = smolley.currentMissionIndex == idx
                let cleared = smolley.completedMissionIDs.contains(m.id)
                Button {
                    smolley.loadMission(index: idx)
                } label: {
                    Text("M\(m.id)\(cleared ? "✓" : "")")
                        .font(.caption.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(active ? Color.cyan.opacity(0.85) : panelBg)
                        )
                        .foregroundStyle(active ? Color.black : primaryInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cutaway3DViewport(transit: TunnelTransitSummary) -> some View {
        ZStack(alignment: .topLeading) {
            SceneView(
                scene: sceneCoord.scene,
                pointOfView: sceneCoord.cameraNode,
                options: [.allowsCameraControl, .temporalAntialiasingEnabled]
            )
            .frame(height: 235)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(smolley.currentMission.locationBadge)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Text(String(format: "Transit %.2f min • Peak %.2f km/s • Coriolis %.3f N/kg",
                            transit.transitMinutes,
                            transit.peakSpeedKmPerSec,
                            transit.peakCoriolisNewtonsPerKg))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
            .padding(8)
        }
    }

    private var valveManifoldControls: some View {
        VStack(spacing: 6) {
            Text(smolley.missionBanner)
                .font(.caption.weight(.bold))
                .foregroundStyle(smolley.isManifoldAligned ? Color.green : primaryInk)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(0..<smolley.manifoldDice.count, id: \.self) { idx in
                    let curPip = smolley.manifoldDice[idx].top
                    let targetPip = smolley.currentMission.targetValvePips[idx]
                    let ax = smolley.currentMission.valveAxles[idx]
                    let curLabel = LearnedGeometryOracle.label(forPip: curPip, skin: globalEngine.visualSkin)
                    let tgtLabel = LearnedGeometryOracle.label(forPip: targetPip, skin: globalEngine.visualSkin)

                    VStack(spacing: 3) {
                        Text("\(ax.shortTag) • Goal \(tgtLabel)")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.75)
                        HStack(spacing: 6) {
                            Button("↑") {
                                if smolley.tipManifoldDie(index: idx, direction: .north) {
                                    TactileAudioHaptics.shared.playTumble(pip: smolley.manifoldDice[idx].top)
                                }
                            }
                            .buttonStyle(.bordered)
                            Text(curLabel)
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(curPip == targetPip ? .green : primaryInk)
                            Button("↓") {
                                if smolley.tipManifoldDie(index: idx, direction: .south) {
                                    TactileAudioHaptics.shared.playTumble(pip: smolley.manifoldDice[idx].top)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(panelBg))
                    .foregroundStyle(primaryInk)
                }
            }

            Button {
                smolley.triggerCapsuleLaunch()
                TactileAudioHaptics.shared.playStageWin()
            } label: {
                Label(
                    smolley.isManifoldAligned ? "🚀 Drop Gravity / OTEC Capsule!" : "Test-Drop Capsule Anyway",
                    systemImage: "arrow.up.and.down.circle.fill"
                )
                .font(.caption.weight(.heavy))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(smolley.isManifoldAligned ? .green : .teal)
        }
    }

    private var joeStoryCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(smolley.currentMission.title)
                .font(.footnote.weight(.heavy))
            Text(smolley.currentMission.joeBriefing)
                .font(.caption)
                .opacity(0.88)
            Text("💡 Physics Note: \(smolley.currentMission.physicsTakeaway)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(panelBg))
        .foregroundStyle(primaryInk)
    }

    private func otecAndTunnelSliders(otec: OTECTelemetry, transit: TunnelTransitSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🌊 OTEC Rankine Plant")
                    .font(.caption.weight(.heavy))
                Spacer()
                Text(String(format: "ΔT %.1f°C • Net +%.1f MW • %.0f L/s Fresh H₂O",
                            otec.deltaTKelvin,
                            otec.netSurplusMW,
                            otec.desalinatedFreshwaterLitersPerSec))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(otec.netSurplusMW > 0 ? .green : .orange)
            }

            HStack(spacing: 10) {
                Text(String(format: "Warm %.0f°C", smolley.otecConfig.warmSurfaceTempC))
                    .font(.caption2.monospacedDigit())
                Slider(value: $smolley.otecConfig.warmSurfaceTempC, in: 20...31)
                Text(String(format: "Chord %.0f%%", smolley.customChordDepth * 100))
                    .font(.caption2.monospacedDigit())
                Slider(value: $smolley.customChordDepth, in: 0.15...1.0)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(panelBg))
        .foregroundStyle(primaryInk)
    }
}
